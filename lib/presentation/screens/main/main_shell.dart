import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/theme/app_theme.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/push_notification_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_screen.dart';
import '../recipe/recipe_screen.dart';
import '../analytics/analytics_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/notification_inbox_screen.dart';

/// Global unread-notification count — any screen can read or reset this.
class NotificationBadge {
  static final ValueNotifier<int> count = ValueNotifier(0);

  /// Re-computes the badge count and updates the notifier.
  static Future<void> refresh() async {
    try {
      final svc = NotificationService();
      final results = await Future.wait([
        svc.fetchNotifications(),
        svc.getLastReadAt(),
      ]).timeout(const Duration(seconds: 6));

      final notifications = results[0] as List<AppNotification>;
      final lastRead = results[1] as DateTime?;

      final unread = notifications
          .where((n) => lastRead == null || n.createdAt.isAfter(lastRead))
          .length;
      count.value = unread;
    } catch (_) {
      // Keep previous value on error
    }
  }

  /// Call after opening the inbox to reset to zero immediately.
  static void clear() => count.value = 0;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final _shellKey = GlobalKey<_MainShellState>();

  // ignore: library_private_types_in_public_api
  static GlobalKey<_MainShellState> get shellKey => _shellKey;

  static void switchTab(int index) => _shellKey.currentState?.switchTab(index);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  StreamSubscription<QuerySnapshot>? _notifSub;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const InventoryScreen(),
    const RecipeScreen(),
    const AnalyticsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialise push notifications for the signed-in user
    PushNotificationService().init();
    // Initial badge load
    NotificationBadge.refresh();
    // Watch household_notifications in real-time — badge updates the moment
    // any member adds/removes an item (Cloud Function writes a notification doc)
    _startNotificationsWatch();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _startNotificationsWatch() async {
    final firebase = FirebaseService();
    final uid = firebase.currentUser?.uid;
    if (uid == null) return;

    final hQuery = await firebase.households
        .where('members', arrayContains: uid)
        .limit(1)
        .get();
    if (hQuery.docs.isEmpty) return;

    final householdId = hQuery.docs.first.id;

    // Stream household_notifications — fires whenever a new notification is written
    // (by Cloud Functions when any member adds/removes/updates an item)
    _notifSub = firebase.firestore
        .collection('household_notifications')
        .doc(householdId)
        .collection('items')
        .snapshots()
        .listen((_) => NotificationBadge.refresh());
  }

  void switchTab(int index) => setState(() => _currentIndex = index);

  void _openNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => const NotificationInboxScreen()))
        .then((_) {
      // After closing inbox mark all read and reset badge
      NotificationService().markAllRead('');
      NotificationBadge.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppTheme.darkSurface : AppTheme.white;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),

          // ── Global floating notification bell ────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: ValueListenableBuilder<int>(
              valueListenable: NotificationBadge.count,
              builder: (_, badgeCount, __) => GestureDetector(
                onTap: _openNotifications,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkCard.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      badgeCount > 0
                          ? Icons.notifications
                          : Icons.notifications_none_outlined,
                      color: badgeCount > 0
                          ? AppTheme.primaryGreen
                          : (isDark
                              ? AppTheme.darkSubtitle
                              : AppTheme.subtitleGrey),
                      size: 22,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        constraints: const BoxConstraints(
                            minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view,
                  label: 'Dashboard',
                  index: 0,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  label: 'Inventory',
                  index: 1,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.restaurant_menu_outlined,
                  activeIcon: Icons.restaurant_menu,
                  label: 'Recipes',
                  index: 2,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Analytics',
                  index: 3,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  index: 4,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = AppTheme.primaryGreen;
    final inactiveColor =
        isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 10,
                color: isActive ? activeColor : inactiveColor,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
