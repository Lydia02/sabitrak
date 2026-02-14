import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final bodyColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: February 2026',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: bodyColor,
              ),
            ),
            const SizedBox(height: 20),
            _section(
              title: 'Information We Collect',
              body:
                  'We collect information you provide when creating an account, including your name, email address, and household details. We also collect data about the food items you add to your pantry.',
              textColor: textColor,
              bodyColor: bodyColor,
            ),
            _section(
              title: 'How We Use Your Information',
              body:
                  'Your information is used to provide and improve SabiTrak services, including pantry tracking, expiry notifications, and household management. We do not sell your personal data to third parties.',
              textColor: textColor,
              bodyColor: bodyColor,
            ),
            _section(
              title: 'Data Storage & Security',
              body:
                  'Your data is stored securely using Google Firebase infrastructure with encryption in transit and at rest. We implement industry-standard security measures to protect your information.',
              textColor: textColor,
              bodyColor: bodyColor,
            ),
            _section(
              title: 'Household Data Sharing',
              body:
                  'When you join a household, other members can view shared pantry items. Only household admins can manage membership. You can leave a household at any time.',
              textColor: textColor,
              bodyColor: bodyColor,
            ),
            _section(
              title: 'Push Notifications',
              body:
                  'If enabled, we send push notifications for expiry reminders and household updates. You can disable notifications at any time from the app settings.',
              textColor: textColor,
              bodyColor: bodyColor,
            ),
            _section(
              title: 'Your Rights',
              body:
                  'You have the right to access, update, or delete your personal data. To request data deletion, contact us at support@sabitrak.com.',
              textColor: textColor,
              bodyColor: bodyColor,
            ),
            _section(
              title: 'Contact',
              body:
                  'For privacy-related questions, contact us at support@sabitrak.com.',
              textColor: textColor,
              bodyColor: bodyColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String body,
    required Color textColor,
    required Color bodyColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: bodyColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
