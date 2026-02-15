import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import 'add_item_options_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryRepository _repo = InventoryRepository();
  String? _householdId;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'All', 'Grains', 'Spices', 'Canned', 'Dairy', 'Fruits', 'Vegetables',
    'Meat', 'Beverages', 'Snacks', 'Frozen',
  ];

  @override
  void initState() {
    super.initState();
    _loadHouseholdId();
  }

  Future<void> _loadHouseholdId() async {
    final uid = FirebaseService().currentUser?.uid;
    if (uid == null) return;
    final query = await FirebaseService()
        .households
        .where('members', arrayContains: uid)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty && mounted) {
      setState(() => _householdId = query.docs.first.id);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FoodItem> _filterItems(List<FoodItem> items) {
    var filtered = items;
    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((item) =>
              item.category.toLowerCase().contains(_selectedCategory.toLowerCase()))
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return filtered;
  }

  void _openAddItem() {
    AddItemOptionsScreen.show(context);
  }

  /// Derive "Smart Insights" from actual inventory data
  List<_InsightCard> _buildInsights(List<FoodItem> items) {
    final insights = <_InsightCard>[];

    // Expiring soon items
    final expiringSoon =
        items.where((i) => i.isExpiringSoon && !i.isExpired).toList();
    for (final item in expiringSoon.take(2)) {
      insights.add(_InsightCard(
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFF7ED),
        darkBgColor: const Color(0xFF3D2A00),
        borderColor: const Color(0xFFFED7AA),
        darkBorderColor: const Color(0xFF7C4A00),
        title: '${item.name} low?',
        subtitle: 'Expiring in ${item.daysUntilExpiry} day${item.daysUntilExpiry == 1 ? '' : 's'}',
      ));
    }

    // Low quantity items (qty <= 1)
    final lowQty =
        items.where((i) => i.quantity <= 1 && !i.isExpired).toList();
    for (final item in lowQty.take(2)) {
      if (insights.length >= 3) break;
      insights.add(_InsightCard(
        icon: Icons.auto_awesome,
        iconColor: AppTheme.primaryGreen,
        bgColor: AppTheme.primaryGreen.withValues(alpha: 0.06),
        darkBgColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
        borderColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
        darkBorderColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
        title: '${item.quantity} ${item.name} left?',
        subtitle: 'Consider restocking soon',
      ));
    }

    // Fallback if inventory is empty or no insights
    if (insights.isEmpty) {
      insights.add(_InsightCard(
        icon: Icons.auto_awesome,
        iconColor: AppTheme.primaryGreen,
        bgColor: AppTheme.primaryGreen.withValues(alpha: 0.06),
        darkBgColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
        borderColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
        darkBorderColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
        title: 'Pantry looks good!',
        subtitle: 'No urgent items right now',
      ));
    }

    return insights;
  }

  int _progressPercent(List<FoodItem> items) {
    if (items.isEmpty) return 0;
    final fresh = items.where((i) => !i.isExpired && !i.isExpiringSoon).length;
    return ((fresh / items.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final surfaceColor = isDark ? AppTheme.darkSurface : const Color(0xFFF7F7F6);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.primaryGreen.withValues(alpha: 0.1);

    return Scaffold(
      body: SafeArea(
        child: _householdId == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              )
            : StreamBuilder<List<FoodItem>>(
                stream: _repo.getFoodItems(_householdId!),
                builder: (context, snapshot) {
                  final allItems = snapshot.data ?? [];
                  final filteredItems = _filterItems(allItems);
                  final insights = _buildInsights(allItems);
                  final progress = _progressPercent(allItems);

                  return Column(
                    children: [
                      // ── Header ──────────────────────────────────────────
                      Container(
                        color: isDark ? AppTheme.darkSurface : AppTheme.white,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.arrow_back,
                                        color: textColor, size: 24),
                                    onPressed: () => Navigator.of(context).maybePop(),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Smart Inventory',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.more_vert,
                                        color: textColor, size: 24),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                            // Progress bar section
                            Container(
                              color: isDark ? AppTheme.darkCard : AppTheme.white,
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'PANTRY REFRESH PROGRESS',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                          color: textColor.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      Text(
                                        '$progress%',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress / 100,
                                      minHeight: 6,
                                      backgroundColor: AppTheme.primaryGreen
                                          .withValues(alpha: 0.1),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              AppTheme.primaryGreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                            ),
                          ],
                        ),
                      ),

                      // ── Scrollable body ─────────────────────────────────
                      Expanded(
                        child: (snapshot.connectionState == ConnectionState.waiting)
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryGreen,
                                  strokeWidth: 2,
                                ),
                              )
                            : allItems.isEmpty
                                ? _buildEmptyState(
                                    textColor, subtitleColor, isDark)
                                : ListView(
                                    children: [
                                      // Smart Insights
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 16, 16, 0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'SMART INSIGHTS',
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.5,
                                                color: textColor
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              height: 100,
                                              child: ListView.separated(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount: insights.length,
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(width: 10),
                                                itemBuilder: (ctx, i) =>
                                                    _SmartInsightChip(
                                                  card: insights[i],
                                                  isDark: isDark,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 14),

                                      // Search Bar
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: isDark
                                                ? []
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.05),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ],
                                          ),
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: (val) => setState(
                                                () => _searchQuery = val),
                                            style:
                                                TextStyle(color: textColor),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Search pantry items...',
                                              hintStyle: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 14,
                                                color: textColor
                                                    .withValues(alpha: 0.4),
                                              ),
                                              prefixIcon: Icon(Icons.search,
                                                  color: subtitleColor,
                                                  size: 22),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Category Filter
                                      SizedBox(
                                        height: 40,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          itemCount: _categories.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 10),
                                          itemBuilder: (ctx, i) {
                                            final cat = _categories[i];
                                            final isSelected =
                                                _selectedCategory == cat;
                                            return GestureDetector(
                                              onTap: () => setState(() =>
                                                  _selectedCategory = cat),
                                              child: Container(
                                                padding: const EdgeInsets
                                                    .symmetric(horizontal: 20),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? AppTheme.primaryGreen
                                                      : AppTheme.primaryGreen
                                                          .withValues(
                                                              alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  cat,
                                                  style: TextStyle(
                                                    fontFamily: 'Roboto',
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: isSelected
                                                        ? AppTheme.white
                                                        : textColor,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Items List
                                      if (filteredItems.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(40),
                                          child: Center(
                                            child: Text(
                                              'No items match your filter',
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 14,
                                                color: subtitleColor,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ...filteredItems.map(
                                          (item) => Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 0, 16, 12),
                                            child: _SmartItemCard(
                                              item: item,
                                              textColor: textColor,
                                              subtitleColor: subtitleColor,
                                              cardColor: cardColor,
                                              surfaceColor: surfaceColor,
                                              borderColor: borderColor,
                                              isDark: isDark,
                                            ),
                                          ),
                                        ),

                                      // Verify All button
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 4, 16, 24),
                                        child: ElevatedButton.icon(
                                          onPressed: () {},
                                          icon: const Icon(Icons.done_all,
                                              size: 20),
                                          label: const Text(
                                              'Verify All Predicted Changes'),
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ],
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddItem,
        backgroundColor: AppTheme.primaryGreen,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppTheme.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState(
      Color textColor, Color subtitleColor, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppTheme.fieldBorderColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 52,
                color: subtitleColor.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your inventory is empty',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add food items to track expiry dates and get smart insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: subtitleColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openAddItem,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Add Your First Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class for insight cards ────────────────────────────────────────────
class _InsightCard {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color darkBgColor;
  final Color borderColor;
  final Color darkBorderColor;
  final String title;
  final String subtitle;

  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.darkBgColor,
    required this.borderColor,
    required this.darkBorderColor,
    required this.title,
    required this.subtitle,
  });
}

// ── Smart Insight Chip ───────────────────────────────────────────────────────
class _SmartInsightChip extends StatelessWidget {
  final _InsightCard card;
  final bool isDark;

  const _SmartInsightChip({required this.card, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? card.darkBgColor : card.bgColor;
    final border = isDark ? card.darkBorderColor : card.borderColor;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: card.iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(card.icon, color: card.iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            card.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: card.iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            card.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 10,
              color: card.iconColor.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Smart Item Card ──────────────────────────────────────────────────────────
class _SmartItemCard extends StatelessWidget {
  final FoodItem item;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDark;

  const _SmartItemCard({
    required this.item,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Status
    String statusText;
    Color statusBg;
    Color statusFg;
    bool isLowStock = false;

    if (item.isExpired) {
      statusText = 'EXPIRED';
      statusBg = const Color(0xFFFFEBEE);
      statusFg = const Color(0xFFC62828);
    } else if (item.isExpiringSoon) {
      statusText = 'LOW STOCK';
      statusBg = const Color(0xFFFFF7ED);
      statusFg = const Color(0xFFD97706);
      isLowStock = true;
    } else if (item.quantity <= 1) {
      statusText = 'LOW STOCK';
      statusBg = const Color(0xFFFFF7ED);
      statusFg = const Color(0xFFD97706);
      isLowStock = true;
    } else if (item.quantity >= 5) {
      statusText = 'FULL';
      statusBg = const Color(0xFFE8F5E9);
      statusFg = AppTheme.primaryGreen;
    } else {
      statusText = 'STEADY';
      statusBg = const Color(0xFFE8F5E9);
      statusFg = AppTheme.primaryGreen;
    }

    // Predicted text
    String predicted;
    Color predictedColor;
    if (item.isExpiringSoon || item.isExpired) {
      predicted = '-1 unit';
      predictedColor = Colors.red;
    } else {
      predicted = 'No change';
      predictedColor = subtitleColor;
    }
    final isPredictedNegative = item.isExpiringSoon || item.isExpired;

    // Card border: thicker for low stock
    final cardBorder = isLowStock
        ? Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.2), width: 2)
        : Border.all(color: borderColor, width: 1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: cardBorder,
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
          // Icon / image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        _categoryIcon(item.category),
                        color: AppTheme.primaryGreen.withValues(alpha: 0.45),
                        size: 30,
                      ),
                    ),
                  )
                : Icon(
                    _categoryIcon(item.category),
                    color: AppTheme.primaryGreen.withValues(alpha: 0.45),
                    size: 30,
                  ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? statusFg.withValues(alpha: 0.15)
                            : statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Predicted change
                    isPredictedNegative
                        ? RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              children: [
                                const TextSpan(text: 'Predicted: '),
                                TextSpan(
                                  text: predicted,
                                  style: const TextStyle(
                                      color: Colors.red),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            'Predicted: $predicted',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: predictedColor,
                            ),
                          ),
                    // Check button
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isLowStock
                              ? AppTheme.primaryGreen
                              : AppTheme.primaryGreen.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLowStock ? Icons.check : Icons.check_circle_outline,
                          size: 17,
                          color: isLowStock
                              ? AppTheme.white
                              : AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fruits':
        return Icons.apple;
      case 'vegetables':
        return Icons.eco_outlined;
      case 'dairy':
        return Icons.water_drop_outlined;
      case 'meat & fish':
      case 'meat':
        return Icons.set_meal_outlined;
      case 'grains':
      case 'grains & cereals':
        return Icons.grain;
      case 'canned':
      case 'canned goods':
        return Icons.inventory_2_outlined;
      case 'beverages':
        return Icons.local_cafe_outlined;
      case 'snacks':
        return Icons.cookie_outlined;
      case 'frozen':
      case 'frozen foods':
        return Icons.ac_unit;
      case 'spices':
      case 'spices & condiments':
        return Icons.spa_outlined;
      default:
        return Icons.fastfood_outlined;
    }
  }
}
