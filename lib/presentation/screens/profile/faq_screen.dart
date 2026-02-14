import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'What is SabiTrak?',
      'a':
          'SabiTrak is a pantry management app that helps you track food items, reduce waste, and manage your household inventory efficiently.',
    },
    {
      'q': 'How do I add food items?',
      'a':
          'Go to the Inventory tab and tap the + button. You can add items manually or scan a barcode.',
    },
    {
      'q': 'How do I invite someone to my household?',
      'a':
          'Go to Profile > Share Invite Code. Share the code with the person you want to invite. They can use it when joining a household.',
    },
    {
      'q': 'What do the expiry alerts mean?',
      'a':
          'Items expiring within 3 days are marked as "Expiring Soon" in orange. Expired items are shown in red. Fresh items are green.',
    },
    {
      'q': 'Can I use SabiTrak without a household?',
      'a':
          'Yes! You can set up a Solo household to track your personal pantry items.',
    },
    {
      'q': 'How do I change my household type?',
      'a':
          'Currently, household type is set during creation. Contact support if you need to change it.',
    },
    {
      'q': 'Is my data secure?',
      'a':
          'Yes. SabiTrak uses Firebase for authentication and data storage with industry-standard security practices.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'FAQ',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? AppTheme.darkCard : AppTheme.white,
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                faq['q']!,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              iconColor: textColor,
              collapsedIconColor: textColor,
              children: [
                Text(
                  faq['a']!,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkSubtitle
                        : AppTheme.subtitleGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
