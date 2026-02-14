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
      if (query.docs.isNotEmpty) {
        householdId = query.docs.first.id;
      }
    }

    if (mounted) {
      setState(() => _loaded = true);
      if (householdId != null) {
        _inventorySub =
            _inventoryRepo.getFoodItems(householdId).listen((items) {
          if (mounted) {
            setState(() => _items = items);
          }
        });
      }
    }
  }

  bool get _isEmpty => _items.isEmpty;

  int get _totalItems => _items.length;
  int get _expiredCount => _items.where((i) => i.isExpired).length;
  int get _expiringSoonCount => _items.where((i) => i.isExpiringSoon).length;
  int get _freshCount =>
      _items.where((i) => !i.isExpired && !i.isExpiringSoon).length;

  int get _totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  double get _wasteReductionPercent {
    if (_totalItems == 0) return 0;
    final saved = _totalItems - _expiredCount;
    return (saved / _totalItems * 100).clamp(0, 100);
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
      final loc =
          item.storageLocation.isNotEmpty ? item.storageLocation : 'Other';
      map[loc] = (map[loc] ?? 0) + item.quantity;
    }
    return map;
  }

  List<FoodItem> get _expiringNext7Days {
    return _items
        .where((i) => !i.isExpired && i.daysUntilExpiry <= 7)
        .toList()
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.fieldBorderColor;

    return Scaffold(
      body: SafeArea(
        child: _loaded
            ? (_isEmpty
                ? _buildEmptyState(isDark, textColor, subtitleColor, cardColor, borderColor)
                : _buildActiveState(isDark, textColor, subtitleColor, cardColor, borderColor))
            : const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════════════

  Widget _buildEmptyState(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color borderColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(isDark, textColor, subtitleColor, cardColor),
          const SizedBox(height: 32),

          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 36,
              color: subtitleColor.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'No Analytics Yet',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start adding items to your pantry to see\ninsights about your food habits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: subtitleColor,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => AddItemOptionsScreen.show(context),
                child: const Text('Add Your First Item'),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Preview cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildPreviewCard(
                  icon: Icons.eco_outlined,
                  title: 'Waste Saved',
                  subtitle: 'Track how much food you save from waste',
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildPreviewCard(
                  icon: Icons.restaurant_outlined,
                  title: 'Consumption',
                  subtitle: 'See what you consume most',
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildPreviewCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'What\'s Left',
                  subtitle: 'Overview of remaining pantry items',
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPreviewCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtitleColor,
    required Color cardColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryGreen.withValues(alpha: 0.4),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: subtitleColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline,
            size: 18,
            color: subtitleColor.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ACTIVE STATE
  // ═══════════════════════════════════════════════════

  Widget _buildActiveState(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color borderColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark, textColor, subtitleColor, cardColor),
          const SizedBox(height: 16),
          _buildWasteReductionCard(isDark, textColor, subtitleColor, cardColor, borderColor),
          const SizedBox(height: 16),
          _buildOverviewBarChart(isDark, textColor, subtitleColor, cardColor, borderColor),
          const SizedBox(height: 16),
          _buildWhatsLeftSection(isDark, textColor, subtitleColor, cardColor, borderColor),
          const SizedBox(height: 16),
          _buildCategoryConsumption(isDark, textColor, subtitleColor, cardColor),
          const SizedBox(height: 16),
          _buildExpiringSoon(isDark, textColor, subtitleColor, cardColor),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.fieldBorderColor.withValues(alpha: 0.3),
            ),
            child: Icon(
              Icons.person,
              color: subtitleColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  'Your pantry insights at a glance',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardColor,
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: textColor,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteReductionCard(bool isDark, Color textColor,
      Color subtitleColor, Color cardColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
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
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _wasteReductionPercent / 100,
                    strokeWidth: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.fieldBorderColor.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _wasteReductionPercent >= 70
                          ? const Color(0xFF2E7D32)
                          : _wasteReductionPercent >= 40
                              ? const Color(0xFFE65100)
                              : const Color(0xFFC62828),
                    ),
                  ),
                  Text(
                    '${_wasteReductionPercent.round()}%',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waste Reduction Goal',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _wasteReductionPercent >= 80
                        ? 'Amazing! You\'re saving most of your food.'
                        : _wasteReductionPercent >= 50
                            ? 'Good progress! Keep reducing waste.'
                            : 'Use items before they expire to save more.',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MiniStat(
                        label: 'Saved',
                        value: '${_totalItems - _expiredCount}',
                        color: const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 16),
                      _MiniStat(
                        label: 'Wasted',
                        value: '$_expiredCount',
                        color: const Color(0xFFC62828),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewBarChart(bool isDark, Color textColor,
      Color subtitleColor, Color cardColor, Color borderColor) {
    final saved = _freshCount + _expiringSoonCount;
    final wasted = _expiredCount;
    final maxVal = max(max(saved, wasted), 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PANTRY OVERVIEW',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '$_totalItems items total',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ChartBar(
              label: 'Fresh',
              value: _freshCount,
              maxValue: maxVal,
              color: const Color(0xFF2E7D32),
              textColor: textColor,
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _ChartBar(
              label: 'Expiring Soon',
              value: _expiringSoonCount,
              maxValue: maxVal,
              color: const Color(0xFFE65100),
              textColor: textColor,
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _ChartBar(
              label: 'Expired',
              value: _expiredCount,
              maxValue: maxVal,
              color: const Color(0xFFC62828),
              textColor: textColor,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsLeftSection(bool isDark, Color textColor,
      Color subtitleColor, Color cardColor, Color borderColor) {
    final storage = _storageBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxQty = storage.isNotEmpty ? storage.first.value : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'WHAT\'S LEFT',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '$_totalQuantity units remaining',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...storage.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StorageBar(
                    label: entry.key,
                    quantity: entry.value,
                    maxQuantity: maxQty,
                    icon: _storageIcon(entry.key),
                    textColor: textColor,
                    isDark: isDark,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  IconData _storageIcon(String location) {
    switch (location.toLowerCase()) {
      case 'fridge':
        return Icons.kitchen_outlined;
      case 'freezer':
        return Icons.ac_unit;
      case 'cupboard':
        return Icons.door_sliding_outlined;
      case 'counter':
        return Icons.countertops_outlined;
      case 'shelf':
        return Icons.shelves;
      case 'bag/basket':
        return Icons.shopping_basket_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildCategoryConsumption(bool isDark, Color textColor,
      Color subtitleColor, Color cardColor) {
    final categories = _categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = categories.take(5).toList();
    final maxVal = topCategories.isNotEmpty ? topCategories.first.value : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOP CATEGORIES',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ...topCategories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cat = entry.value;
                    final barHeight =
                        (cat.value / maxVal * 120).clamp(8.0, 120.0);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 4,
                          right:
                              index == topCategories.length - 1 ? 0 : 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${cat.value}',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: _barColor(index),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat.key.length > 8
                                  ? '${cat.key.substring(0, 7)}…'
                                  : cat.key,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 10,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _barColor(int index) {
    const colors = [
      Color(0xFF33401C),
      Color(0xFF4A5A2C),
      Color(0xFF558B2F),
      Color(0xFF7CB342),
      Color(0xFF9CCC65),
    ];
    return colors[index % colors.length];
  }

  Widget _buildExpiringSoon(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor) {
    final expiringItems = _expiringNext7Days;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXPIRING SOON',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: expiringItems.isNotEmpty
                        ? const Color(0xFFE65100).withValues(alpha: 0.1)
                        : const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${expiringItems.length} item${expiringItems.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: expiringItems.isNotEmpty
                          ? const Color(0xFFE65100)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (expiringItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nothing expiring this week. Nice!',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...expiringItems.take(5).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExpiryRow(
                      item: item,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                    ),
                  )),
            if (expiringItems.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${expiringItems.length - 5} more items',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Reusable Widgets
// ═══════════════════════════════════════════════════

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ChartBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;
  final Color textColor;
  final bool isDark;

  const _ChartBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? value / maxValue : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 18,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.fieldBorderColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _StorageBar extends StatelessWidget {
  final String label;
  final int quantity;
  final int maxQuantity;
  final IconData icon;
  final Color textColor;
  final bool isDark;

  const _StorageBar({
    required this.label,
    required this.quantity,
    required this.maxQuantity,
    required this.icon,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxQuantity > 0 ? quantity / maxQuantity : 0.0;
    return Row(
      children: [
        Icon(icon, size: 18, color: textColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 14,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.fieldBorderColor.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF558B2F),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$quantity',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  final FoodItem item;
  final Color textColor;
  final Color subtitleColor;

  const _ExpiryRow({
    required this.item,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final isToday = days == 0;
    final urgencyColor = isToday
        ? const Color(0xFFC62828)
        : days <= 1
            ? const Color(0xFFE65100)
            : const Color(0xFFE65100).withValues(alpha: 0.7);

    return Row(
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: urgencyColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              Text(
                '${item.quantity} ${item.unit} · ${item.storageLocation}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: urgencyColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isToday
                ? 'Today'
                : days == 1
                    ? 'Tomorrow'
                    : '$days days',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: urgencyColor,
            ),
          ),
        ),
      ],
    );
  }
}
