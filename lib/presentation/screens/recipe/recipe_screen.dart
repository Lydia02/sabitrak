import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/matched_recipe.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/recipe_service.dart';
import '../../../services/snack_service.dart';
import '../inventory/add_item_options_screen.dart';
import '../profile/notification_inbox_screen.dart';
import 'recipe_detail_screen.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  // ── Data ─────────────────────────────────────────────────────────────────
  final InventoryRepository _inventoryRepo = InventoryRepository();
  final RecipeService _recipeService = RecipeService();
  final SnackService _snackService = SnackService();

  StreamSubscription<List<FoodItem>>? _inventorySub;
  List<FoodItem> _inventoryItems = [];

  RecipeRecommendationResult _recommendations =
      const RecipeRecommendationResult(expiring: [], quickMatch: []);
  List<MatchedRecipe> _searchResults = [];
  List<SnackSuggestion> _snackSuggestions = [];

  // ── State flags ───────────────────────────────────────────────────────────
  bool _inventoryLoaded = false;
  bool _recipesLoading = false;
  bool _searching = false;
  String _searchQuery = '';
  int _unreadCount = 0;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Notification badge ────────────────────────────────────────────────────
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
        .push(MaterialPageRoute(
            builder: (_) => const NotificationInboxScreen()))
        .then((_) => _loadUnreadCount());
  }

  // ── Inventory loading ─────────────────────────────────────────────────────
  Future<void> _loadInventory() async {
    final firebaseService = FirebaseService();
    final uid = firebaseService.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _inventoryLoaded = true);
      return;
    }

    final query = await firebaseService.households
        .where('members', arrayContains: uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      if (mounted) setState(() => _inventoryLoaded = true);
      return;
    }

    final householdId = query.docs.first.id;
    _inventorySub = _inventoryRepo.getFoodItems(householdId).listen((items) {
      if (!mounted) return;
      // Detect any change — length OR item names changed
      final oldNames = _inventoryItems.map((i) => i.name).toSet();
      final newNames = items.map((i) => i.name).toSet();
      final changed = items.length != _inventoryItems.length ||
          !oldNames.containsAll(newNames) ||
          !newNames.containsAll(oldNames);
      _inventoryItems = items;
      _inventoryLoaded = true;
      if (mounted) setState(() {});
      if (changed || _recommendations.isEmpty) {
        _fetchRecommendations();
      }
    });
  }

  // ── Recipe fetching ───────────────────────────────────────────────────────
  Future<void> _fetchRecommendations() async {
    if (_inventoryItems.isEmpty) return;
    if (mounted) setState(() => _recipesLoading = true);

    try {
      final results = await Future.wait([
        _recipeService.getRecommendations(_inventoryItems),
        _snackService.getSuggestions(_inventoryItems),
      ]);
      if (mounted) {
        setState(() {
          _recommendations = results[0] as RecipeRecommendationResult;
          _snackSuggestions = results[1] as List<SnackSuggestion>;
          _recipesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _recipesLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    setState(() => _searchQuery = query);

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final results =
          await _recipeService.searchRecipes(query, _inventoryItems);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    });
  }

  void _openDetail(MatchedRecipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecipeDetailScreen(
        recipe: recipe,
        pantryItems: _inventoryItems,
      ),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor =
        isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: !_inventoryLoaded
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryGreen, strokeWidth: 2))
            : _inventoryItems.isEmpty
                ? _buildEmptyState(
                    isDark, textColor, subtitleColor, cardColor, bgColor)
                : _buildActiveState(
                    isDark, textColor, subtitleColor, cardColor, bgColor),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color bgColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(textColor, subtitleColor, bgColor),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.restaurant,
                            color: AppTheme.primaryGreen.withValues(alpha: 0.6),
                            size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pantry items yet',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add food items to your pantry\nand we\'ll recommend recipes\nbased on what you have.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          color: subtitleColor,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          onPressed: () => AddItemOptionsScreen.show(context),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Add First Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ACTIVE STATE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveState(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color bgColor) {
    // If user is searching, show search results
    final showSearch = _searchQuery.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: _fetchRecommendations,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(textColor, subtitleColor, bgColor),
            const SizedBox(height: 16),

            if (showSearch)
              _buildSearchResults(
                  isDark, textColor, subtitleColor, cardColor, bgColor)
            else ...[
              // Loading indicator while fetching recipes
              if (_recipesLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                            color: AppTheme.primaryGreen, strokeWidth: 2),
                        const SizedBox(height: 12),
                        Text(
                          'Finding recipes from your pantry…',
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_recommendations.isEmpty)
                _buildNoMatchState(subtitleColor, bgColor)
              else ...[
                // ── Use It Before You Lose It ──────────────────────────────
                if (_recommendations.expiring.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFE65100),
                    title: 'Use It Before You Lose It',
                    subtitle:
                        '${_recommendations.expiring.length} recipes use expiring items',
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 248,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _recommendations.expiring.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                      itemBuilder: (_, i) => _RecipeCard(
                        recipe: _recommendations.expiring[i],
                        isDark: isDark,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        cardColor: cardColor,
                        showExpiryBadge: true,
                        onTap: () =>
                            _openDetail(_recommendations.expiring[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Quick & Easy (recipes + snacks merged) ─────────────────
                if (_recommendations.quickEasy.isNotEmpty ||
                    _snackSuggestions.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.bolt,
                    iconColor: const Color(0xFFF9A825),
                    title: 'Quick & Easy',
                    subtitle:
                        '${_recommendations.quickEasy.length + _snackSuggestions.length} quick bites & fast recipes',
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 248,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      // snack cards first, then quick recipes
                      itemCount: _snackSuggestions.length +
                          _recommendations.quickEasy.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        if (i < _snackSuggestions.length) {
                          return _SnackCard(
                            suggestion: _snackSuggestions[i],
                            isDark: isDark,
                            cardColor: cardColor,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          );
                        }
                        final ri = i - _snackSuggestions.length;
                        return _RecipeCard(
                          recipe: _recommendations.quickEasy[ri],
                          isDark: isDark,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          cardColor: cardColor,
                          showExpiryBadge: false,
                          onTap: () =>
                              _openDetail(_recommendations.quickEasy[ri]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Best Matches ───────────────────────────────────────────
                _buildSectionHeader(
                  icon: Icons.eco,
                  iconColor: AppTheme.primaryGreen,
                  title: 'Best Matches From Your Pantry',
                  subtitle:
                      '${_recommendations.quickMatch.length} recipes you can make',
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _recommendations.quickMatch.length,
                    itemBuilder: (_, i) => _GridRecipeCard(
                      recipe: _recommendations.quickMatch[i],
                      isDark: isDark,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      cardColor: cardColor,
                      onTap: () =>
                          _openDetail(_recommendations.quickMatch[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── Search results ────────────────────────────────────────────────────────
  Widget _buildSearchResults(bool isDark, Color textColor, Color subtitleColor,
      Color cardColor, Color bgColor) {
    if (_searching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(
                  color: AppTheme.primaryGreen, strokeWidth: 2),
              const SizedBox(height: 12),
              Text('Searching recipes…',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: subtitleColor)),
            ],
          ),
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Center(
          child: Text(
            'No recipes found for "$_searchQuery"',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Roboto', fontSize: 14, color: subtitleColor),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_searchResults.length} results for "$_searchQuery"',
            style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: subtitleColor),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (_, i) => _GridRecipeCard(
              recipe: _searchResults[i],
              isDark: isDark,
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              onTap: () => _openDetail(_searchResults[i]),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildNoMatchState(Color subtitleColor, Color bgColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off,
                size: 40, color: subtitleColor.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No recipe matches found.\nTry adding more items to your pantry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Roboto', fontSize: 13, color: subtitleColor),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchRecommendations,
              child: const Text('Try Again',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────
  Widget _buildHeader(
      Color textColor, Color subtitleColor, Color bgColor) {
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
                child: const Icon(Icons.eco, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Recipes',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openNotifications,
                child: Stack(clipBehavior: Clip.none, children: [
                  Icon(Icons.notifications_outlined,
                      color: textColor, size: 24),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Center(
                          child: Text('$_unreadCount',
                              style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search any recipe (e.g. jollof, chicken…)',
                hintStyle: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    color: subtitleColor),
                prefixIcon:
                    Icon(Icons.search, color: subtitleColor, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: subtitleColor, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
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

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: subtitleColor)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Snack card (Quick & Easy section)
// ══════════════════════════════════════════════════════════════════════════════

class _SnackCard extends StatelessWidget {
  final SnackSuggestion suggestion;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;

  const _SnackCard({
    required this.suggestion,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: suggestion.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: suggestion.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        _EmojiPlaceholder(emoji: suggestion.emoji, isDark: isDark),
                    errorWidget: (_, __, ___) =>
                        _EmojiPlaceholder(emoji: suggestion.emoji, isDark: isDark),
                  )
                : _EmojiPlaceholder(emoji: suggestion.emoji, isDark: isDark),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.productName,
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
                    const Icon(Icons.bolt, size: 12, color: Color(0xFFF9A825)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        suggestion.servingSuggestion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          color: subtitleColor,
                          height: 1.3,
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
}

class _EmojiPlaceholder extends StatelessWidget {
  final String emoji;
  final bool isDark;

  const _EmojiPlaceholder({required this.emoji, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFF8E1),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 48)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Horizontal scroll recipe card (Use It Before You Lose It)
// ══════════════════════════════════════════════════════════════════════════════

class _RecipeCard extends StatelessWidget {
  final MatchedRecipe recipe;
  final bool isDark;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool showExpiryBadge;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.isDark,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.showExpiryBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            // ── Image ───────────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: recipe.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: recipe.thumbnailUrl,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 120,
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFE8D5B7),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: AppTheme.primaryGreen,
                                    strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 120,
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFE8D5B7),
                            child: Icon(Icons.restaurant,
                                size: 40,
                                color: AppTheme.primaryGreen
                                    .withValues(alpha: 0.4)),
                          ),
                        )
                      : Container(
                          height: 120,
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE8D5B7),
                          child: Icon(Icons.restaurant,
                              size: 40,
                              color:
                                  AppTheme.primaryGreen.withValues(alpha: 0.4)),
                        ),
                ),
                // Match % badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      recipe.matchPercent,
                      style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
                // Expiry badge
                if (showExpiryBadge && recipe.usesExpiringItem)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
            // ── Info ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (recipe.usesExpiringItem)
                    Row(
                      children: [
                        const Icon(Icons.eco,
                            size: 11, color: Color(0xFFE65100)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'Uses: ${recipe.expiringMatchedItems.take(2).join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 10,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: subtitleColor),
                      const SizedBox(width: 3),
                      Text(recipe.estimatedPrepTime,
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              color: subtitleColor)),
                      const SizedBox(width: 8),
                      Icon(Icons.kitchen_outlined,
                          size: 12, color: subtitleColor),
                      const SizedBox(width: 3),
                      Text(
                          '${recipe.matchedCount}/${recipe.ingredients.length}',
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              color: subtitleColor)),
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

// ══════════════════════════════════════════════════════════════════════════════
//  Grid recipe card (Best Matches)
// ══════════════════════════════════════════════════════════════════════════════

class _GridRecipeCard extends StatelessWidget {
  final MatchedRecipe recipe;
  final bool isDark;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final VoidCallback onTap;

  const _GridRecipeCard({
    required this.recipe,
    required this.isDark,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            // ── Image ───────────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: recipe.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: recipe.thumbnailUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFE8D5B7),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: AppTheme.primaryGreen,
                                      strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFE8D5B7),
                              child: Icon(Icons.restaurant,
                                  size: 32,
                                  color: AppTheme.primaryGreen
                                      .withValues(alpha: 0.4)),
                            ),
                          )
                        : Container(
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFE8D5B7),
                            child: Icon(Icons.restaurant,
                                size: 32,
                                color: AppTheme.primaryGreen
                                    .withValues(alpha: 0.4)),
                          ),
                  ),
                  // Match badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: recipe.usesExpiringItem
                            ? const Color(0xFFE65100)
                            : AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        recipe.matchPercent,
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Info ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.kitchen_outlined,
                          size: 11, color: subtitleColor),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${recipe.matchedCount}/${recipe.ingredients.length} have',
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 10,
                              color: subtitleColor),
                        ),
                      ),
                      Icon(Icons.schedule, size: 11, color: subtitleColor),
                      const SizedBox(width: 2),
                      Text(
                        recipe.estimatedPrepTime.split('–').first,
                        style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 10,
                            color: subtitleColor),
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
