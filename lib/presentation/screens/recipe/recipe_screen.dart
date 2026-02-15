import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
import '../inventory/add_item_options_screen.dart';
import '../profile/notification_inbox_screen.dart';

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
  int _unreadCount = 0;

  final List<String> _categories = [
    'Rice & Grains',
    'Noodles & Pasta',
    'Soups & Stews',
    'Meat & Chicken',
    'Fish',
    'Eggs',
    'Beans & Legumes',
    'Bread & Snacks',
    'Veggies & Salad',
    'Swallow',
    'Quick Meals',
    'Budget Friendly',
  ];

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
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final svc = NotificationService();
    final notifications = await svc.fetchNotifications();
    final lastRead = await svc.getLastReadAt();
    final unread = notifications
        .where((n) => lastRead == null || n.createdAt.isAfter(lastRead))
        .length;
    if (mounted) setState(() => _unreadCount = unread);
  }

  void _openNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationInboxScreen()))
        .then((_) => _loadUnreadCount());
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.backgroundColor;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.fieldBorderColor;

    return Scaffold(
      body: SafeArea(
        child: _loaded
            ? _hasItems
                ? _buildActiveState(isDark, textColor, subtitleColor, cardColor, bgColor, borderColor)
                : _buildEmptyState(isDark, textColor, subtitleColor, cardColor, bgColor, borderColor)
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
  //  EMPTY STATE
  // ══════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color bgColor, Color borderColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmptyHeader(textColor),
          const SizedBox(height: 16),
          _buildSearchBar(isDark, subtitleColor, bgColor),
          const SizedBox(height: 24),
          _buildCategorySection(isDark, textColor, subtitleColor, cardColor, borderColor),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Use It Before You Lose It',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
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
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.5),
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
                  Text(
                    'Your inventory is empty. Add food\nitems to see personalized recipe\nrecommendations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: subtitleColor,
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
          Center(
            child: Text(
              'Start tracking to discover recipes!',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: subtitleColor,
              ),
            ),
          ),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Quick & Easy',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
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
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.bolt, color: subtitleColor, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    'Quick recipes will appear here\nbased on what\'s in your pantry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: subtitleColor,
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

  Widget _buildEmptyHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryGreen,
            ),
            child: const Icon(Icons.person, color: AppTheme.white, size: 20),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Recipes',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _openNotifications,
            child: Stack(clipBehavior: Clip.none, children: [
              Icon(Icons.notifications_outlined, color: textColor, size: 24),
              if (_unreadCount > 0)
                Positioned(
                  right: -3, top: -3,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Center(child: Text('$_unreadCount', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  ACTIVE STATE
  // ══════════════════════════════════════════════════
  Widget _buildActiveState(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color bgColor, Color borderColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveHeader(isDark, textColor, bgColor, subtitleColor),
          const SizedBox(height: 16),
          _buildExpiringSection(isDark, textColor, subtitleColor, cardColor),
          const SizedBox(height: 24),
          _buildQuickEasySection(isDark, textColor, subtitleColor, cardColor),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActiveHeader(bool isDark, Color textColor, Color bgColor, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
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
              Text(
                'SabiTrak',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Icon(Icons.tune, color: textColor, size: 22),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _openNotifications,
                child: Stack(clipBehavior: Clip.none, children: [
                  Icon(Icons.notifications_outlined, color: textColor, size: 24),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -3, top: -3,
                      child: Container(
                        width: 14, height: 14,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Center(child: Text('$_unreadCount', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                      ),
                    ),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Search recipes or ingredients...',
                hintStyle: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: subtitleColor,
                ),
                prefixIcon: Icon(Icons.search,
                    color: subtitleColor, size: 20),
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

  Widget _buildSearchBar(bool isDark, Color subtitleColor, Color bgColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(
            color: isDark ? AppTheme.darkText : AppTheme.primaryGreen,
          ),
          decoration: InputDecoration(
            hintText: 'Search recipes...',
            hintStyle: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: subtitleColor,
            ),
            prefixIcon:
                Icon(Icons.search, color: subtitleColor, size: 20),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'EXPLORE BY CATEGORY',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: subtitleColor,
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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringSection(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 6),
              Text(
                'Use It Before You Lose It',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
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
              isDark: isDark,
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickEasySection(bool isDark, Color textColor,
      Color subtitleColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.bolt, color: textColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Quick & Easy',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'View all',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
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
              isDark: isDark,
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
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
  final bool isDark;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;

  const _ExpiringRecipeCard({
    required this.recipe,
    required this.isDark,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 200,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3D3020)
                        : const Color(0xFFE8D5B7),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (recipe.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.eco,
                            size: 12, color: AppTheme.primaryGreen),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            recipe.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 14, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        recipe.time,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                      if (recipe.rating != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.star,
                            size: 14, color: Color(0xFFFFC107)),
                        const SizedBox(width: 2),
                        Text(
                          recipe.rating!,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            color: subtitleColor,
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
  final bool isDark;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;

  const _QuickRecipeCard({
    required this.recipe,
    required this.isDark,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE0E0E0),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(
                    recipe.imageIcon,
                    size: 40,
                    color: subtitleColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 13, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        recipe.time,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: subtitleColor,
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
