import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _householdName;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadHouseholdName();
  }

  Future<void> _loadHouseholdName() async {
    final name = await FirebaseService().getHouseholdName();
    if (mounted) {
      setState(() {
        _householdName = name;
        _loaded = true;
      });
    }
  }

  String get _greeting {
    if (!_loaded) return '';
    if (_householdName != null && _householdName!.isNotEmpty) {
      return 'Welcome, $_householdName!';
    }
    final user = FirebaseService().currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'there';
    final firstName = displayName.contains(' ')
        ? displayName.split(' ').first
        : displayName.split('@').first;
    return 'Welcome, $firstName!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 20),
            color: AppTheme.primaryGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _loaded
                          ? Text(
                              _greeting,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.white,
                              ),
                            )
                          : const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.white,
                              ),
                            ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: AppTheme.white),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined,
                              color: AppTheme.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Track your food and reduce waste.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sync: Online',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.white,
                  ),
                ),
              ],
            ),
          ),

          // ── Body — fills remaining space ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                // Proportional vertical spacing based on available height
                final sectionGap = h * 0.04; // ~4% of body height
                final cardPadding = h * 0.02;

                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: sectionGap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Insights
                      const Text(
                        'Insights',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      SizedBox(height: cardPadding),
                      Row(
                        children: [
                          Expanded(
                            child: _InsightCard(
                              number: '10',
                              label: 'items',
                              subtitle: 'Use within 7 days',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InsightCard(
                              number: '5',
                              label: 'items saved',
                              subtitle: 'This month',
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Smart Suggestions
                      const Text(
                        'Smart Suggestions',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      SizedBox(height: cardPadding),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: const [
                                  Icon(Icons.lightbulb_outline,
                                      color: AppTheme.white, size: 20),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '2 items expire',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        color: AppTheme.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                'View Recipes',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Quick Actions
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      SizedBox(height: cardPadding),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: const [
                          _QuickAction(
                              icon: Icons.qr_code_scanner, label: 'Scan'),
                          _QuickAction(
                              icon: Icons.inventory_2_outlined,
                              label: 'Update\nPantry'),
                          _QuickAction(
                              icon: Icons.restaurant_menu, label: 'Recipes'),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String number;
  final String label;
  final String subtitle;

  const _InsightCard({
    required this.number,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              color: AppTheme.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
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
            fontSize: 12,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }
}
