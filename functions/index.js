const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentDeleted, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const https = require("https");

initializeApp();

// ─── Shared helpers ───────────────────────────────────────────────────────────

/**
 * Returns FCM tokens for ALL members of a household (or exclude one uid).
 */
async function getHouseholdTokens(db, householdId, excludedUid = null) {
  const householdDoc = await db.collection("households").doc(householdId).get();
  if (!householdDoc.exists) return [];

  const members = householdDoc.data().members || [];
  const tokens = [];

  await Promise.all(
    members
      .filter((uid) => uid !== excludedUid)
      .map(async (uid) => {
        const userDoc = await db.collection("users").doc(uid).get();
        const token = userDoc.data()?.fcmToken;
        if (token) tokens.push(token);
      })
  );

  return tokens;
}

/** Sends a multicast push notification. */
async function sendPush(tokens, title, body, data = {}) {
  if (!tokens.length) return;
  const messaging = getMessaging();
  const chunks = [];
  for (let i = 0; i < tokens.length; i += 500) {
    chunks.push(tokens.slice(i, i + 500));
  }
  await Promise.all(
    chunks.map((chunk) =>
      messaging.sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        android: {
          priority: "high",
          notification: { channelId: "sabitrak_default", sound: "default" },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
      })
    )
  );
}

/**
 * Persists a notification into household_notifications/{hid}/items
 * for ALL members to see in the in-app inbox.
 */
async function persistNotification(db, householdId, type, title, body, actorUid = null, actorName = null) {
  await db
    .collection("household_notifications")
    .doc(householdId)
    .collection("items")
    .add({
      type,
      title,
      body,
      actorUid: actorUid || null,
      actorName: actorName || null,
      createdAt: Timestamp.now(),
    });
}

/** Resolves firstName + lastName from users collection. */
async function resolveActorName(db, uid) {
  if (!uid) return "A household member";
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    const data = userDoc.data();
    if (!data) return "A household member";
    const first = data.firstName || "";
    const last = data.lastName || "";
    const full = `${first} ${last}`.trim();
    return full || data.displayName || "A household member";
  } catch (_) {
    return "A household member";
  }
}

// ─── 1. Food item ADDED ───────────────────────────────────────────────────────

exports.onFoodItemAdded = onDocumentCreated(
  { document: "food_items/{itemId}", region: "us-central1" },
  async (event) => {
    const db = getFirestore();
    const data = event.data?.data();
    if (!data) return;

    const { householdId, addedBy, name: itemName = "An item" } = data;
    if (!householdId) return;

    const actorName = await resolveActorName(db, addedBy);
    const title = "🛒 Pantry Updated";
    // body is stored without the actor prefix — Flutter prepends "You" or actorName
    const body = `added ${itemName} to the pantry.`;

    // Push to OTHER members only (don't push to self)
    const tokens = await getHouseholdTokens(db, householdId, addedBy);

    await Promise.all([
      sendPush(tokens, title, `${actorName} ${body}`, { type: "householdUpdate", itemName }),
      // Persist for ALL members (including actor — shows in their own inbox)
      persistNotification(db, householdId, "householdUpdate", title, body, addedBy, actorName),
    ]);
  }
);

// ─── 2. Food item DELETED ─────────────────────────────────────────────────────

exports.onFoodItemDeleted = onDocumentDeleted(
  { document: "food_items/{itemId}", region: "us-central1" },
  async (event) => {
    const db = getFirestore();
    const data = event.data?.data();
    if (!data) return;

    const { householdId, addedBy, name: itemName = "An item" } = data;
    if (!householdId) return;

    // If the item had already expired, archive it in waste_log.
    // The Flutter app also writes to waste_log when the user marks it as
    // wasted, so we only write here for items deleted by other means
    // (e.g. programmatic cleanup) where expiryDate is in the past.
    const expiryDate = data.expiryDate;
    const now = Timestamp.now();
    if (expiryDate && expiryDate.seconds < now.seconds) {
      await db.collection("waste_log").add({
        itemId: event.data.id,
        itemName: itemName,
        category: data.category || "",
        quantity: data.quantity || 0,
        unit: data.unit || "",
        householdId,
        addedBy: addedBy || null,
        expiryDate: expiryDate,
        wastedAt: now,
      });
    }

    // Use lastEditedBy (set by Flutter just before delete) or fall back to addedBy
    const actorUid = data.lastEditedBy || addedBy;
    const actorName = await resolveActorName(db, actorUid);
    const title = "📦 Item Removed";
    const body = `removed ${itemName} from the pantry.`;

    const tokens = await getHouseholdTokens(db, householdId, actorUid);

    await Promise.all([
      sendPush(tokens, `🛒 ${title}`, `${actorName} ${body}`, { type: "householdUpdate", itemName }),
      persistNotification(db, householdId, "householdUpdate", title, body, actorUid, actorName),
    ]);
  }
);

