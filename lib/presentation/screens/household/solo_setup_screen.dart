import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../services/firebase_service.dart';
import '../../widgets/error_modal.dart';
import '../main/main_shell.dart';

class SoloSetupScreen extends StatefulWidget {
  const SoloSetupScreen({super.key});

  @override
  State<SoloSetupScreen> createState() => _SoloSetupScreenState();
}

class _SoloSetupScreenState extends State<SoloSetupScreen> {
  String _householdType = 'Solo';
  String? _expiryAlert;
  bool _isLoading = false;

  static const List<String> _householdTypes = ['Solo', 'Share', 'Couple'];
  static const List<String> _expiryOptions = [
    '1 day before',
    '2 days before',
    '3 days before',
    '1 week before',
  ];

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(9, (i) => chars[(rand + i * 7) % chars.length])
        .join();
  }

  Future<void> _onSavePreferences() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseService().currentUser;
      final code = _generateInviteCode();
      final name = user?.displayName?.split(' ').first ?? 'My Household';

      await FirebaseService().households.add({
        'name': '$name\'s Household',
        'type': _householdType,
        'expiryAlert': _expiryAlert,
        'adminUid': user?.uid,
        'members': [user?.uid],
        'inviteCode': code,
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainShell(key: MainShell.shellKey)),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorModal(context,
            title: 'Error', message: 'Failed to save preferences: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.fieldBorderColor;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                'Set Your Preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Personalise how SabiTrak works for you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Apartment / Living Type:',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              ..._householdTypes.map((type) => RadioListTile<String>(
                    title: Text(type,
                        style: TextStyle(
                            fontFamily: 'Roboto',
                            color: textColor)),
                    value: type,
                    groupValue: _householdType,
                    activeColor: AppTheme.primaryGreen,
                    onChanged: (v) => setState(() => _householdType = v!),
                    contentPadding: EdgeInsets.zero,
                  )),
              const SizedBox(height: 24),
              Text(
                'Default Expiry Alert:',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _expiryAlert,
                dropdownColor: cardColor,
                hint: const Text('Select when to alert you'),
                items: _expiryOptions
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _expiryAlert = v),
                style: TextStyle(fontFamily: 'Roboto', fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryGreen, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can change these settings anytime in Profile.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _onSavePreferences,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.white))
                    : const Text('Save & Continue'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.backButtonColor),
                child: const Text('Back'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
