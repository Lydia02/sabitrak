const { onRequest } = require("firebase-functions/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

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
