import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import 'add_item_options_screen.dart';
import 'update_pantry_sheet.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final InventoryRepository _repo = InventoryRepository();
  String? _householdId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Storage location tabs
  static const List<String> _storageTabs = [
    'All',
    'Fridge',
    'Freezer',
    'Pantry',
  ];
  int _selectedTabIndex = 0;

  // Status filter chips
  static const List<String> _statusFilters = ['All', 'Expiring Soon', 'Expired', 'Fresh'];
  String _selectedStatus = 'All';

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

    // Storage tab filter
    if (_selectedTabIndex != 0) {
      final tab = _storageTabs[_selectedTabIndex].toLowerCase();
      filtered = filtered.where((item) {
        final loc = item.storageLocation.toLowerCase();
        if (tab == 'pantry') {
          // Pantry = anything not fridge/freezer
          return !loc.contains('fridge') && !loc.contains('freezer');
        }
        return loc.contains(tab);
      }).toList();
    }

    // Status chip filter
    switch (_selectedStatus) {
      case 'Expiring Soon':
        filtered = filtered.where((i) => i.isExpiringSoon && !i.isExpired).toList();
        break;
      case 'Expired':
        filtered = filtered.where((i) => i.isExpired).toList();
        break;
      case 'Fresh':
        filtered = filtered.where((i) => !i.isExpiringSoon && !i.isExpired).toList();
        break;
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // FIFO sort: use soonest-expiring items first (expired pushed to bottom)
    filtered.sort((a, b) {
      if (a.isExpired && !b.isExpired) return 1;
      if (!a.isExpired && b.isExpired) return -1;
      return a.expiryDate.compareTo(b.expiryDate);
    });

    return filtered;
  }

  void _openAddItem() {
    AddItemOptionsScreen.show(context);
  }

  void _openUpdateSheet(FoodItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdatePantrySheet(item: item, repo: _repo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? Colors.white60 : Colors.black45;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
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

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top bar ───────────────────────────────────────────
                      Container(
                        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'My Inventory',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${allItems.length} items',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Search bar
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                                style: TextStyle(color: textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search food items...',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    color: subtitleColor,
                                  ),
                                  prefixIcon: Icon(Icons.search,
                                      color: subtitleColor, size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                          child: Icon(Icons.close,
                                              color: subtitleColor, size: 18),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Storage tabs
                            Row(
                              children: List.generate(_storageTabs.length, (i) {
                                final isSelected = _selectedTabIndex == i;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedTabIndex = i),
                                    child: Container(
                                      margin: EdgeInsets.only(
                                          right: i < _storageTabs.length - 1
                                              ? 8
                                              : 0),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryGreen
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryGreen
                                              : (isDark
                                                  ? Colors.white24
                                                  : Colors.black12),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _storageTabs[i],
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : subtitleColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 10),

                            // Status filter chips
                            SizedBox(
                              height: 32,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _statusFilters.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final f = _statusFilters[i];
                                  final isSelected = _selectedStatus == f;
                                  Color chipColor;
                                  if (f == 'Expiring Soon') {
                                    chipColor = const Color(0xFFD97706);
                                  } else if (f == 'Expired') {
                                    chipColor = const Color(0xFFDC2626);
                                  } else if (f == 'Fresh') {
                                    chipColor = AppTheme.primaryGreen;
                                  } else {
                                    chipColor = isDark
                                        ? Colors.white54
                                        : Colors.black54;
                                  }
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedStatus = f),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? chipColor.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? chipColor
                                              : (isDark
                                                  ? Colors.white24
                                                  : Colors.black12),
                                        ),
                                      ),
                                      child: Text(
                                        f.toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: isSelected
                                              ? chipColor
                                              : subtitleColor,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),

                      // ── List ────────────────────────────────────────────
                      Expanded(
                        child: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryGreen,
                                  strokeWidth: 2,
                                ),
                              )
                            : allItems.isEmpty
                                ? _buildEmptyState(textColor, subtitleColor)
                                : filteredItems.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(40),
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
                                    : ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 12, 16, 100),
                                        itemCount: filteredItems.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (_, i) {
                                          // Mark the first non-expired item as "USE FIRST" (FIFO)
                                          final firstNonExpiredIndex = filteredItems
                                              .indexWhere((item) => !item.isExpired);
                                          return _InventoryItemCard(
                                            item: filteredItems[i],
                                            isDark: isDark,
                                            cardColor: cardColor,
                                            textColor: textColor,
                                            subtitleColor: subtitleColor,
                                            onTap: () => _openUpdateSheet(filteredItems[i]),
                                            showUseFist: i == firstNonExpiredIndex,
                                          );
                                        },
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
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subtitleColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 72, color: subtitleColor.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              'Your inventory is empty',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add food items to track expiry dates and get recipe suggestions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: subtitleColor,
                height: 1.5,
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

// ── Item Card ─────────────────────────────────────────────────────────────────
class _InventoryItemCard extends StatelessWidget {
  final FoodItem item;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onTap;
  final bool showUseFist;

  const _InventoryItemCard({
    required this.item,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
    required this.onTap,
    this.showUseFist = false,
  });

  // Determine shelf life fraction remaining (0.0 – 1.0)
  double get _shelfFraction {
    final total = item.expiryDate.difference(item.purchaseDate).inDays;
    if (total <= 0) return 0;
    final remaining = item.expiryDate.difference(DateTime.now()).inDays;
    return (remaining / total).clamp(0.0, 1.0);
  }

  // Percentage of shelf life remaining
  int get _shelfPercent => (_shelfFraction * 100).round();

  Color get _shelfBarColor {
    if (item.isExpired) return const Color(0xFFDC2626);
    if (item.isExpiringSoon) return const Color(0xFFD97706);
    if (_shelfFraction > 0.5) return AppTheme.primaryGreen;
    return const Color(0xFFEAB308); // yellow for 20–50%
  }

  // Status chip
  ({String label, Color bg, Color fg}) get _statusChip {
    if (item.isExpired) {
      return (
        label: 'EXPIRED',
        bg: const Color(0xFFFFEBEE),
        fg: const Color(0xFFDC2626),
      );
    } else if (item.isExpiringSoon) {
      return (
        label: 'EXPIRING SOON',
        bg: const Color(0xFFFFF3CD),
        fg: const Color(0xFFD97706),
      );
    } else {
      return (
        label: 'FRESH',
        bg: const Color(0xFFDCFCE7),
        fg: AppTheme.primaryGreen,
      );
    }
  }

  // Display quantity string (handles kg decimals)
  String get _qtyDisplay {
    final unit = item.unit;
    final qty = item.quantity;
    // Show decimal only for weight units if needed
    final isWeight =
        unit.toLowerCase() == 'kg' || unit.toLowerCase() == 'grams';
    if (isWeight && qty < 1000) {
      // qty is stored as grams internally if unit=Grams
      return '$qty';
    }
    return '$qty';
  }

  // Storage location icon
  IconData _storageIcon(String loc) {
    final l = loc.toLowerCase();
    if (l.contains('fridge')) return Icons.kitchen_outlined;
    if (l.contains('freezer')) return Icons.ac_unit;
    if (l.contains('cupboard') || l.contains('shelf')) return Icons.shelves;
    if (l.contains('counter')) return Icons.countertops_outlined;
    if (l.contains('bag') || l.contains('basket')) {
      return Icons.shopping_basket_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
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
        return Icons.grain;
      case 'canned':
        return Icons.inventory_2_outlined;
      case 'beverages':
        return Icons.local_cafe_outlined;
      case 'snacks':
        return Icons.cookie_outlined;
      case 'frozen':
        return Icons.ac_unit;
      case 'spices':
        return Icons.spa_outlined;
      default:
        return Icons.fastfood_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = _statusChip;
    final fraction = _shelfFraction;
    final barColor = _shelfBarColor;
    final chipBg = isDark ? chip.fg.withValues(alpha: 0.18) : chip.bg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ───────────────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Icon(
                          _categoryIcon(item.category),
                          color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                          size: 32,
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          _categoryIcon(item.category),
                          color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                          size: 32,
                        ),
                      ),
                    )
                  : Icon(
                      _categoryIcon(item.category),
                      color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                      size: 32,
                    ),
            ),
            const SizedBox(width: 14),

            // ── Info ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status chip
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (showUseFist)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF1565C0).withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'USE FIRST',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1565C0),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          chip.label,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: chip.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Quantity + storage location
                  Row(
                    children: [
                      Text(
                        '$_qtyDisplay ${item.unit}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(_storageIcon(item.storageLocation),
                          size: 13, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        item.storageLocation,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Shelf life progress bar
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Shelf life',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 10,
                                    color: subtitleColor,
                                  ),
                                ),
                                Text(
                                  item.isExpired
                                      ? 'Expired'
                                      : '${item.daysUntilExpiry}d left',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: barColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? Colors.white12
                                    : Colors.black.withValues(alpha: 0.07),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(barColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // % badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$_shelfPercent%',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: barColor,
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
      ),
    );
  }
}
