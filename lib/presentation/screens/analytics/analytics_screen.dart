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

  // ── Computed stats ──
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
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: _loaded
            ? (_isEmpty ? _buildEmptyState() : _buildActiveState())
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

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 32),

          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.fieldBorderColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 36,
              color: AppTheme.subtitleGrey.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'No Analytics Yet',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start adding items to your pantry to see\ninsights about your food habits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: AppTheme.subtitleGrey,
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
                ),
                const SizedBox(height: 12),
                _buildPreviewCard(
                  icon: Icons.restaurant_outlined,
                  title: 'Consumption',
                  subtitle: 'See what you consume most',
                ),
                const SizedBox(height: 12),
                _buildPreviewCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'What\'s Left',
                  subtitle: 'Overview of remaining pantry items',
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.fieldBorderColor.withValues(alpha: 0.4),
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
                    color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: AppTheme.subtitleGrey.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline,
            size: 18,
            color: AppTheme.subtitleGrey.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ACTIVE STATE
  // ═══════════════════════════════════════════════════

  Widget _buildActiveState() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),

          // ── Waste Reduction Goal (circular) ──
          _buildWasteReductionCard(),
          const SizedBox(height: 16),

          // ── Overview Bar Chart: Saved vs Consumed vs Wasted ──
          _buildOverviewBarChart(),
          const SizedBox(height: 16),

          // ── What's Left — pantry status bars ──
          _buildWhatsLeftSection(),
          const SizedBox(height: 16),

          // ── Category Consumption ──
          _buildCategoryConsumption(),
          const SizedBox(height: 16),

          // ── Expiring Soon ──
          _buildExpiringSoon(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.fieldBorderColor.withValues(alpha: 0.3),
            ),
            child: const Icon(
              Icons.person,
              color: AppTheme.subtitleGrey,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                Text(
                  'Your pantry insights at a glance',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: AppTheme.subtitleGrey,
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
                color: AppTheme.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.primaryGreen,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Waste Reduction Goal ──
  Widget _buildWasteReductionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _wasteReductionPercent / 100,
                    strokeWidth: 6,
                    backgroundColor:
                        AppTheme.fieldBorderColor.withValues(alpha: 0.3),
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
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
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
                  const Text(
                    'Waste Reduction Goal',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _wasteReductionPercent >= 80
                        ? 'Amazing! You\'re saving most of your food.'
                        : _wasteReductionPercent >= 50
                            ? 'Good progress! Keep reducing waste.'
                            : 'Use items before they expire to save more.',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: AppTheme.subtitleGrey,
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

  // ── Overview Bar Chart ──
  Widget _buildOverviewBarChart() {
    final saved = _freshCount + _expiringSoonCount;
    final wasted = _expiredCount;
    final maxVal = max(max(saved, wasted), 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
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
                const Text(
                  'PANTRY OVERVIEW',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.subtitleGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '$_totalItems items total',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: AppTheme.subtitleGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bar chart rows
            _ChartBar(
              label: 'Fresh',
              value: _freshCount,
              maxValue: maxVal,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 14),
            _ChartBar(
              label: 'Expiring Soon',
              value: _expiringSoonCount,
              maxValue: maxVal,
              color: const Color(0xFFE65100),
            ),
            const SizedBox(height: 14),
            _ChartBar(
              label: 'Expired',
              value: _expiredCount,
              maxValue: maxVal,
              color: const Color(0xFFC62828),
            ),
          ],
        ),
      ),
    );
  }

  // ── What's Left Section ──
  Widget _buildWhatsLeftSection() {
    final storage = _storageBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxQty = storage.isNotEmpty
        ? storage.first.value
        : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
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
                const Text(
                  'WHAT\'S LEFT',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.subtitleGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '$_totalQuantity units remaining',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: AppTheme.subtitleGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Storage location bars
            ...storage.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StorageBar(
                    label: entry.key,
                    quantity: entry.value,
                    maxQuantity: maxQty,
                    icon: _storageIcon(entry.key),
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

  // ── Category Consumption ──
  Widget _buildCategoryConsumption() {
    final categories = _categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = categories.take(5).toList();
    final maxVal = topCategories.isNotEmpty ? topCategories.first.value : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
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
            const Text(
              'TOP CATEGORIES',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.subtitleGrey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),

            // Vertical bar chart
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ...topCategories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cat = entry.value;
                    final barHeight = (cat.value / maxVal * 120).clamp(8.0, 120.0);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 4,
                          right: index == topCategories.length - 1 ? 0 : 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${cat.value}',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
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
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 10,
                                color: AppTheme.subtitleGrey,
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

  // ── Expiring Soon ──
  Widget _buildExpiringSoon() {
    final expiringItems = _expiringNext7Days;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
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
                const Text(
                  'EXPIRING SOON',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.subtitleGrey,
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Nothing expiring this week. Nice!',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: AppTheme.subtitleGrey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...expiringItems.take(5).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExpiryRow(item: item),
                  )),
            if (expiringItems.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${expiringItems.length - 5} more items',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.subtitleGrey,
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

  const _ChartBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
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
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 18,
              backgroundColor:
                  AppTheme.fieldBorderColor.withValues(alpha: 0.2),
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

  const _StorageBar({
    required this.label,
    required this.quantity,
    required this.maxQuantity,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxQuantity > 0 ? quantity / maxQuantity : 0.0;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 14,
              backgroundColor:
                  AppTheme.fieldBorderColor.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF558B2F),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$quantity',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  final FoodItem item;

  const _ExpiryRow({required this.item});

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
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryGreen,
                ),
              ),
              Text(
                '${item.quantity} ${item.unit} · ${item.storageLocation}',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: AppTheme.subtitleGrey,
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
