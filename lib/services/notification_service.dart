import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repositories/inventory_repository.dart';
import 'firebase_service.dart';

enum NotificationType { expiringSoon, expired, lowStock, householdUpdate, recipeReminder }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? actorUid;   // uid of the member who triggered this (null = system)
  final String? actorName;  // display name of that member
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.actorUid,
    this.actorName,
    this.isRead = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final InventoryRepository _repo = InventoryRepository();
  final FirebaseService _firebase = FirebaseService();

  // ── Fetch ─────────────────────────────────────────────────────────────────

  /// Returns merged notifications:
  ///   1. Persisted Firestore docs in `household_notifications/{householdId}/items`
  ///      — written by Cloud Functions for cross-member events (item added/removed,
  ///        expiry alerts, recipe reminders)
  ///   2. Derived in-app notifications from the live inventory (expired, low stock)
  Future<List<AppNotification>> fetchNotifications() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return [];

    final hQuery = await _firebase.households
        .where('members', arrayContains: uid)
        .limit(1)
        .get();
    if (hQuery.docs.isEmpty) return [];

    final householdId = hQuery.docs.first.id;
    final householdData = hQuery.docs.first.data() as Map<String, dynamic>;
    final memberCount = (householdData['members'] as List?)?.length ?? 1;

    // Run in parallel with individual timeouts so one slow source never blocks
    final results = await Future.wait<List<AppNotification>>([
      _fetchPersistedNotifications(householdId)
          .timeout(const Duration(seconds: 6), onTimeout: () => []),
      _deriveLiveNotifications(uid, householdId, memberCount)
          .timeout(const Duration(seconds: 6), onTimeout: () => []),
    ]);

    final persisted = results[0];
    final derived = results[1];

    // Merge: persisted first (they come from Cloud Functions / other members),
    // then derived local ones — deduplicate by id
    final seen = <String>{};
    final merged = <AppNotification>[];
    for (final n in [...persisted, ...derived]) {
      if (seen.add(n.id)) merged.add(n);
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  // ── Persisted notifications (written by Cloud Functions) ──────────────────

  Future<List<AppNotification>> _fetchPersistedNotifications(
      String householdId) async {
    try {
      final snap = await _firebase.firestore
          .collection('household_notifications')
          .doc(householdId)
          .collection('items')
          .limit(50)
          .get();

      final currentUid = _firebase.currentUser?.uid;
      return snap.docs.map((doc) {
        final data = doc.data();
        final typeStr = data['type'] as String? ?? 'householdUpdate';
        final actorUid = data['actorUid'] as String?;
        final actorName = data['actorName'] as String? ?? 'Someone';
        final rawBody = data['body'] as String? ?? '';
        // Body is stored as "added X to pantry." — prefix with actor or "You"
        final String body;
        if (actorUid != null) {
          final prefix = (actorUid == currentUid) ? 'You' : actorName;
          body = '$prefix $rawBody';
        } else {
          body = rawBody;
        }
        return AppNotification(
          id: doc.id,
          type: _parseType(typeStr),
          title: data['title'] as String? ?? 'SabiTrak',
          body: body,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          actorUid: actorUid,
          actorName: actorName,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  NotificationType _parseType(String s) {
    switch (s) {
      case 'expiringSoon': return NotificationType.expiringSoon;
      case 'expired': return NotificationType.expired;
      case 'lowStock': return NotificationType.lowStock;
      case 'recipeReminder': return NotificationType.recipeReminder;
      default: return NotificationType.householdUpdate;
    }
  }

  // ── Derived live notifications (local inventory scan) ─────────────────────

  Future<List<AppNotification>> _deriveLiveNotifications(
      String uid, String householdId, int memberCount) async {
    try {
      final items = await _repo.getFoodItems(householdId).first;
      final notifications = <AppNotification>[];
      final now = DateTime.now();

      // Expired items
      for (final item in items.where((i) => i.isExpired)) {
        notifications.add(AppNotification(
          id: 'expired_${item.id}',
          type: NotificationType.expired,
          title: '${item.name} has expired',
          body: 'Remove it from your pantry to keep your inventory accurate.',
          createdAt: now.subtract(Duration(days: item.daysUntilExpiry.abs())),
        ));
      }

      // Expiring soon (within 3 days)
      for (final item in items.where((i) => i.isExpiringSoon && !i.isExpired)) {
        final days = item.daysUntilExpiry;
        notifications.add(AppNotification(
          id: 'expiring_${item.id}',
          type: NotificationType.expiringSoon,
          title:
              '${item.name} expires ${days == 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}'}',
          body: 'Use it soon or move it to the freezer.',
          createdAt: now,
        ));
      }

      // Low stock (qty <= 1, not expired)
      for (final item in items.where((i) => i.quantity <= 1 && !i.isExpired)) {
        notifications.add(AppNotification(
          id: 'low_${item.id}',
          type: NotificationType.lowStock,
          title: '${item.name} is running low',
          body: 'Only ${item.quantity} ${item.unit} left. Consider restocking.',
          createdAt: now.subtract(const Duration(hours: 2)),
        ));
      }

      // Recent additions by OTHER household members (last 24h)
      if (memberCount > 1) {
        final recentByOthers = items
            .where((i) =>
                i.addedBy != uid &&
                now.difference(i.createdAt).inHours < 24)
            .toList();
        if (recentByOthers.isNotEmpty) {
          final names = recentByOthers.map((i) => i.name).take(3).join(', ');
          notifications.add(AppNotification(
            id: 'household_recent',
            type: NotificationType.householdUpdate,
            title: 'Household update',
            body: 'A member recently added: $names.',
            createdAt: recentByOthers.first.createdAt,
          ));
        }
      }

      return notifications;
    } catch (_) {
      return [];
    }
  }

  // ── Action recorder (called by the app after add/delete/update) ──────────

  /// Persists a notification for the whole household so everyone (including
  /// the person who triggered the action) sees it in the inbox.
  /// Also bumps the badge count via [NotificationBadge] if available.
  Future<void> recordAction({
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    try {
      // Look up the actor's display name from Firestore users collection
      String actorName = 'Someone';
      try {
        final userDoc = await _firebase.users.doc(uid).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final firstName = userData?['firstName'] as String? ?? '';
        final lastName = userData?['lastName'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        actorName = fullName.isNotEmpty
            ? fullName
            : _firebase.currentUser?.displayName ?? 'Someone';
      } catch (_) {}

      final hQuery = await _firebase.households
          .where('members', arrayContains: uid)
          .limit(1)
          .get();
      if (hQuery.docs.isEmpty) return;
      final householdId = hQuery.docs.first.id;

      await _firebase.firestore
          .collection('household_notifications')
          .doc(householdId)
          .collection('items')
          .add({
        'type': _typeToString(type),
        'title': title,
        'body': body,
        'actorUid': uid,
        'actorName': actorName,
        'createdAt': Timestamp.now(),
      });
    } catch (_) {}
  }

  String _typeToString(NotificationType t) {
    switch (t) {
      case NotificationType.expiringSoon: return 'expiringSoon';
      case NotificationType.expired: return 'expired';
      case NotificationType.lowStock: return 'lowStock';
      case NotificationType.recipeReminder: return 'recipeReminder';
      case NotificationType.householdUpdate: return 'householdUpdate';
    }
  }

  // ── Read-state helpers ────────────────────────────────────────────────────

  Future<void> markAllRead(String householdId) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    await _firebase.firestore
        .collection('notification_read')
        .doc(uid)
        .set({'lastReadAt': Timestamp.fromDate(DateTime.now())},
            SetOptions(merge: true));
  }

  Future<DateTime?> getLastReadAt() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firebase.firestore
        .collection('notification_read')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    final ts = doc.data()?['lastReadAt'];
    return ts != null ? (ts as Timestamp).toDate() : null;
  }
}
