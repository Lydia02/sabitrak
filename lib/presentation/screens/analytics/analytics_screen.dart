import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import '../inventory/add_item_options_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loaded = false;
  List<FoodItem> _items = [];
  final InventoryRepository _inventoryRepo = InventoryRepository();
  StreamSubscription<List<FoodItem>>? _inventorySub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final firebaseService = FirebaseService();
    final uid = firebaseService.currentUser?.uid;
    String? householdId;
    if (uid != null) {
      final query = await firebaseService.households
          .where('members', arrayContains: uid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) householdId = query.docs.first.id;
    }
    if (mounted) {
      setState(() => _loaded = true);
      if (householdId != null) {
        _inventorySub = _inventoryRepo.getFoodItems(householdId).listen((items) {
          if (mounted) setState(() => _items = items);
        });
      }
    }
  }

  // ── Computed values ──────────────────────────────────────────────────────
  bool get _isEmpty => _items.isEmpty;
  int get _totalItems => _items.length;
  int get _expiredCount => _items.where((i) => i.isExpired).length;
  int get _expiringSoonCount => _items.where((i) => i.isExpiringSoon && !i.isExpired).length;
  int get _freshCount => _items.where((i) => !i.isExpired && !i.isExpiringSoon).length;
  int get _totalQuantity => _items.fold(0, (s, i) => s + i.quantity);

  double get _wasteReductionPercent {
    if (_totalItems == 0) return 0;
    return ((_totalItems - _expiredCount) / _totalItems * 100).clamp(0, 100);
  }

  Map<String, int> get _categoryBreakdown {
    final map = <String, int>{};
    for (final item in _items) {
      final cat = item.category.isNotEmpty ? item.category : 'Other';
      map[cat] = (map[cat] ?? 0) + item.quantity;
    }
    return map;
  }

  Map<String, int> get _storageBreakdown {
    final map = <String, int>{};
    for (final item in _items) {
      final loc = item.storageLocation.isNotEmpty ? item.storageLocation : 'Other';
      map[loc] = (map[loc] ?? 0) + item.quantity;
    }
    return map;
  }

  List<FoodItem> get _expiringNext7Days => _items
      .where((i) => !i.isExpired && i.daysUntilExpiry <= 7)
      .toList()
    ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final surfaceBg = isDark ? AppTheme.darkSurface : const Color(0xFFF5F5F3);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: surfaceBg,
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2))
            : _isEmpty
                ? _buildEmptyState(isDark, textColor, subtitleColor, cardColor, borderColor, surfaceBg)
                : _buildActiveState(isDark, textColor, subtitleColor, cardColor, borderColor, surfaceBg),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color borderColor, Color surfaceBg) {
    return SingleChildScrollView(
      child: Column(children: [
        _buildHeader(isDark, textColor, subtitleColor, cardColor),
        const SizedBox(height: 48),
        Icon(Icons.bar_chart_rounded, size: 64, color: subtitleColor.withValues(alpha: 0.3)),
        const SizedBox(height: 20),
        Text('No Analytics Yet',
            style: TextStyle(fontFamily: 'Roboto', fontSize: 20,
                fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text('Add items to your pantry to see\ninsights about your food habits.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Roboto', fontSize: 13, color: subtitleColor, height: 1.5)),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => AddItemOptionsScreen.show(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Your First Item'),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ACTIVE STATE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildActiveState(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color borderColor, Color surfaceBg) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(isDark, textColor, subtitleColor, cardColor),
        const SizedBox(height: 16),

        // ── 3 summary stat chips ─────────────────────────────────────────
        _buildStatRow(isDark, textColor, subtitleColor, cardColor),
        const SizedBox(height: 16),

        // ── Waste Reduction ──────────────────────────────────────────────
        _buildWasteReductionCard(isDark, textColor, subtitleColor, cardColor),
        const SizedBox(height: 16),

        // ── Pantry Overview bars ─────────────────────────────────────────
        _buildOverviewBars(isDark, textColor, subtitleColor, cardColor),
        const SizedBox(height: 16),

        // ── What's Left ──────────────────────────────────────────────────
        _buildWhatsLeft(isDark, textColor, subtitleColor, cardColor),
        const SizedBox(height: 16),

        // ── Top Categories vertical bars ─────────────────────────────────
        _buildCategoryChart(isDark, textColor, subtitleColor, cardColor),
        const SizedBox(height: 16),

        // ── Expiring Soon list ───────────────────────────────────────────
        _buildExpiringSoon(isDark, textColor, subtitleColor, cardColor),
        const SizedBox(height: 28),
      ]),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, Color textColor, Color subtitleColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Analytics',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 20,
                    fontWeight: FontWeight.w700, color: textColor)),
            Text('Your pantry insights at a glance',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: subtitleColor)),
          ]),
        ),
      ]),
    );
  }

  // ── 3 Stat Chips ─────────────────────────────────────────────────────────

  Widget _buildStatRow(bool isDark, Color textColor, Color subtitleColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _StatChip(
            label: 'Fresh',
            value: '$_freshCount',
            color: const Color(0xFF2E7D32),
            cardColor: cardColor,
            isDark: isDark,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatChip(
            label: 'Expiring',
            value: '$_expiringSoonCount',
            color: const Color(0xFFE65100),
            cardColor: cardColor,
            isDark: isDark,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatChip(
            label: 'Expired',
            value: '$_expiredCount',
            color: const Color(0xFFC62828),
            cardColor: cardColor,
            isDark: isDark,
          )),
        ]),
      ),
    );
  }

  // ── Waste Reduction Card ──────────────────────────────────────────────────

  Widget _buildWasteReductionCard(bool isDark, Color textColor, Color subtitleColor, Color cardColor) {
    final pct = _wasteReductionPercent;
    final goalColor = pct >= 70
        ? const Color(0xFF2E7D32)
        : pct >= 40
            ? const Color(0xFFE65100)
            : const Color(0xFFC62828);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _card(isDark, cardColor),
        child: Row(children: [
          // Circular indicator
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _RingPainter(
                value: pct / 100,
                trackColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                fillColor: goalColor,
                textColor: textColor,
                strokeWidth: 8,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Waste Reduction Goal',
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 15,
                      fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 4),
              Text(
                pct >= 80
                    ? 'Amazing! You\'re saving most of your food.'
                    : pct >= 50
                        ? 'Good progress! Keep reducing waste.'
                        : 'Use items before they expire to save more.',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                    color: subtitleColor, height: 1.4)),
              const SizedBox(height: 10),
              Row(children: [
                _Dot(color: const Color(0xFF2E7D32), label: 'Saved: ${_totalItems - _expiredCount}'),
                const SizedBox(width: 14),
                _Dot(color: const Color(0xFFC62828), label: 'Wasted: $_expiredCount'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Pantry Overview horizontal bars ──────────────────────────────────────

  Widget _buildOverviewBars(bool isDark, Color textColor, Color subtitleColor, Color cardColor) {
    final maxVal = max(max(_freshCount, _expiringSoonCount), max(_expiredCount, 1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _card(isDark, cardColor),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLabel(label: 'PANTRY OVERVIEW', trailing: '$_totalItems items total', subtitleColor: subtitleColor),
          const SizedBox(height: 18),
          _HBar(label: 'Fresh', value: _freshCount, maxValue: maxVal,
              color: const Color(0xFF2E7D32), textColor: textColor, isDark: isDark),
          const SizedBox(height: 12),
          _HBar(label: 'Expiring Soon', value: _expiringSoonCount, maxValue: maxVal,
              color: const Color(0xFFE65100), textColor: textColor, isDark: isDark),
          const SizedBox(height: 12),
          _HBar(label: 'Expired', value: _expiredCount, maxValue: maxVal,
              color: const Color(0xFFC62828), textColor: textColor, isDark: isDark),
        ]),
      ),
    );
  }

  // ── What's Left ──────────────────────────────────────────────────────────

  Widget _buildWhatsLeft(bool isDark, Color textColor, Color subtitleColor, Color cardColor) {
    final storage = _storageBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxQty = storage.isNotEmpty ? storage.first.value : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _card(isDark, cardColor),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLabel(label: 'WHAT\'S LEFT', trailing: '$_totalQuantity units', subtitleColor: subtitleColor),
          const SizedBox(height: 18),
          ...storage.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SBar(
                  label: e.key,
                  quantity: e.value,
                  maxQuantity: maxQty,
                  icon: _storageIcon(e.key),
                  textColor: textColor,
                  isDark: isDark,
                ),
              )),
        ]),
      ),
    );
  }

  // ── Top Categories vertical bars ─────────────────────────────────────────

  Widget _buildCategoryChart(bool isDark, Color textColor, Color subtitleColor, Color cardColor) {
    final cats = (_categoryBreakdown.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();
    final maxVal = cats.isNotEmpty ? cats.first.value : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _card(isDark, cardColor),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLabel(label: 'TOP CATEGORIES', trailing: '', subtitleColor: subtitleColor),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: cats.asMap().entries.map((e) {
                final i = e.key;
                final cat = e.value;
                final barH = (cat.value / maxVal * 100).clamp(8.0, 100.0);
                final color = _barColor(i);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 5, right: i == cats.length - 1 ? 0 : 5),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${cat.value}',
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                              fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        child: Container(height: barH, color: color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.key.length > 8 ? '${cat.key.substring(0, 7)}…' : cat.key,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Roboto', fontSize: 9, color: subtitleColor),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          // Legend dots
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: cats.asMap().entries.map((e) => _Dot(
                  color: _barColor(e.key),
                  label: e.value.key,
                )).toList(),
          ),
        ]),
      ),
    );
  }

  // ── Expiring Soon list ────────────────────────────────────────────────────

  Widget _buildExpiringSoon(bool isDark, Color textColor, Color subtitleColor, Color cardColor) {
    final items = _expiringNext7Days;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _card(isDark, cardColor),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _SectionLabel(
              label: 'EXPIRING SOON',
              trailing: '',
              subtitleColor: subtitleColor,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: items.isNotEmpty
                    ? const Color(0xFFE65100).withValues(alpha: 0.1)
                    : const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${items.length} item${items.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: items.isNotEmpty ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 8),
              Text('Nothing expiring this week. Nice!',
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 13, color: subtitleColor)),
            ])
          else
            ...items.take(5).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExpiryRow(item: item, textColor: textColor, subtitleColor: subtitleColor),
                )),
          if (items.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+${items.length - 5} more items',
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: subtitleColor)),
            ),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BoxDecoration _card(bool isDark, Color cardColor) => BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      );

  IconData _storageIcon(String location) {
    switch (location.toLowerCase()) {
      case 'fridge': return Icons.kitchen_outlined;
      case 'freezer': return Icons.ac_unit;
      case 'cupboard': return Icons.door_sliding_outlined;
      case 'counter': return Icons.countertops_outlined;
      case 'shelf': return Icons.shelves;
      case 'bag/basket': return Icons.shopping_basket_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }

  Color _barColor(int i) {
    const colors = [
      Color(0xFF2E7D32),
      Color(0xFF558B2F),
      Color(0xFF7CB342),
      Color(0xFFAED581),
      Color(0xFFE65100),
    ];
    return colors[i % colors.length];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Reusable sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  final String trailing;
  final Color subtitleColor;

  const _SectionLabel({required this.label, required this.trailing, required this.subtitleColor});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
              fontWeight: FontWeight.w700, color: subtitleColor, letterSpacing: 1.2)),
      if (trailing.isNotEmpty)
        Text(trailing,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: subtitleColor.withValues(alpha: 0.7))),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color cardColor;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.cardColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 22,
                fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.75))),
      ]),
    );
  }
}

