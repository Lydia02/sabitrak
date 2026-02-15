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

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = NotificationService();
    final items = await svc.fetchNotifications();
    final lastRead = await svc.getLastReadAt();

    // Mark as read anything older than lastReadAt
    for (final n in items) {
      if (lastRead != null && n.createdAt.isBefore(lastRead)) {
        n.isRead = true;
      }
    }

    if (mounted) setState(() { _notifications = items; _loading = false; });

    // Mark all read
    final uid = await svc.getLastReadAt(); // just to reuse method signature
    if (uid != null || true) {
      await NotificationService().markAllRead('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final surfaceBg = isDark ? AppTheme.darkSurface : const Color(0xFFF7F7F6);

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
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 2,
              ),
            )
          : _notifications.isEmpty
              ? _buildEmpty(textColor, subtitleColor)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _NotifCard(
                    notif: _notifications[i],
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    cardColor: cardColor,
                    isDark: isDark,
                    onTap: () => _handleTap(_notifications[i]),
                  ),
                ),
    );
  }

  void _handleTap(AppNotification notif) {
    Navigator.pop(context);
    if (notif.type == NotificationType.expiringSoon ||
        notif.type == NotificationType.expired ||
        notif.type == NotificationType.lowStock) {
      // Go to Smart Inventory tab
      MainShell.switchTab(1);
    } else if (notif.type == NotificationType.householdUpdate) {
      // Go to Analytics or Inventory
      MainShell.switchTab(1);
    }
  }

  Widget _buildEmpty(Color textColor, Color subtitleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined,
              size: 64,
              color: subtitleColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No notifications right now.',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool isDark;
  final VoidCallback onTap;

  const _NotifCard({
    required this.notif,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _icon();
    final iconColor = _iconColor();
    final iconBg = isDark
        ? iconColor.withValues(alpha: 0.15)
        : iconColor.withValues(alpha: 0.1);
    final timeAgo = _timeAgo(notif.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead
              ? cardColor
              : (isDark
                  ? AppTheme.primaryGreen.withValues(alpha: 0.07)
                  : AppTheme.primaryGreen.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead
                ? Colors.transparent
                : AppTheme.primaryGreen.withValues(alpha: 0.12),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon() {
    switch (notif.type) {
      case NotificationType.expired:
        return Icons.error_outline;
      case NotificationType.expiringSoon:
        return Icons.timer_outlined;
      case NotificationType.lowStock:
        return Icons.warning_amber_rounded;
      case NotificationType.householdUpdate:
        return Icons.group_outlined;
    }
  }

  Color _iconColor() {
    switch (notif.type) {
      case NotificationType.expired:
        return const Color(0xFFC62828);
      case NotificationType.expiringSoon:
        return const Color(0xFFD97706);
      case NotificationType.lowStock:
        return const Color(0xFFE65100);
      case NotificationType.householdUpdate:
        return AppTheme.primaryGreen;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
