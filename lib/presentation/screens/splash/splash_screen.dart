import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/theme/app_theme.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/local_cache_service.dart';
import '../main/main_shell.dart';
import '../onboarding/onboarding_screen.dart';
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

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOnline = await ConnectivityService().isConnected();

    // If a Google signup was started but never completed verification,
    // delete that Firebase account so it doesn't linger
    final pendingGoogleUid = prefs.getString('pending_google_uid');
    if (pendingGoogleUid != null && currentUser != null &&
        currentUser.uid == pendingGoogleUid) {
      if (isOnline) {
        try {
          await currentUser.delete();
        } catch (_) {
          await FirebaseAuth.instance.signOut();
        }
      } else {
        await FirebaseAuth.instance.signOut();
      }
      await prefs.remove('pending_google_uid');
    } else if (currentUser != null) {
      if (isOnline) {
        // Check if user was active within the last 10 minutes
        final lastActiveMs = prefs.getInt('last_active_ms');
        final withinGrace = lastActiveMs != null &&
            DateTime.now().millisecondsSinceEpoch - lastActiveMs <
                const Duration(minutes: 10).inMilliseconds;

        final householdDone = prefs.getBool('household_setup_done') ?? false;
        if (withinGrace && onboardingComplete && householdDone) {
          // Within grace period — go straight to app without signing out
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => MainShell(key: MainShell.shellKey),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
          return;
        }
        // Grace period expired — sign out and require fresh login
        await FirebaseAuth.instance.signOut();
      } else {
        // Offline: restore session if we have a cached profile + completed setup
        final householdDone = prefs.getBool('household_setup_done') ?? false;
        final cached = LocalCacheService().getCachedUserProfile();
        if (onboardingComplete && householdDone && cached != null) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  MainShell(key: MainShell.shellKey),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
          return;
        }
        // No cached session — still sign out so they hit the welcome screen
        await FirebaseAuth.instance.signOut();
      }
    }

    if (!mounted) return;

    // Route based on whether they've completed onboarding before
    final Widget destination;
    if (onboardingComplete) {
      destination = const WelcomeScreen();
    } else {
      destination = const OnboardingScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;

    return Scaffold(
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
                    Text(
                      'SabiTrak',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: textColor,
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
                child: Text(
                  'Smart tracking. Less waste.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
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