class _HBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;
  final Color textColor;
  final bool isDark;

  const _HBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    return Row(children: [
      SizedBox(
        width: 106,
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                fontWeight: FontWeight.w500, color: textColor)),
      ),
      Expanded(
        child: SizedBox(
          height: 20,
          child: CustomPaint(
            painter: _BarPainter(
              fraction: fraction,
              trackColor: trackColor,
              fillColor: color,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 28,
        child: Text('$value',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

class _SBar extends StatelessWidget {
  final String label;
  final int quantity;
  final int maxQuantity;
  final IconData icon;
  final Color textColor;
  final bool isDark;

  const _SBar({
    required this.label,
    required this.quantity,
    required this.maxQuantity,
    required this.icon,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxQuantity > 0 ? (quantity / maxQuantity).clamp(0.0, 1.0) : 0.0;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    return Row(children: [
      Icon(icon, size: 17, color: AppTheme.primaryGreen),
      const SizedBox(width: 8),
      SizedBox(
        width: 70,
        child: Text(label,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                fontWeight: FontWeight.w500, color: textColor)),
      ),
      Expanded(
        child: SizedBox(
          height: 14,
          child: CustomPaint(
            painter: _BarPainter(
              fraction: fraction,
              trackColor: trackColor,
              fillColor: AppTheme.primaryGreen,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 24,
        child: Text('$quantity',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                fontWeight: FontWeight.w700, color: textColor)),
      ),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color fillColor;
  final Color textColor;
  final double strokeWidth;

  const _RingPainter({
    required this.value,
    required this.trackColor,
    required this.fillColor,
    required this.textColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track
    paint.color = trackColor;
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    // Arc
    if (value > 0) {
      paint.color = fillColor;
      canvas.drawArc(rect, -pi / 2, 2 * pi * value.clamp(0.0, 1.0), false, paint);
    }

    // Text
    final label = '${(value * 100).round()}%';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.fillColor != fillColor ||
      old.trackColor != trackColor || old.textColor != textColor;
}

class _BarPainter extends CustomPainter {
  final double fraction;
  final Color trackColor;
  final Color fillColor;

  const _BarPainter({
    required this.fraction,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height), radius);
    canvas.drawRRect(rrect, Paint()..color = trackColor);

    final fillW = (size.width * fraction).clamp(0.0, size.width);
    if (fillW > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillW, size.height), radius);
      canvas.drawRRect(fillRect, Paint()..color = fillColor);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction || old.trackColor != trackColor || old.fillColor != fillColor;
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;

  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkSubtitle
                  : AppTheme.subtitleGrey)),
    ]);
  }
}

class _ExpiryRow extends StatelessWidget {
  final FoodItem item;
  final Color textColor;
  final Color subtitleColor;

  const _ExpiryRow({required this.item, required this.textColor, required this.subtitleColor});

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final isToday = days == 0;
    final urgencyColor = isToday
        ? const Color(0xFFC62828)
        : days <= 2
            ? const Color(0xFFE65100)
            : const Color(0xFFE65100).withValues(alpha: 0.65);

    return Row(children: [
      Container(
        width: 4, height: 38,
        decoration: BoxDecoration(color: urgencyColor, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name,
              style: TextStyle(fontFamily: 'Roboto', fontSize: 13,
                  fontWeight: FontWeight.w600, color: textColor)),
          Text('${item.quantity} ${item.unit} · ${item.storageLocation}',
              style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: subtitleColor)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: urgencyColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isToday ? 'Today' : days == 1 ? 'Tomorrow' : '$days days',
          style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
              fontWeight: FontWeight.w700, color: urgencyColor),
        ),
      ),
    ]);
  }
}
