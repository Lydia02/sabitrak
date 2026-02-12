import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const _PlaceholderScreen(label: 'Households'),
    const _PlaceholderScreen(label: 'Add Item'),
    const _PlaceholderScreen(label: 'Recipes'),
    const _PlaceholderScreen(label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.white,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Households',
                  index: 1,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
              ),
              // Center FAB placeholder
              const SizedBox(width: 56),
              Expanded(
                child: _NavItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book,
                  label: 'Recipes',
                  index: 3,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  index: 4,
                  currentIndex: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _currentIndex = 2),
        backgroundColor: AppTheme.primaryGreen,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppTheme.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? AppTheme.primaryGreen : AppTheme.subtitleGrey,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 10,
              color: isActive ? AppTheme.primaryGreen : AppTheme.subtitleGrey,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 20,
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
