import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import '../../../services/food_image_service.dart';
import '../../../services/food_intelligence_service.dart';
import '../../widgets/error_modal.dart';

class ManualEntryScreen extends StatefulWidget {
  final String? prefilledName;
  final String? prefilledCategory;
  final String? prefilledBarcode;
  final String? prefilledImageUrl;
  final DateTime? prefilledExpiryDate;
  final ItemType initialItemType;

  const ManualEntryScreen({
    super.key,
    this.prefilledName,
    this.prefilledCategory,
    this.prefilledBarcode,
    this.prefilledImageUrl,
    this.prefilledExpiryDate,
    this.initialItemType = ItemType.ingredient,
  });

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
  late ItemType _itemType;

  final _intelligenceService = FoodIntelligenceService();
  final _repo = InventoryRepository();
  FoodSuggestion? _currentSuggestion;
  Timer? _nameSuggestionDebounce;
  bool _userOverrodeCategory = false;
  bool _userOverrodeStorage = false;
  // For leftover mode: matched raw ingredient in pantry
  FoodItem? _linkedIngredient;

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

  int get _suggestedDays {
    if (_itemType == ItemType.leftover) return 3;
    return _currentSuggestion?.shelfLifeDays ??
        _shelfLifeDefaults[_selectedCategory] ??
        14;
  }

  String get _shelfLifeLabel =>
      _currentSuggestion?.shelfLifeLabel ?? '${_suggestedDays}d';

  @override
  void initState() {
    super.initState();
    _itemType = widget.initialItemType;
    if (_itemType == ItemType.leftover) _selectedStorage = 'Fridge';
    _loadHouseholdId();
    if (widget.prefilledName != null) {
      _nameController.text = widget.prefilledName!;
      // Apply suggestion immediately for pre-filled names
      _applyNameSuggestion(widget.prefilledName!);
    }
    if (widget.prefilledCategory != null &&
        _categories.contains(widget.prefilledCategory)) {
      _selectedCategory = widget.prefilledCategory!;
      _userOverrodeCategory = true;
    }
    // Listen to name changes and auto-suggest
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    _nameSuggestionDebounce?.cancel();
    _nameSuggestionDebounce = Timer(const Duration(milliseconds: 350), () {
      _applyNameSuggestion(_nameController.text);
    });
  }

  void _applyNameSuggestion(String name) {
    if (name.trim().isEmpty) {
      if (mounted) setState(() { _currentSuggestion = null; _linkedIngredient = null; });
      return;
    }
    final suggestion = _intelligenceService.suggest(name);
    if (!mounted) return;
    setState(() {
      _currentSuggestion = suggestion;
      if (!_userOverrodeCategory) _selectedCategory = suggestion.category;
      if (!_userOverrodeStorage) {
        _selectedStorage = _itemType == ItemType.leftover ? 'Fridge' : suggestion.storageLocation;
      }
    });
    // For leftovers: auto-look up matching raw ingredient in pantry
    if (_itemType == ItemType.leftover && _householdId != null) {
      _repo.findDuplicate(name, _householdId!, itemType: ItemType.ingredient)
          .then((match) { if (mounted) setState(() => _linkedIngredient = match); });
    }
  }

  Future<void> _loadHouseholdId() async {
    final uid = FirebaseService().currentUser?.uid;
    if (uid == null) return;
    final query =
        await FirebaseService().households
            .where('members', arrayContains: uid)
            .limit(1)
            .get();
    if (query.docs.isNotEmpty && mounted) {
      setState(() => _householdId = query.docs.first.id);
    }
  }

