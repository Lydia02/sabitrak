import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../services/firebase_service.dart';
import '../../widgets/error_modal.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _nameController = TextEditingController();
  String _selectedCategory = 'Fruits';
  String _selectedStorage = 'Counter';
  int _quantity = 1;
  String _selectedUnit = 'Pieces';
  bool _isLoading = false;
  String? _householdId;

  static const List<String> _categories = [
    'Fruits',
    'Vegetables',
    'Dairy',
    'Meat & Fish',
    'Grains',
    'Canned',
    'Spices',
    'Beverages',
    'Snacks',
    'Frozen',
    'Other',
  ];

  static const List<String> _storageLocations = [
    'Fridge',
    'Freezer',
    'Cupboard',
    'Counter',
    'Shelf',
    'Bag/Basket',
  ];

  static const List<String> _units = [
    'Pieces',
    'Kg',
    'Grams',
    'Litres',
    'Packs',
    'Bags',
    'Bunch',
    'Cans',
    'Bottles',
  ];

  static const Map<String, IconData> _storageIcons = {
    'Fridge': Icons.kitchen_outlined,
    'Freezer': Icons.ac_unit,
    'Cupboard': Icons.door_sliding_outlined,
    'Counter': Icons.countertops_outlined,
    'Shelf': Icons.shelves,
    'Bag/Basket': Icons.shopping_basket_outlined,
  };

  static const Map<String, int> _shelfLifeDefaults = {
    'Fruits': 5,
    'Vegetables': 5,
    'Dairy': 7,
    'Meat & Fish': 3,
    'Grains': 90,
    'Canned': 365,
    'Spices': 180,
    'Beverages': 30,
    'Snacks': 30,
    'Frozen': 90,
    'Other': 14,
  };

  int get _suggestedDays => _shelfLifeDefaults[_selectedCategory] ?? 14;

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

  Future<void> _addToInventory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showErrorModal(context,
          title: 'Missing Name', message: 'Please enter a food name.');
      return;
    }
    if (_householdId == null) {
      showErrorModal(context,
          title: 'Error', message: 'No household found. Please try again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: _suggestedDays));
      final uid = FirebaseService().currentUser?.uid ?? '';

      final item = FoodItem(
        id: '',
        name: name,
        barcode: '',
        category: _selectedCategory,
        quantity: _quantity,
        unit: _selectedUnit,
        purchaseDate: now,
        expiryDate: expiryDate,
        storageLocation: _selectedStorage,
        householdId: _householdId!,
        addedBy: uid,
        createdAt: now,
      );

      await FirebaseService().foodItems.add(item.toFirestore());

      if (!mounted) return;
      showSuccessModal(
        context,
        title: 'Item Added!',
        message: '$name has been added to your inventory.',
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorModal(context,
            title: 'Error', message: 'Failed to add item: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: textColor),
                  ),
                  Expanded(
                    child: Text(
                      'Add Item',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Food Name
                    Text(
                      'FOOD NAME',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Enter food name',
                          hintStyle: TextStyle(color: subtitleColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon: const Icon(Icons.auto_awesome,
                              color: AppTheme.primaryGreen, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CATEGORY',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const Text(
                          'AI SUGGESTION',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryGreen
                                    : borderColor,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.white
                                    : textColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Storage Location
                    Text(
                      'STORAGE LOCATION',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _storageLocations.map((loc) {
                        final isSelected = _selectedStorage == loc;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedStorage = loc),
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 40 - 24) / 4,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryGreen
                                    : borderColor,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _storageIcons[loc] ?? Icons.storage,
                                  color: isSelected
                                      ? AppTheme.white
                                      : subtitleColor,
                                  size: 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.white
                                        : textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Smart Shelf Life
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
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
                          const Icon(Icons.auto_awesome,
                              color: AppTheme.primaryGreen, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Smart Shelf Life',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Suggested for $_selectedCategory\nTypical Freshness',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 12,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '+$_suggestedDays\nDAYS',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.white,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Based on standard ${_selectedStorage.toLowerCase()} storage.',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quantity + Unit
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
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
                          Text(
                            'Quantity',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          const Spacer(),
                          // Minus
                          GestureDetector(
                            onTap: () {
                              if (_quantity > 1) {
                                setState(() => _quantity--);
                              }
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor),
                              ),
                              child: Icon(Icons.remove,
                                  size: 18, color: subtitleColor),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$_quantity',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Unit dropdown
                          DropdownButton<String>(
                            value: _selectedUnit,
                            underline: const SizedBox(),
                            dropdownColor: cardColor,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            items: _units
                                .map((u) => DropdownMenuItem(
                                    value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedUnit = v);
                            },
                          ),
                          const SizedBox(width: 8),
                          // Plus
                          GestureDetector(
                            onTap: () => setState(() => _quantity++),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryGreen,
                              ),
                              child: const Icon(Icons.add,
                                  size: 18, color: AppTheme.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Add to Inventory button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addToInventory,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.white),
                              )
                            : const Text('Add to Inventory'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
