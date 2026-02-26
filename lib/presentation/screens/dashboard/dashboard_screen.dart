import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/matched_recipe.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import '../../../services/recipe_service.dart';
import '../inventory/add_item_options_screen.dart';
import '../inventory/barcode_scanner_screen.dart';
import '../main/main_shell.dart';
import '../recipe/recipe_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _householdName;
  bool _loaded = false;
  int _totalItems = 0;
  int _expiringItems = 0;
  int _memberCount = 0;
  bool _popupShown = false;

  final InventoryRepository _inventoryRepo = InventoryRepository();
  final RecipeService _recipeService = RecipeService();
  StreamSubscription<List<FoodItem>>? _inventorySub;
  List<FoodItem> _inventoryItems = [];
  List<MatchedRecipe> _recommendedRecipes = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _showPantryCheckPopup() {
    if (_popupShown) return;
    _popupShown = true;
    // Delay slightly so the dashboard renders first
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (ctx) => const _PantryCheckDialog(),
      );
    });
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final firebaseService = FirebaseService();
    final name = await firebaseService.getHouseholdName();
    final uid = firebaseService.currentUser?.uid;
    int members = 1;
    String? householdId;
    if (uid != null) {
      final query = await firebaseService.households
          .where('members', arrayContains: uid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        householdId = query.docs.first.id;
        final data = query.docs.first.data() as Map<String, dynamic>;
        final memberList = data['members'] as List<dynamic>?;
        members = memberList?.length ?? 1;
      }
    }
    if (mounted) {
      setState(() {
        _householdName = name;
        _memberCount = members;
        _loaded = true;
      });
      if (householdId != null) {
        _inventorySub = _inventoryRepo.getFoodItems(householdId).listen((items) {
          if (mounted) {
            final changed = items.length != _inventoryItems.length;
            setState(() {
              _inventoryItems = items;
              _totalItems = items.length;
              _expiringItems = items.where((item) => item.isExpiringSoon || item.isExpired).length;
            });
            if (items.isNotEmpty) _showPantryCheckPopup();
            if (changed || _recommendedRecipes.isEmpty) _fetchDashboardRecipes(items);
          }
        });
      }
    }
  }

  Future<void> _fetchDashboardRecipes(List<FoodItem> items) async {
    if (items.isEmpty) return;
    final result = await _recipeService.getRecommendations(items);
    if (!mounted) return;
    // Show expiring-first, fallback to quickMatch
    final recipes = result.expiring.isNotEmpty ? result.expiring : result.quickMatch;
    setState(() => _recommendedRecipes = recipes.take(6).toList());
  }

  void _navigateToAddItem() {
    AddItemOptionsScreen.show(context);
  }

  String get _greetingName {
    if (!_loaded) return '';
    if (_householdName != null && _householdName!.isNotEmpty) {
      return _householdName!;
    }
    final user = FirebaseService().currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'there';
    return displayName.contains(' ')
        ? displayName.split(' ').first
        : displayName.split('@').first;
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool get _isEmpty => _totalItems == 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    return Scaffold(
      body: SafeArea(
        child: _loaded
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(textColor, subtitleColor, cardColor, isDark),
                    const SizedBox(height: 16),
                    _buildStatCards(textColor, subtitleColor, cardColor, isDark),
                    const SizedBox(height: 16),
                    _buildAnalyticalOverview(textColor, subtitleColor, cardColor, isDark),
                    const SizedBox(height: 16),
                    _buildQuickActions(textColor, cardColor, isDark),
                    const SizedBox(height: 16),
                    if (_isEmpty)
                      _buildEmptyState(textColor, subtitleColor)
                    else
                      _buildRecommended(textColor, subtitleColor, cardColor, isDark),
                    const SizedBox(height: 16),
                  ],
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subtitleColor, Color cardColor, bool isDark) {
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
                  ? AppTheme.darkSurface
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
                  '$_timeGreeting, $_greetingName!',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  _isEmpty
                      ? 'Start tracking your food today.'
                      : 'You saved 0kg of food this month',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(Color textColor, Color subtitleColor, Color cardColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFE65100),
              value: '$_expiringItems',
              label: 'EXPIRING',
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.shopping_bag_outlined,
              iconColor: AppTheme.primaryGreen,
              value: '$_totalItems',
              label: 'TOTAL ITEMS',
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF1565C0),
              value: '$_memberCount',
              label: 'MEMBERS',
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticalOverview(Color textColor, Color subtitleColor, Color cardColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => MainShell.switchTab(3),
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
                Expanded(
                  child: Text(
                    'ANALYTICAL OVERVIEW',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.bar_chart,
                  size: 20,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(
                    painter: _DashRingPainter(
                      value: _isEmpty ? 0.0 : 0.85,
                      trackColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppTheme.fieldBorderColor.withValues(alpha: 0.3),
                      fillColor: AppTheme.primaryGreen,
                      textColor: textColor,
                      label: _isEmpty ? '0%' : '85%',
                      strokeWidth: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waste Reduction Goal',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isEmpty
                            ? 'Start tracking your food to see your reduction progress.'
                            : 'You\'re doing great! Only 15% away from your monthly target.',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildQuickActions(Color textColor, Color cardColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionButton(
            icon: Icons.qr_code_scanner,
            label: 'Scan',
            textColor: textColor,
            cardColor: cardColor,
            isDark: isDark,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
            ),
          ),
          _QuickActionButton(
            icon: Icons.add_circle_outline,
            label: 'Add Item',
            textColor: textColor,
            cardColor: cardColor,
            isDark: isDark,
            onTap: _navigateToAddItem,
          ),
          _QuickActionButton(
            icon: Icons.sync,
            label: 'Update\nPantry',
            textColor: textColor,
            cardColor: cardColor,
            isDark: isDark,
            onTap: () => MainShell.switchTab(1),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subtitleColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppTheme.fieldBorderColor.withValues(alpha: 0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 36,
              color: subtitleColor.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your inventory is empty',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add food items to see personalized recipe\nrecommendations and track expiry dates.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToAddItem,
              child: const Text('Add Your First Item'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommended(Color textColor, Color subtitleColor, Color cardColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recommended for You',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                GestureDetector(
                  onTap: () => MainShell.switchTab(2),
                  child: Text(
                    'SEE ALL',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _recommendedRecipes.isEmpty
              ? SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      'Finding recipes from your pantry…',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 20),
                    itemCount: _recommendedRecipes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final recipe = _recommendedRecipes[i];
                      return _DashRecipeCard(
                        recipe: recipe,
                        isDark: isDark,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        cardColor: cardColor,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(recipe: recipe),
                        )),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color cardColor;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.cardColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
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
            child: Icon(icon, color: textColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashRecipeCard extends StatelessWidget {
  final MatchedRecipe recipe;
  final bool isDark;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final VoidCallback onTap;

  const _DashRecipeCard({
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
        width: 200,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Recipe image ─────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: recipe.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: recipe.thumbnailUrl,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 110,
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
                            height: 110,
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFE8D5B7),
                            child: Icon(Icons.restaurant,
                                size: 36,
                                color: AppTheme.primaryGreen
                                    .withValues(alpha: 0.4)),
                          ),
                        )
                      : Container(
                          height: 110,
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE8D5B7),
                          child: Icon(Icons.restaurant,
                              size: 36,
                              color:
                                  AppTheme.primaryGreen.withValues(alpha: 0.4)),
                        ),
                ),
                // Badge: expiring or match %
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: recipe.usesExpiringItem
                          ? const Color(0xFFE65100)
                          : AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      recipe.usesExpiringItem
                          ? 'EXPIRING INGREDIENT'
                          : '${recipe.matchPercent} MATCH',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Info ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recipe.usesExpiringItem
                        ? 'Uses: ${recipe.expiringMatchedItems.take(2).join(', ')}'
                        : '${recipe.matchedCount}/${recipe.ingredients.length} ingredients in pantry',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: recipe.usesExpiringItem
                          ? const Color(0xFFE65100)
                          : subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 13, color: subtitleColor),
                      const SizedBox(width: 3),
                      Text(
                        recipe.estimatedPrepTime,
                        style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
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

class _DashRingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color fillColor;
  final Color textColor;
  final String label;
  final double strokeWidth;

  const _DashRingPainter({
    required this.value,
    required this.trackColor,
    required this.fillColor,
    required this.textColor,
    required this.label,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    paint.color = trackColor;
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    if (value > 0) {
      paint.color = fillColor;
      canvas.drawArc(rect, -3.14159 / 2, 2 * 3.14159 * value.clamp(0.0, 1.0), false, paint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_DashRingPainter old) =>
      old.value != value || old.fillColor != fillColor ||
      old.trackColor != trackColor || old.textColor != textColor;
}

// ── Pantry Check Popup ───────────────────────────────────────────────────────
class _PantryCheckDialog extends StatelessWidget {
  const _PantryCheckDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.checklist_rounded,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pantry Check?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Did you use something without logging it? Keep your inventory accurate for better recipe matches.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: subtitleColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  MainShell.switchTab(1);
                },
                child: const Text('Update Now'),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'MAYBE LATER',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: subtitleColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