  Future<void> _showDeductDialog() async {
    if (_linkedIngredient == null) return;
    final ingredient = _linkedIngredient!;
    int deductQty = _quantity;

    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Deduct from ${ingredient.name}?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Current stock: ${ingredient.quantity} ${ingredient.unit}',
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 13)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: deductQty > 1 ? () => setS(() => deductQty--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$deductQty ${ingredient.unit}',
                  style: const TextStyle(fontFamily: 'Roboto',
                      fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: deductQty < ingredient.quantity
                    ? () => setS(() => deductQty++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              onPressed: () => Navigator.pop(ctx, deductQty),
              child: const Text('Deduct', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != null && confirmed > 0) {
      final newQty = ingredient.quantity - confirmed;
      if (newQty <= 0) {
        await _repo.deleteFoodItem(ingredient.id);
      } else {
        await _repo.updateFoodItem(ingredient.id, {'quantity': newQty});
      }
      if (mounted) setState(() => _linkedIngredient = null);
    }
  }

  Future<void> _addToInventory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showErrorModal(context, title: 'Missing Name', message: 'Please enter a food name.');
      return;
    }
    if (_householdId == null) {
      showErrorModal(context, title: 'Error', message: 'No household found. Please try again.');
      return;
    }

    // ── Duplicate check (ingredients + leftovers) ───────────────────────────
    if (_itemType == ItemType.ingredient || _itemType == ItemType.leftover) {
      final duplicate = await _repo.findDuplicate(name, _householdId!, itemType: _itemType);
      if (duplicate != null && mounted) {
        final isLeftover = _itemType == ItemType.leftover;
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isLeftover ? 'Leftover Already Logged' : 'Item Already Exists'),
            content: Text(
              '"${duplicate.name}" is already in your ${isLeftover ? 'leftovers' : 'pantry'} '
              '(${duplicate.quantity} ${duplicate.unit}, ${duplicate.storageLocation}).\n\n'
              'What would you like to do?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'add_anyway'),
                child: const Text('Add Separate'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: Text(isLeftover ? 'Add to Existing' : 'Update Quantity',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (action == null || action == 'cancel') return;
        if (action == 'merge') {
          await _repo.mergeQuantity(duplicate.id, _quantity);
          if (!mounted) return;
          showSuccessModal(context, title: 'Updated!',
              message: 'Added $_quantity to your existing ${duplicate.name}.');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          });
          return;
        }
        // 'add_anyway' falls through to create a new separate entry
      }
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final expiryDate = widget.prefilledExpiryDate ?? now.add(Duration(days: _suggestedDays));
      final uid = FirebaseService().currentUser?.uid ?? '';

      final item = FoodItem(
        id: '',
        name: name,
        barcode: widget.prefilledBarcode ?? '',
        category: _selectedCategory,
        quantity: _quantity,
        unit: _selectedUnit,
        purchaseDate: now,
        expiryDate: expiryDate,
        storageLocation: _selectedStorage,
        imageUrl: widget.prefilledImageUrl,
        householdId: _householdId!,
        addedBy: uid,
        createdAt: now,
        itemType: _itemType,
      );

      final docRef = await _repo.addFoodItem(item).then((_) async {
        // re-fetch to get the doc reference for image update
        return FirebaseService().foodItems
            .where('householdId', isEqualTo: _householdId)
            .where('name', isEqualTo: name)
            .limit(1)
            .get()
            .then((s) => s.docs.isNotEmpty ? s.docs.first.reference : null);
      });

      if (widget.prefilledImageUrl == null && docRef != null) {
        FoodImageService.findImageUrl(name).then((imgUrl) {
          if (imgUrl != null && imgUrl.isNotEmpty) {
            docRef.update({'imageUrl': imgUrl});
          }
        });
      }

      if (!mounted) return;
      showSuccessModal(
        context,
        title: 'Item Added!',
        message: '$name has been added to your inventory.',
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // Pop back to the root route safely regardless of stack depth
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorModal(
          context,
          title: 'Error',
          message: 'Failed to add item: $e',
        );
      }
    }
  }

