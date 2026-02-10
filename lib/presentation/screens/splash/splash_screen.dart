import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../welcome/welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    // Logo fade + scale in
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Tagline slide up + fade in
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _taglineFade = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // Brief blank screen
    await Future.delayed(const Duration(milliseconds: 500));

    // Fade in logo
    _fadeController.forward();

    // After logo appears, slide in tagline
    await Future.delayed(const Duration(milliseconds: 800));
    _slideController.forward();

    // Hold the splash, then navigate
    await Future.delayed(const Duration(milliseconds: 2000));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const WelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo + App Name
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _fadeAnimation,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/leaf_icon.png',
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'SabiTrak',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                        height: 40 / 36,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Tagline
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _taglineFade,
                child: const Text(
                  'Smart tracking. Less waste.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.subtitleGrey,
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