// ─── 3. Food item UPDATED ─────────────────────────────────────────────────────

exports.onFoodItemUpdated = onDocumentUpdated(
  { document: "food_items/{itemId}", region: "us-central1" },
  async (event) => {
    const db = getFirestore();
    const after = event.data?.after?.data();
    const before = event.data?.before?.data();
    if (!after || !before) return;

    const { householdId, addedBy, name: itemName = "An item" } = after;
    if (!householdId) return;

    // Only notify if quantity or expiryDate changed (skip trivial writes)
    const qtyChanged = before.quantity !== after.quantity;
    const expiryChanged = String(before.expiryDate?.seconds) !== String(after.expiryDate?.seconds);
    if (!qtyChanged && !expiryChanged) return;

    // Use lastEditedBy (set by Flutter on every update) or fall back to addedBy
    const actorUid = after.lastEditedBy || addedBy;
    const actorName = await resolveActorName(db, actorUid);

    // Build a meaningful body describing what changed
    let changeDesc;
    if (qtyChanged && expiryChanged) {
      changeDesc = `updated quantity and expiry date of ${itemName}.`;
    } else if (qtyChanged) {
      changeDesc = `updated ${itemName} quantity to ${after.quantity} ${after.unit || ""}.`.trim();
    } else {
      changeDesc = `updated the expiry date of ${itemName}.`;
    }

    const title = "✏️ Item Updated";
    const tokens = await getHouseholdTokens(db, householdId, actorUid);

    await Promise.all([
      sendPush(tokens, title, `${actorName} ${changeDesc}`, { type: "householdUpdate", itemName }),
      persistNotification(db, householdId, "householdUpdate", title, changeDesc, actorUid, actorName),
    ]);
  }
);

// ─── 4. Household member JOINED ───────────────────────────────────────────────
// Fires when the households/{householdId} document is updated (members array grows)

exports.onHouseholdMemberJoined = onDocumentWritten(
  { document: "households/{householdId}", region: "us-central1" },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const beforeMembers = before.members || [];
    const afterMembers = after.members || [];

    // Find newly added members
    const newMembers = afterMembers.filter((uid) => !beforeMembers.includes(uid));
    if (newMembers.length === 0) return;

    const db = getFirestore();
    const householdId = event.params.householdId;
    const householdName = after.name || "your household";

    await Promise.all(
      newMembers.map(async (newUid) => {
        const newMemberName = await resolveActorName(db, newUid);
        const title = "👥 New Member Joined";
        const body = `joined ${householdName}.`;

        // Push to existing members (everyone except the new joiner)
        const tokens = await getHouseholdTokens(db, householdId, newUid);
        await Promise.all([
          sendPush(tokens, title, `${newMemberName} ${body}`, { type: "householdUpdate" }),
          // Persist for ALL members (so the joiner also sees it)
          persistNotification(db, householdId, "householdUpdate", title, body, newUid, newMemberName),
        ]);
      })
    );
  }
);

// ─── 5. Daily expiry check — 8 AM WAT (7 AM UTC) ─────────────────────────────

exports.checkExpiringItems = onSchedule(
  { schedule: "0 7 * * *", timeZone: "UTC", region: "us-central1" },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const in3Days = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

    const snap = await db
      .collection("food_items")
      .where("expiryDate", ">=", Timestamp.fromDate(now))
      .where("expiryDate", "<=", Timestamp.fromDate(in3Days))
      .get();

    if (snap.empty) return;

    const byHousehold = {};
    snap.docs.forEach((doc) => {
      const d = doc.data();
      if (!d.householdId) return;
      if (!byHousehold[d.householdId]) byHousehold[d.householdId] = [];
      byHousehold[d.householdId].push(d.name || "Unknown item");
    });

    await Promise.all(
      Object.entries(byHousehold).map(async ([householdId, names]) => {
        const tokens = await getHouseholdTokens(db, householdId);
        const unique = [...new Set(names)];
        const preview = unique.slice(0, 3).join(", ");
        const extra = unique.length > 3 ? ` +${unique.length - 3} more` : "";
        const title = "⏰ Expiring Soon";
        const body = `${preview}${extra} ${unique.length === 1 ? "is" : "are"} expiring in the next 3 days. Use them before they go to waste!`;

        await Promise.all([
          sendPush(tokens, title, body, { type: "expiringSoon" }),
          persistNotification(db, householdId, "expiringSoon", title, body),
        ]);
      })
    );
  }
);

// ─── 6. Auto-move long-expired items to waste_log — 6 AM UTC daily ───────────
//
// Any food item whose expiryDate is more than 7 days in the past is considered
// abandoned waste. We archive it to waste_log and delete it from food_items so
// the inventory stays clean and the waste reduction % stays accurate.