  @override
  void dispose() {
    _nameSuggestionDebounce?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor =
        isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final borderColor =
        isDark
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
                      widget.prefilledBarcode != null
                          ? 'Scanned Item'
                          : 'Add Item',
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

                    // ── Item Type Toggle ─────────────────────────────────────
                    Text(
                      'ITEM TYPE',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      _TypeChip(
                        label: 'Ingredient',
                        icon: Icons.kitchen_outlined,
                        selected: _itemType == ItemType.ingredient,
                        onTap: () => setState(() {
                          _itemType = ItemType.ingredient;
                          _userOverrodeStorage = false;
                          _applyNameSuggestion(_nameController.text);
                        }),
                        cardColor: cardColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: 'Leftover',
                        icon: Icons.rice_bowl_outlined,
                        selected: _itemType == ItemType.leftover,
                        onTap: () => setState(() {
                          _itemType = ItemType.leftover;
                          // Auto-set fridge + 3-day shelf life for leftovers
                          if (!_userOverrodeStorage) _selectedStorage = 'Fridge';
                        }),
                        cardColor: cardColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: 'Product',
                        icon: Icons.shopping_bag_outlined,
                        selected: _itemType == ItemType.product,
                        onTap: () => setState(() => _itemType = ItemType.product),
                        cardColor: cardColor,
                        borderColor: borderColor,
                      ),
                    ]),
                    if (_itemType == ItemType.leftover) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Leftover: auto-set to Fridge with 3-day shelf life.',
                              style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                                  color: subtitleColor),
                            ),
                          ),
                        ]),
                      ),
                      if (_linkedIngredient != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            const Icon(Icons.link, color: AppTheme.primaryGreen, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Found "${_linkedIngredient!.name}" in pantry (${_linkedIngredient!.quantity} ${_linkedIngredient!.unit}). Deduct used amount?',
                                style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: subtitleColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showDeductDialog(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Deduct', style: TextStyle(
                                    fontFamily: 'Roboto', fontSize: 11,
                                    fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),

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
                            horizontal: 16,
                            vertical: 14,
                          ),
                          suffixIcon: const Icon(
                            Icons.auto_awesome,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
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
                        if (_currentSuggestion != null)
                          GestureDetector(
                            onTap:
                                () => setState(
                                  () => _userOverrodeCategory = false,
                                ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: AppTheme.primaryGreen,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _userOverrodeCategory
                                      ? 'TAP TO RESTORE AI'
                                      : 'AI SUGGESTED',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return GestureDetector(
                              onTap:
                                  () => setState(() {
                                    _selectedCategory = cat;
                                    _userOverrodeCategory = true;
                                  }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? AppTheme.primaryGreen
                                          : cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        isSelected
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
                                    color:
                                        isSelected ? AppTheme.white : textColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Storage Location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        if (_currentSuggestion != null)
                          GestureDetector(
                            onTap:
                                () => setState(
                                  () => _userOverrodeStorage = false,
                                ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: AppTheme.primaryGreen,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _userOverrodeStorage
                                      ? 'TAP TO RESTORE AI'
                                      : 'AI SUGGESTED',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _storageLocations.map((loc) {
                            final isSelected = _selectedStorage == loc;
                            return GestureDetector(
                              onTap:
                                  () => setState(() {
                                    _selectedStorage = loc;
                                    _userOverrodeStorage = true;
                                  }),
                              child: Container(
                                width:
                                    (MediaQuery.of(context).size.width -
                                        40 -
                                        24) /
                                    4,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? AppTheme.primaryGreen
                                          : cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? AppTheme.primaryGreen
                                            : borderColor,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _storageIcons[loc] ?? Icons.storage,
                                      color:
                                          isSelected
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
                                        color:
                                            isSelected
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
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: AppTheme.primaryGreen,
                            size: 18,
                          ),
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
                                  _currentSuggestion != null &&
                                          _currentSuggestion!.tip.isNotEmpty
                                      ? _currentSuggestion!.tip
                                      : 'Suggested for $_selectedCategory',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 12,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.prefilledExpiryDate != null
                                  ? '${widget.prefilledExpiryDate!.day}/${widget.prefilledExpiryDate!.month}/${widget.prefilledExpiryDate!.year}'
                                  : _shelfLifeLabel,
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
                        widget.prefilledExpiryDate != null
                            ? 'Expiry date captured from label.'
                            : 'Based on standard ${_selectedStorage.toLowerCase()} storage.',
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
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
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
                              child: Icon(
                                Icons.remove,
                                size: 18,
                                color: subtitleColor,
                              ),
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
                            items:
                                _units
                                    .map(
                                      (u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(u),
                                      ),
                                    )
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
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: AppTheme.white,
                              ),
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
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.white,
                                  ),
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

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color cardColor;
  final Color borderColor;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.cardColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryGreen : cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryGreen : borderColor,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20,
                color: selected ? Colors.white : AppTheme.subtitleGrey),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.subtitleGrey,
                )),
          ]),
        ),
      ),
    );
  }
}
