import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import '../inventory/add_item_options_screen.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final InventoryRepository _inventoryRepo = InventoryRepository();
  StreamSubscription<List<FoodItem>>? _inventorySub;
  List<FoodItem> _inventoryItems = [];
  bool _loaded = false;
  String _searchQuery = '';
  String _selectedCategory = '';

  final List<String> _categories = [
    'Rice & Grains',    // jollof, fried rice, rice & beans, porridge
    'Noodles & Pasta',  // indomie, spaghetti, noodle stir-fry
    'Soups & Stews',    // egusi, pepper soup, tomato stew
    'Meat & Chicken',   // grilled chicken, suya, beef stew
    'Fish',             // fried fish, fish stew, grilled tilapia
    'Eggs',             // omelette, boiled eggs, egg sauce
    'Beans & Legumes',  // porridge beans, moi moi, akara
    'Bread & Snacks',   // toast, sandwiches, puff puff
    'Veggies & Salad',  // veggie stir-fry, coleslaw, salad
    'Swallow',          // eba, amala, pounded yam, fufu
    'Quick Meals',      // under 15 mins, one-pot, microwave
    'Budget Friendly',  // meals under ₦1,000
  ];

  // Sample recipe data — will be replaced with API/Firestore data
  final List<_RecipeData> _expiringRecipes = const [
    _RecipeData(
      title: 'Jollof Rice with Chicken',
      subtitle: 'Uses: Chicken (Expiring Today)',
      time: '45m',
      rating: '4.8',
      matchPercent: 90,
      imageIcon: Icons.rice_bowl,
    ),
    _RecipeData(
      title: 'Indomie Stir Fry',
      subtitle: 'Uses: Eggs & Veggies (Exp. in 2 days)',
      time: '10m',
      rating: '4.5',
      matchPercent: 85,
      imageIcon: Icons.ramen_dining,
    ),
    _RecipeData(
      title: 'Egg Sauce & Bread',
      subtitle: 'Uses: Tomatoes (Exp. tomorrow)',
      time: '15m',
      rating: '4.3',
      matchPercent: 78,
      imageIcon: Icons.egg_outlined,
    ),
  ];

  final List<_RecipeData> _quickRecipes = const [
    _RecipeData(
      title: 'Indomie Pepper Soup',
      time: '10 mins',
      imageIcon: Icons.ramen_dining,
    ),
    _RecipeData(
      title: 'Fried Plantain & Eggs',
      time: '12 mins',
      imageIcon: Icons.breakfast_dining,
    ),
    _RecipeData(
      title: 'Garri & Groundnut',
      time: '5 mins',
      imageIcon: Icons.rice_bowl,
    ),
    _RecipeData(
      title: 'Spaghetti Jollof',
      time: '20 mins',
      imageIcon: Icons.dinner_dining,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final firebaseService = FirebaseService();
    final uid = firebaseService.currentUser?.uid;
    if (uid != null) {
      final query = await firebaseService.households
          .where('members', arrayContains: uid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final householdId = query.docs.first.id;
        _inventorySub =
            _inventoryRepo.getFoodItems(householdId).listen((items) {
          if (mounted) {
            setState(() {
              _inventoryItems = items;
              _loaded = true;
            });
          }
        });
        return;
      }
    }
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  bool get _hasItems => _inventoryItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: _loaded
            ? _hasItems
                ? _buildActiveState()
                : _buildEmptyState()
            : const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  EMPTY STATE — no items in pantry
  // ══════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _buildEmptyHeader(),
          const SizedBox(height: 16),

          // ── Search Bar ──
          _buildSearchBar(),
          const SizedBox(height: 24),

          // ── Explore by Category ──
          _buildCategorySection(),
          const SizedBox(height: 28),

          // ── Use It Before You Lose It — empty ──
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Use It Before You Lose It',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dashed empty card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.fieldBorderColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      color: AppTheme.primaryGreen.withValues(alpha: 0.6),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your inventory is empty. Add food\nitems to see personalized recipe\nrecommendations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: AppTheme.subtitleGrey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Add Your First Item CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => AddItemOptionsScreen.show(context),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Add Your First Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Start tracking to discover recipes!',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: AppTheme.subtitleGrey,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Quick & Easy header (empty teaser)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Quick & Easy',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick & Easy empty prompt
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.fieldBorderColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.bolt, color: AppTheme.subtitleGrey, size: 28),
                  SizedBox(height: 10),
                  Text(
                    'Quick recipes will appear here\nbased on what\'s in your pantry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: AppTheme.subtitleGrey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Empty header: avatar + title + bell ──
  Widget _buildEmptyHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryGreen,
            ),
            child: const Icon(Icons.person, color: AppTheme.white, size: 20),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Recipes',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          // Notification bell
          const Icon(
            Icons.notifications_outlined,
            color: AppTheme.primaryGreen,
            size: 24,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  ACTIVE STATE — has items in pantry
  // ══════════════════════════════════════════════════
  Widget _buildActiveState() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _buildActiveHeader(),
          const SizedBox(height: 16),

          // ── Use It Before You Lose It ──
          _buildExpiringSection(),
          const SizedBox(height: 24),

          // ── Quick & Easy ──
          _buildQuickEasySection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Active header: SabiTrak + search + icons ──
  Widget _buildActiveHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Leaf icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.eco, color: AppTheme.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'SabiTrak',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.tune,
                    color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.notifications_outlined,
                    color: AppTheme.primaryGreen, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search recipes or ingredients...',
                hintStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: AppTheme.fieldHintColor,
                ),
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.subtitleGrey, size: 20),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared search bar for empty state ──
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search recipes...',
            hintStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: AppTheme.fieldHintColor,
            ),
            prefixIcon:
                const Icon(Icons.search, color: AppTheme.subtitleGrey, size: 20),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // ── Explore by Category chips ──
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'EXPLORE BY CATEGORY',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.subtitleGrey,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = isSelected ? '' : cat;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.fieldBorderColor,
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
                          : AppTheme.primaryGreen,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Use It Before You Lose It — horizontal cards ──
  Widget _buildExpiringSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: const Color(0xFFE65100), size: 20),
              const SizedBox(width: 6),
              const Text(
                'Use It Before You Lose It',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.subtitleGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _expiringRecipes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _ExpiringRecipeCard(
              recipe: _expiringRecipes[i],
            ),
          ),
        ),
      ],
    );
  }

  // ── Quick & Easy — 2-column grid ──
  Widget _buildQuickEasySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.bolt, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 6),
              const Text(
                'Quick & Easy',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.subtitleGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: _quickRecipes.length,
            itemBuilder: (_, i) => _QuickRecipeCard(
              recipe: _quickRecipes[i],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  Data model for sample recipes
// ═══════════════════════════════════════════════════

class _RecipeData {
  final String title;
  final String? subtitle;
  final String time;
  final String? rating;
  final int? matchPercent;
  final IconData imageIcon;

  const _RecipeData({
    required this.title,
    this.subtitle,
    required this.time,
    this.rating,
    this.matchPercent,
    required this.imageIcon,
  });
}

// ═══════════════════════════════════════════════════
//  Expiring Recipe Card (horizontal scroll)
// ═══════════════════════════════════════════════════

class _ExpiringRecipeCard extends StatelessWidget {
  final _RecipeData recipe;

  const _ExpiringRecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area with match badge
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D5B7),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: Icon(
                      recipe.imageIcon,
                      size: 48,
                      color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                // Match percentage badge
                if (recipe.matchPercent != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${recipe.matchPercent}% MATCH',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  if (recipe.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.eco,
                            size: 12, color: AppTheme.primaryGreen),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            recipe.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              color: AppTheme.subtitleGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 14, color: AppTheme.subtitleGrey),
                      const SizedBox(width: 4),
                      Text(
                        recipe.time,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: AppTheme.subtitleGrey,
                        ),
                      ),
                      if (recipe.rating != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.star,
                            size: 14, color: Color(0xFFFFC107)),
                        const SizedBox(width: 2),
                        Text(
                          recipe.rating!,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            color: AppTheme.subtitleGrey,
                          ),
                        ),
                      ],
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

// ═══════════════════════════════════════════════════
//  Quick & Easy Recipe Card (grid)
// ═══════════════════════════════════════════════════

class _QuickRecipeCard extends StatelessWidget {
  final _RecipeData recipe;

  const _QuickRecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(
                    recipe.imageIcon,
                    size: 40,
                    color: AppTheme.subtitleGrey.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            // Title + time
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 13, color: AppTheme.subtitleGrey),
                      const SizedBox(width: 4),
                      Text(
                        recipe.time,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: AppTheme.subtitleGrey,
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
