import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_theme.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contact Us',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.support_agent,
                size: 64, color: AppTheme.primaryGreen.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'We\'d love to hear from you!',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reach out for support, feedback, or partnerships.',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 32),
            _ContactTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: 'support@sabitrak.com',
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
              onTap: () => _launch('mailto:support@sabitrak.com'),
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.language,
              title: 'Website',
              subtitle: 'www.sabitrak.com',
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
              onTap: () => _launch('https://www.sabitrak.com'),
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.chat_bubble_outline,
              title: 'Twitter / X',
              subtitle: '@sabitrak',
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
              onTap: () => _launch('https://twitter.com/sabitrak'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
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
        child: Row(
          children: [
            Icon(icon, size: 24, color: textColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: subtitleColor),
          ],
        ),
      ),
    );
  }
}
