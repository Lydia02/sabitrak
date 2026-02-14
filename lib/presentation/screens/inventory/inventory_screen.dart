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
  String _selectedStorage = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _storageTabs = [
    'All',
    'Fridge',
    'Freezer',
    'Cupboard',
    'Counter',
    'Shelf',
    'Bag/Basket',
  ];

  static const List<String> _statusFilters = [
    'All',
    'Expiring Soon',
    'Expired',
    'Fresh',
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

    // Filter by storage location
    if (_selectedStorage != 'All') {
      filtered = filtered
          .where((item) =>
              item.storageLocation.toLowerCase() ==
              _selectedStorage.toLowerCase())
          .toList();
    }

    // Filter by status
    if (_selectedStatus == 'Expiring Soon') {
      filtered = filtered.where((item) => item.isExpiringSoon).toList();
    } else if (_selectedStatus == 'Expired') {
      filtered = filtered.where((item) => item.isExpired).toList();
    } else if (_selectedStatus == 'Fresh') {
      filtered = filtered
          .where((item) => !item.isExpired && !item.isExpiringSoon)
          .toList();
    }

    // Filter by search
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inventory',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search your inventory...',
                    hintStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      color: AppTheme.fieldHintColor,
                    ),
                    prefixIcon: Icon(Icons.search, color: AppTheme.subtitleGrey),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Storage Tabs ──
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _storageTabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = _storageTabs[index];
                  final isSelected = _selectedStorage == tab;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStorage = tab),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppTheme.primaryGreen : AppTheme.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.fieldBorderColor,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? AppTheme.white
                              : AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // ── Status Filter Chips ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                children: _statusFilters
                    .where((s) => s != 'All')
                    .map((status) {
                  final isSelected = _selectedStatus == status;
                  Color chipColor;
                  Color textColor;
                  Color borderColor;
                  if (status == 'Expiring Soon') {
                    chipColor = isSelected
                        ? const Color(0xFFFFF3E0)
                        : AppTheme.white;
                    textColor = const Color(0xFFE65100);
                    borderColor = const Color(0xFFE65100);
                  } else if (status == 'Expired') {
                    chipColor = isSelected
                        ? const Color(0xFFFFEBEE)
                        : AppTheme.white;
                    textColor = const Color(0xFFC62828);
                    borderColor = const Color(0xFFC62828);
                  } else {
                    chipColor = isSelected
                        ? const Color(0xFFE8F5E9)
                        : AppTheme.white;
                    textColor = AppTheme.primaryGreen;
                    borderColor = AppTheme.primaryGreen;
                  }
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedStatus = isSelected ? 'All' : status;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isSelected ? borderColor : AppTheme.fieldBorderColor,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? textColor : AppTheme.subtitleGrey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Items List or Empty State ──
            Expanded(
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryGreen,
                              strokeWidth: 2,
                            ),
                          );
                        }

                        final items = _filterItems(snapshot.data ?? []);

                        if ((snapshot.data ?? []).isEmpty) {
                          return _buildEmptyState();
                        }

                        if (items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 48,
                                    color: AppTheme.subtitleGrey
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No items match your filters',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    color: AppTheme.subtitleGrey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _InventoryItemCard(item: items[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // ── FAB ──
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddItem,
        backgroundColor: AppTheme.primaryGreen,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppTheme.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                  color: AppTheme.fieldBorderColor.withValues(alpha: 0.4),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 52,
                color: AppTheme.subtitleGrey.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your inventory is empty',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add food items to see personalized recipe recommendations and track expiry dates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: AppTheme.subtitleGrey,
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

// ═══════════════════════════════════════════════════
//  Inventory Item Card
// ═══════════════════════════════════════════════════

class _InventoryItemCard extends StatelessWidget {
  final FoodItem item;

  const _InventoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final totalShelfLife =
        item.expiryDate.difference(item.purchaseDate).inDays;
    final remaining = totalShelfLife > 0
        ? ((days.clamp(0, totalShelfLife)) / totalShelfLife)
        : 0.0;

    // Status badge
    String statusText;
    Color statusBgColor;
    Color statusTextColor;
    Color progressColor;

    if (item.isExpired) {
      statusText = 'EXPIRED';
      statusBgColor = const Color(0xFFFFEBEE);
      statusTextColor = const Color(0xFFC62828);
      progressColor = const Color(0xFFC62828);
    } else if (item.isExpiringSoon) {
      statusText = '${days}D LEFT';
      statusBgColor = const Color(0xFFFFF3E0);
      statusTextColor = const Color(0xFFE65100);
      progressColor = const Color(0xFFE65100);
    } else if (days <= 14) {
      statusText = '$days DAYS';
      statusBgColor = const Color(0xFFFFF3E0);
      statusTextColor = const Color(0xFFE65100);
      progressColor = const Color(0xFFE65100);
    } else {
      statusText = 'FRESH';
      statusBgColor = const Color(0xFFE8F5E9);
      statusTextColor = AppTheme.primaryGreen;
      progressColor = AppTheme.primaryGreen;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
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
          // Thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _categoryIcon(item.category),
              color: AppTheme.primaryGreen.withValues(alpha: 0.5),
              size: 28,
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
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.straighten,
                        size: 13, color: AppTheme.subtitleGrey.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      '${item.quantity} ${item.unit}',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: AppTheme.subtitleGrey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '\u2022',
                      style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          color: AppTheme.subtitleGrey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.storageLocation,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: AppTheme.subtitleGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Shelf life bar
                Row(
                  children: [
                    const Text(
                      'SHELF LIFE',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.subtitleGrey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(remaining * 100).round()}% REMAINING',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: statusTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: remaining.toDouble(),
                    minHeight: 5,
                    backgroundColor:
                        AppTheme.fieldBorderColor.withValues(alpha: 0.3),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(progressColor),
                  ),
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
