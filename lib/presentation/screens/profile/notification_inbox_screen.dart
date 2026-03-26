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

      if (mounted) {
        setState(() {
          _all = items;
          _loading = false;
        });
      }
      svc.markAllRead('');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppNotification> get _alerts =>
      _all
          .where(
            (n) =>
                n.type == NotificationType.expiringSoon ||
                n.type == NotificationType.expired ||
                n.type == NotificationType.lowStock,
          )
          .toList();

  List<AppNotification> get _activity =>
      _all
          .where(
            (n) =>
                n.type == NotificationType.householdUpdate ||
                n.type == NotificationType.recipeReminder,
          )
          .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor =
        isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
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
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
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
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              )
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

// ── Alerts tab ────────────────────────────────────────────────────────────────

/// Filter options for the Alerts tab.
enum _AlertFilter { all, expiringSoon, expired, lowStock }

class _AlertsTab extends StatefulWidget {
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
  State<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<_AlertsTab> {
  static const int _pageSize = 10;

  _AlertFilter _filter = _AlertFilter.all;
  bool _newestFirst = true;
  int _visibleCount = _pageSize;

  List<AppNotification> get _filtered {
    List<AppNotification> items;
    switch (_filter) {
      case _AlertFilter.expiringSoon:
        items =
            widget.alerts
                .where((n) => n.type == NotificationType.expiringSoon)
                .toList();
        break;
      case _AlertFilter.expired:
        items =
            widget.alerts
                .where((n) => n.type == NotificationType.expired)
                .toList();
        break;
      case _AlertFilter.lowStock:
        items =
            widget.alerts
                .where((n) => n.type == NotificationType.lowStock)
                .toList();
        break;
      case _AlertFilter.all:
        items = List.of(widget.alerts);
    }
    items.sort(
      (a, b) =>
          _newestFirst
              ? b.createdAt.compareTo(a.createdAt)
              : a.createdAt.compareTo(b.createdAt),
    );
    return items;
  }

  List<AppNotification> get _page => _filtered.take(_visibleCount).toList();

  void _resetPagination() => _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final page = _page;
    final hasMore = filtered.length > _visibleCount;

    if (widget.alerts.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No alerts',
        subtitle: 'Your pantry is in great shape!',
        subtitleColor: widget.subtitleColor,
        textColor: widget.textColor,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Filter chips + sort toggle ────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      count: widget.alerts.length,
                      selected: _filter == _AlertFilter.all,
                      onTap:
                          () => setState(() {
                            _filter = _AlertFilter.all;
                            _resetPagination();
                          }),
                      subtitleColor: widget.subtitleColor,
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Expiring Soon',
                      count:
                          widget.alerts
                              .where(
                                (n) => n.type == NotificationType.expiringSoon,
                              )
                              .length,
                      selected: _filter == _AlertFilter.expiringSoon,
                      accent: const Color(0xFFD97706),
                      onTap:
                          () => setState(() {
                            _filter = _AlertFilter.expiringSoon;
                            _resetPagination();
                          }),
                      subtitleColor: widget.subtitleColor,
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Expired',
                      count:
                          widget.alerts
                              .where((n) => n.type == NotificationType.expired)
                              .length,
                      selected: _filter == _AlertFilter.expired,
                      accent: const Color(0xFFC62828),
                      onTap:
                          () => setState(() {
                            _filter = _AlertFilter.expired;
                            _resetPagination();
                          }),
                      subtitleColor: widget.subtitleColor,
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Low Stock',
                      count:
                          widget.alerts
                              .where((n) => n.type == NotificationType.lowStock)
                              .length,
                      selected: _filter == _AlertFilter.lowStock,
                      accent: const Color(0xFFE65100),
                      onTap:
                          () => setState(() {
                            _filter = _AlertFilter.lowStock;
                            _resetPagination();
                          }),
                      subtitleColor: widget.subtitleColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SortButton(
              newestFirst: _newestFirst,
              subtitleColor: widget.subtitleColor,
              onToggle:
                  () => setState(() {
                    _newestFirst = !_newestFirst;
                    _resetPagination();
                  }),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Result count ──────────────────────────────────────────────────
        Text(
          '${filtered.length} ${filtered.length == 1 ? 'alert' : 'alerts'}',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: widget.subtitleColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),

        // ── Cards ─────────────────────────────────────────────────────────
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: _EmptyState(
              icon: Icons.filter_list_off,
              title: 'No results',
              subtitle: 'No alerts match the selected filter.',
              subtitleColor: widget.subtitleColor,
              textColor: widget.textColor,
            ),
          )
        else
          ...page.map(
            (n) => _AlertCard(
              notif: n,
              textColor: widget.textColor,
              subtitleColor: widget.subtitleColor,
              cardColor: widget.cardColor,
              isDark: widget.isDark,
              onTap: () => widget.onTap(n),
            ),
          ),

        // ── Load more ─────────────────────────────────────────────────────
        if (hasMore) ...[
          const SizedBox(height: 8),
          _LoadMoreButton(
            remaining: filtered.length - _visibleCount,
            subtitleColor: widget.subtitleColor,
            onTap: () => setState(() => _visibleCount += _pageSize),
          ),
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
          boxShadow:
              isDark
                  ? []
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
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
                Text(
                  _timeAgo(notif.createdAt),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: subtitleColor.withValues(alpha: 0.7),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
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

// ── Activity tab ──────────────────────────────────────────────────────────────

class _ActivityTab extends StatefulWidget {
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
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  static const int _pageSize = 10;
  bool _newestFirst = true;
  int _visibleCount = _pageSize;

  List<AppNotification> get _sorted {
    final items = List.of(widget.activity);
    items.sort(
      (a, b) =>
          _newestFirst
              ? b.createdAt.compareTo(a.createdAt)
              : a.createdAt.compareTo(b.createdAt),
    );
    return items;
  }

  List<AppNotification> get _page => _sorted.take(_visibleCount).toList();

  @override
  Widget build(BuildContext context) {
    if (widget.activity.isEmpty) {
      return _EmptyState(
        icon: Icons.history_outlined,
        title: 'No recent activity',
        subtitle: 'Actions by you and your household will appear here.',
        subtitleColor: widget.subtitleColor,
        textColor: widget.textColor,
      );
    }

    final sorted = _sorted;
    final page = _page;
    final hasMore = sorted.length > _visibleCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Header + sort ─────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.textColor,
              ),
            ),
            _SortButton(
              newestFirst: _newestFirst,
              subtitleColor: widget.subtitleColor,
              onToggle:
                  () => setState(() {
                    _newestFirst = !_newestFirst;
                    _visibleCount = _pageSize;
                  }),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${sorted.length} ${sorted.length == 1 ? 'event' : 'events'}',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: widget.subtitleColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),

        // ── Rows ──────────────────────────────────────────────────────────
        ...page.map(
          (n) => _ActivityRow(
            notif: n,
            textColor: widget.textColor,
            subtitleColor: widget.subtitleColor,
            cardColor: widget.cardColor,
            isDark: widget.isDark,
          ),
        ),

        // ── Load more ─────────────────────────────────────────────────────
        if (hasMore) ...[
          const SizedBox(height: 8),
          _LoadMoreButton(
            remaining: sorted.length - _visibleCount,
            subtitleColor: widget.subtitleColor,
            onTap: () => setState(() => _visibleCount += _pageSize),
          ),
        ],
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
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                    fontWeight:
                        notif.isRead ? FontWeight.w500 : FontWeight.w700,
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
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

/// Pill-shaped filter chip for the Alerts tab.
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;
  final Color subtitleColor;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.subtitleColor,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accent ?? AppTheme.primaryGreen;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : activeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : activeColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : activeColor,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? Colors.white.withValues(alpha: 0.25)
                          : activeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : activeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sort direction toggle button.
class _SortButton extends StatelessWidget {
  final bool newestFirst;
  final Color subtitleColor;
  final VoidCallback onToggle;

  const _SortButton({
    required this.newestFirst,
    required this.subtitleColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: subtitleColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: subtitleColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              size: 12,
              color: subtitleColor,
            ),
            const SizedBox(width: 4),
            Text(
              newestFirst ? 'Newest' : 'Oldest',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Load more" button shown when there are more items beyond the current page.
class _LoadMoreButton extends StatelessWidget {
  final int remaining;
  final Color subtitleColor;
  final VoidCallback onTap;

  const _LoadMoreButton({
    required this.remaining,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: subtitleColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: subtitleColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.expand_more, size: 16, color: subtitleColor),
              const SizedBox(width: 6),
              Text(
                'Load $remaining more',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ),
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
