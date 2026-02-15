import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repositories/inventory_repository.dart';
import 'firebase_service.dart';

enum NotificationType { expiringSoon, expired, lowStock, householdUpdate }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final InventoryRepository _repo = InventoryRepository();
  final FirebaseService _firebase = FirebaseService();

  /// Derives in-app notifications from the current inventory and household data.
  Future<List<AppNotification>> fetchNotifications() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return [];

    // Get household id
    final hQuery = await _firebase.households
        .where('members', arrayContains: uid)
        .limit(1)
        .get();
    if (hQuery.docs.isEmpty) return [];

    final householdId = hQuery.docs.first.id;
    final householdData = hQuery.docs.first.data() as Map<String, dynamic>;
    final memberCount = (householdData['members'] as List?)?.length ?? 1;

    final items = await _repo.getFoodItems(householdId).first;
    final notifications = <AppNotification>[];
    final now = DateTime.now();

    // Expired items
    final expired = items.where((i) => i.isExpired).toList();
    for (final item in expired) {
      notifications.add(AppNotification(
        id: 'expired_${item.id}',
        type: NotificationType.expired,
        title: '${item.name} has expired',
        body: 'Remove it from your pantry to keep your inventory accurate.',
        createdAt: now.subtract(Duration(days: item.daysUntilExpiry.abs())),
      ));
    }

    // Expiring soon (within 3 days)
    final expiringSoon =
        items.where((i) => i.isExpiringSoon && !i.isExpired).toList();
    for (final item in expiringSoon) {
      final days = item.daysUntilExpiry;
      notifications.add(AppNotification(
        id: 'expiring_${item.id}',
        type: NotificationType.expiringSoon,
        title: '${item.name} expires ${days == 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}'}',
        body: 'Use it soon or move it to the freezer.',
        createdAt: now,
      ));
    }

    // Low stock (qty <= 1, not expired)
    final lowStock =
        items.where((i) => i.quantity <= 1 && !i.isExpired).toList();
    for (final item in lowStock) {
      notifications.add(AppNotification(
        id: 'low_${item.id}',
        type: NotificationType.lowStock,
        title: '${item.name} is running low',
        body: 'Only ${item.quantity} ${item.unit} left. Consider restocking.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ));
    }

    // Household activity — members count > 1 means shared household
    if (memberCount > 1) {
      // Check recent additions (items added in last 24h by others)
      final recentByOthers = items.where((i) =>
          i.addedBy != uid &&
          now.difference(i.createdAt).inHours < 24).toList();
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

    // Sort: newest first
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  /// Reads notification read-state from Firestore
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