exports.autoMoveExpiredToWaste = onSchedule(
  { schedule: "0 6 * * *", timeZone: "UTC", region: "us-central1" },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const snap = await db
      .collection("food_items")
      .where("expiryDate", "<", Timestamp.fromDate(sevenDaysAgo))
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    const wasteEntries = [];

    snap.docs.forEach((doc) => {
      const data = doc.data();
      if (!data.householdId) return;

      wasteEntries.push({
        itemId: doc.id,
        itemName: data.name || "Unknown item",
        category: data.category || "",
        quantity: data.quantity || 0,
        unit: data.unit || "",
        householdId: data.householdId,
        addedBy: data.addedBy || null,
        expiryDate: data.expiryDate,
        wastedAt: Timestamp.now(),
      });

      batch.delete(doc.ref);
    });

    // Write waste log entries and delete expired items atomically
    await Promise.all([
      ...wasteEntries.map((entry) => db.collection("waste_log").add(entry)),
      batch.commit(),
    ]);
  }
);

// ─── 7. Daily recipe reminder — 12 PM WAT (11 AM UTC) ────────────────────────

exports.dailyRecipeReminder = onSchedule(
  { schedule: "0 11 * * *", timeZone: "UTC", region: "us-central1" },
  async () => {
    const db = getFirestore();
    const householdsSnap = await db.collection("households").get();
    if (householdsSnap.empty) return;

    const messages = [
      "🍳 Check what you can cook today — your pantry has ideas waiting!",
      "🥘 Don't let your pantry items go to waste. Check your recipe recommendations!",
      "🍲 New recipe ideas based on what's in your pantry. Open SabiTrak to explore!",
      "👨‍🍳 Your pantry is ready. See what delicious meals you can make today!",
    ];
    const body = messages[new Date().getDay() % messages.length];
    const title = "🌟 Recipe of the Day";

    await Promise.all(
      householdsSnap.docs.map(async (householdDoc) => {
        const householdId = householdDoc.id;
        const itemsSnap = await db
          .collection("food_items")
          .where("householdId", "==", householdId)
          .limit(1)
          .get();
        if (itemsSnap.empty) return;

        const tokens = await getHouseholdTokens(db, householdId);
        await Promise.all([
          sendPush(tokens, title, body, { type: "recipeReminder" }),
          persistNotification(db, householdId, "recipeReminder", title, body),
        ]);
      })
    );
  }
);

// ─── Existing: EmailJS proxy ──────────────────────────────────────────────────

exports.sendEmail = onRequest(
  { cors: true, invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const { service_id, template_id, user_id, template_params } =
      req.body.data || req.body;

    if (!service_id || !template_id || !user_id || !template_params) {
      res.status(400).json({ error: "Missing required fields." });
      return;
    }

    const payload = JSON.stringify({ service_id, template_id, user_id, template_params });

    try {
      const result = await new Promise((resolve, reject) => {
        const options = {
          hostname: "api.emailjs.com",
          path: "/api/v1.0/email/send",
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Content-Length": Buffer.byteLength(payload),
            "origin": "https://sabitrak.web.app",
          },
        };
        const request = https.request(options, (response) => {
          let data = "";
          response.on("data", (chunk) => { data += chunk; });
          response.on("end", () => resolve({ status: response.statusCode, body: data }));
        });
        request.on("error", reject);
        request.write(payload);
        request.end();
      });

      if (result.status !== 200) {
        res.status(result.status).json({ error: result.body });
        return;
      }
      res.status(200).json({ result: { success: true } });
    } catch (err) {
      res.status(500).json({ error: "Failed to send email: " + err.message });
    }
  }
);

// ─── Existing: Password reset ─────────────────────────────────────────────────

exports.resetPassword = onRequest(
  { cors: true, invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const { email, newPassword, resetToken } = req.body.data || req.body;

    if (!email || !newPassword || !resetToken) {
      res.status(400).json({ error: "Missing required fields." });
      return;
    }

    const db = getFirestore();
    const doc = await db.collection("password_reset_codes").doc(email).get();

    if (!doc.exists) {
      res.status(404).json({ error: "No reset request found." });
      return;
    }

    const data = doc.data();
    if (!data.used || data.code !== resetToken) {
      res.status(403).json({ error: "Invalid or unverified token." });
      return;
    }

    const expiresAt = data.expiresAt.toDate();
    if (new Date() > new Date(expiresAt.getTime() + 15 * 60 * 1000)) {
      res.status(410).json({ error: "Reset session expired." });
      return;
    }

    try {
      const user = await getAuth().getUserByEmail(email);
      await getAuth().updateUser(user.uid, { password: newPassword });
    } catch (err) {
      res.status(500).json({ error: "Failed to update password." });
      return;
    }

    await db.collection("password_reset_codes").doc(email).delete();
    res.status(200).json({ result: { success: true } });
  }
);
