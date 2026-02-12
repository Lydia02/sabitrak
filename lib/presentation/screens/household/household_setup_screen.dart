import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import 'create_household_screen.dart';
import 'join_household_screen.dart';
import 'solo_setup_screen.dart';

class HouseholdSetupScreen extends StatelessWidget {
  const HouseholdSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Set up your household',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share inventory and reduce waste together',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: AppTheme.subtitleGrey,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CreateHouseholdScreen()),
                ),
                child: const Text('Create Household'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const JoinHouseholdScreen()),
                ),
                child: const Text('Join Household'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SoloSetupScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.backButtonColor,
                ),
                child: const Text('Skip'),
              ),
              const SizedBox(height: 16),
              const Text(
                'You can always set up a household later in Profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: AppTheme.subtitleGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
