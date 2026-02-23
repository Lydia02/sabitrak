import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../services/notification_service.dart';
import '../main/main_shell.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<AppNotification> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = NotificationService();
    try {
      final results = await Future.wait([
        svc.fetchNotifications(),
        svc.getLastReadAt(),
      ]).timeout(const Duration(seconds: 8));

      final items = results[0] as List<AppNotification>;
      final lastRead = results[1] as DateTime?;

      for (final n in items) {
        if (lastRead != null && n.createdAt.isBefore(lastRead)) {
          n.isRead = true;
        }
      }

      if (mounted) setState(() { _all = items; _loading = false; });
      svc.markAllRead('');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppNotification> get _alerts => _all.where((n) =>
      n.type == NotificationType.expiringSoon ||
      n.type == NotificationType.expired ||
      n.type == NotificationType.lowStock).toList();

  List<AppNotification> get _activity => _all.where((n) =>
      n.type == NotificationType.householdUpdate ||
      n.type == NotificationType.recipeReminder).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final surfaceBg = isDark ? AppTheme.darkSurface : const Color(0xFFF7F7F6);
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: subtitleColor,
              indicator: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Alerts'),
                      if (_alerts.any((n) => !n.isRead)) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Activity'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen, strokeWidth: 2))
          : TabBarView(
              controller: _tabController,
              children: [
                _AlertsTab(
                  alerts: _alerts,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  cardColor: cardColor,
                  isDark: isDark,
                  onTap: _handleTap,
                ),
                _ActivityTab(
                  activity: _activity,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  cardColor: cardColor,
                  isDark: isDark,
                ),
              ],
            ),
    );
  }

  void _handleTap(AppNotification notif) {
    Navigator.pop(context);
    MainShell.switchTab(1);
  }
}

// ── Alerts tab ───────────────────────────────────────────────────────────────

class _AlertsTab extends StatelessWidget {
  final List<AppNotification> alerts;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool isDark;
  final void Function(AppNotification) onTap;

  const _AlertsTab({
    required this.alerts,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No alerts',
        subtitle: 'Your pantry is in great shape!',
        subtitleColor: subtitleColor,
        textColor: textColor,
      );
    }

    final expiringSoon =
        alerts.where((n) => n.type == NotificationType.expiringSoon).toList();
    final expired =
        alerts.where((n) => n.type == NotificationType.expired).toList();
    final lowStock =
        alerts.where((n) => n.type == NotificationType.lowStock).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (expiringSoon.isNotEmpty) ...[
          _SectionHeader(label: 'Expiring Soon', count: expiringSoon.length, subtitleColor: subtitleColor),
          const SizedBox(height: 8),
          ...expiringSoon.map((n) => _AlertCard(
                notif: n,
                textColor: textColor,
                subtitleColor: subtitleColor,
                cardColor: cardColor,
                isDark: isDark,
                onTap: () => onTap(n),
              )),
          const SizedBox(height: 16),
        ],
        if (expired.isNotEmpty) ...[
          _SectionHeader(label: 'Expired', count: expired.length, subtitleColor: subtitleColor),
          const SizedBox(height: 8),
          ...expired.map((n) => _AlertCard(
                notif: n,
                textColor: textColor,
                subtitleColor: subtitleColor,
                cardColor: cardColor,
                isDark: isDark,
                onTap: () => onTap(n),
              )),
          const SizedBox(height: 16),
        ],
        if (lowStock.isNotEmpty) ...[
          _SectionHeader(label: 'Low Stock', count: lowStock.length, subtitleColor: subtitleColor),
          const SizedBox(height: 8),
          ...lowStock.map((n) => _AlertCard(
                notif: n,
                textColor: textColor,
                subtitleColor: subtitleColor,
                cardColor: cardColor,
                isDark: isDark,
                onTap: () => onTap(n),
              )),
        ],
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AppNotification notif;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool isDark;
  final VoidCallback onTap;

  const _AlertCard({
    required this.notif,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.isDark,
    required this.onTap,
  });

  Color get _accent {
    switch (notif.type) {
      case NotificationType.expired:
        return const Color(0xFFC62828);
      case NotificationType.expiringSoon:
        return const Color(0xFFD97706);
      case NotificationType.lowStock:
        return const Color(0xFFE65100);
      default:
        return AppTheme.primaryGreen;
    }
  }

  String get _urgencyLabel {
    switch (notif.type) {
      case NotificationType.expired:
        return 'EXPIRED';
      case NotificationType.expiringSoon:
        return 'SOON';
      case NotificationType.lowStock:
        return 'LOW';
      default:
        return '';
    }
  }

  String get _actionLabel {
    switch (notif.type) {
      case NotificationType.expired:
        return 'Remove Item';
      case NotificationType.lowStock:
        return 'Go to Inventory';
      default:
        return 'View Inventory';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: accent, width: 4)),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _urgencyLabel,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notif.title,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notif.body,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: subtitleColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.1),
                  foregroundColor: accent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _actionLabel,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity tab ─────────────────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  final List<AppNotification> activity;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool isDark;

  const _ActivityTab({
    required this.activity,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return _EmptyState(
        icon: Icons.history_outlined,
        title: 'No recent activity',
        subtitle: 'Actions by you and your household will appear here.',
        subtitleColor: subtitleColor,
        textColor: textColor,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        ...activity.map((n) => _ActivityRow(
              notif: n,
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
            )),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final AppNotification notif;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool isDark;

  const _ActivityRow({
    required this.notif,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.isDark,
  });

  Color get _dotColor {
    if (notif.body.contains('added')) return AppTheme.primaryGreen;
    if (notif.body.contains('removed') || notif.body.contains('deleted')) {
      return Colors.red;
    }
    if (notif.body.contains('updated')) return const Color(0xFFD97706);
    return AppTheme.primaryGreen;
  }

  IconData get _icon {
    if (notif.type == NotificationType.recipeReminder) {
      return Icons.restaurant_menu_outlined;
    }
    if (notif.body.contains('added')) return Icons.add_circle_outline;
    if (notif.body.contains('removed') || notif.body.contains('deleted')) {
      return Icons.remove_circle_outline;
    }
    if (notif.body.contains('updated')) return Icons.edit_outlined;
    return Icons.group_outlined;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, color: dotColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.body,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _timeAgo(notif.createdAt),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: subtitleColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (!notif.isRead)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color subtitleColor;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: subtitleColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '· $count ${count == 1 ? 'item' : 'items'}',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: subtitleColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Color textColor;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: subtitleColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: subtitleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
