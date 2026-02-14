import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';
import '../inventory/add_item_options_screen.dart';

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

  final InventoryRepository _inventoryRepo = InventoryRepository();
  StreamSubscription<List<FoodItem>>? _inventorySub;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
      // Listen to inventory changes in real-time
      if (householdId != null) {
        _inventorySub = _inventoryRepo.getFoodItems(householdId).listen((items) {
          if (mounted) {
            setState(() {
              _totalItems = items.length;
              _expiringItems = items.where((item) => item.isExpiringSoon || item.isExpired).length;
            });
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _loaded
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    _buildHeader(),
                    const SizedBox(height: 20),

                    // ── Stat Cards ──
                    _buildStatCards(),
                    const SizedBox(height: 20),

                    // ── Analytical Overview ──
                    _buildAnalyticalOverview(),
                    const SizedBox(height: 24),

                    // ── Quick Actions ──
                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    // ── Recommended / Empty State ──
                    if (_isEmpty)
                      _buildEmptyState()
                    else
                      _buildRecommended(),
                    const SizedBox(height: 24),
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

  // ── Header: Avatar + Greeting + Notification bell ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.fieldBorderColor.withValues(alpha: 0.3),
            ),
            child: const Icon(
              Icons.person,
              color: AppTheme.subtitleGrey,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_timeGreeting, $_greetingName!',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                Text(
                  _isEmpty
                      ? 'Start tracking your food today.'
                      : 'You saved 0kg of food this month',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: AppTheme.subtitleGrey,
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.primaryGreen,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3 Stat Cards: Expiring, Total Items, Members ──
  Widget _buildStatCards() {
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
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.shopping_bag_outlined,
              iconColor: AppTheme.primaryGreen,
              value: '$_totalItems',
              label: 'TOTAL ITEMS',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF1565C0),
              value: '$_memberCount',
              label: 'MEMBERS',
            ),
          ),
        ],
      ),
    );
  }

  // ── Analytical Overview: Waste Reduction Goal ──
  Widget _buildAnalyticalOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
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
                const Text(
                  'ANALYTICAL OVERVIEW',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.subtitleGrey,
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
                // Circular progress
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _isEmpty ? 0.0 : 0.85,
                        strokeWidth: 5,
                        backgroundColor: AppTheme.fieldBorderColor.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryGreen,
                        ),
                      ),
                      Text(
                        _isEmpty ? '0%' : '85%',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
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
                      const Text(
                        'Waste Reduction Goal',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isEmpty
                            ? 'Start tracking your food to see your reduction progress.'
                            : 'You\'re doing great! Only 15% away from your monthly target.',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: AppTheme.subtitleGrey,
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
    );
  }

  // ── Quick Actions: Scan, Add Item, Update Pantry ──
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionButton(
            icon: Icons.qr_code_scanner,
            label: 'Scan',
            filled: true,
            onTap: () {},
          ),
          _QuickActionButton(
            icon: Icons.add_circle_outline,
            label: 'Add Item',
            filled: true,
            onTap: _navigateToAddItem,
          ),
          _QuickActionButton(
            icon: Icons.sync,
            label: 'Update\nPantry',
            filled: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ── Empty State: Your inventory is empty ──
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Dashed circle with bag icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.fieldBorderColor.withValues(alpha: 0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 44,
              color: AppTheme.subtitleGrey.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your inventory is empty',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add food items to see personalized recipe\nrecommendations and track expiry dates.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: AppTheme.subtitleGrey,
            ),
          ),
          const SizedBox(height: 24),
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

  // ── Recommended for You (when user has items) ──
  Widget _buildRecommended() {
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
                const Text(
                  'Recommended for You',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'SEE ALL',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.subtitleGrey,
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
              children: const [
                _RecipeCard(
                  title: 'Rich Beef Stew',
                  subtitle: 'Uses your Tomato Paste (Exp. today)',
                  time: '45 min',
                  difficulty: 'Medium',
                  tag: 'EXPIRING INGREDIENT',
                ),
                SizedBox(width: 12),
                _RecipeCard(
                  title: 'Zesty Fruit Salad',
                  subtitle: 'Uses 3 Bananas',
                  time: '10 min',
                  difficulty: 'Easy',
                  tag: 'EXPIRING INGREDIENT',
                ),
                SizedBox(width: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Reusable Widgets
// ═══════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.subtitleGrey,
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
  final bool filled;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.filled,
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
              color: filled
                  ? AppTheme.white
                  : AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGreen,
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

  const _RecipeCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.difficulty,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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
          // Image placeholder with tag
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
                // Placeholder food icon
                Center(
                  child: Icon(
                    Icons.restaurant,
                    size: 40,
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                // Expiring tag
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
          // Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: AppTheme.subtitleGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppTheme.subtitleGrey),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: AppTheme.subtitleGrey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.signal_cellular_alt, size: 14, color: AppTheme.subtitleGrey),
                    const SizedBox(width: 4),
                    Text(
                      difficulty,
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
    );
  }
}
