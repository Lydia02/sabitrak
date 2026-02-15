import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import '../inventory/add_item_options_screen.dart';
import '../main/main_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _householdName;
  String? _householdId;
  bool _loaded = false;
  int _totalItems = 0;
  int _expiringItems = 0;
  int _memberCount = 0;
  bool _popupShown = false;

  final InventoryRepository _inventoryRepo = InventoryRepository();
  StreamSubscription<List<FoodItem>>? _inventorySub;

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
        _householdId = householdId;
        _memberCount = members;
        _loaded = true;
      });
      if (householdId != null) {
        _inventorySub = _inventoryRepo.getFoodItems(householdId).listen((items) {
          if (mounted) {
            setState(() {
              _totalItems = items.length;
              _expiringItems = items.where((item) => item.isExpiringSoon || item.isExpired).length;
            });
            if (items.isNotEmpty) _showPantryCheckPopup();
          }
        });
      }
    }
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
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: textColor,
                size: 22,
              ),
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
                Text(
                  'ANALYTICAL OVERVIEW',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                    letterSpacing: 1.2,
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
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _isEmpty ? 0.0 : 0.85,
                        strokeWidth: 5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppTheme.fieldBorderColor.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryGreen,
                        ),
                      ),
                      Text(
                        _isEmpty ? '0%' : '85%',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
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
            onTap: () {},
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
                  onTap: () {},
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
          SizedBox(
            height: 220,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RecipeCard(
                  title: 'Rich Beef Stew',
                  subtitle: 'Uses your Tomato Paste (Exp. today)',
                  time: '45 min',
                  difficulty: 'Medium',
                  tag: 'EXPIRING INGREDIENT',
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  cardColor: cardColor,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _RecipeCard(
                  title: 'Zesty Fruit Salad',
                  subtitle: 'Uses 3 Bananas',
                  time: '10 min',
                  difficulty: 'Easy',
                  tag: 'EXPIRING INGREDIENT',
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  cardColor: cardColor,
                  isDark: isDark,
                ),
                const SizedBox(width: 20),
              ],
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

class _RecipeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final String difficulty;
  final String tag;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool isDark;

  const _RecipeCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.difficulty,
    required this.tag,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.isDark,
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
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.restaurant,
                    size: 40,
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: subtitleColor),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.signal_cellular_alt, size: 14, color: subtitleColor),
                    const SizedBox(width: 4),
                    Text(
                      difficulty,
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
    );
  }
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
