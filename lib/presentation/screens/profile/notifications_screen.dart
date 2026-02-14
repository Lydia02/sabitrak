import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushEnabled = true;
  bool _expiryReminders = true;
  bool _householdUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('notif_push') ?? true;
      _expiryReminders = prefs.getBool('notif_expiry') ?? true;
      _householdUpdates = prefs.getBool('notif_household') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
          'Notifications',
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
            _buildToggle(
              icon: Icons.notifications_active_outlined,
              title: 'Push Notifications',
              subtitle: 'Receive alerts on your device',
              value: _pushEnabled,
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
              onChanged: (v) {
                setState(() => _pushEnabled = v);
                _savePref('notif_push', v);
              },
            ),
            const SizedBox(height: 12),
            _buildToggle(
              icon: Icons.timer_outlined,
              title: 'Expiry Reminders',
              subtitle: 'Get notified before items expire',
              value: _expiryReminders,
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
              onChanged: (v) {
                setState(() => _expiryReminders = v);
                _savePref('notif_expiry', v);
              },
            ),
            const SizedBox(height: 12),
            _buildToggle(
              icon: Icons.group_outlined,
              title: 'Household Updates',
              subtitle: 'When members add or remove items',
              value: _householdUpdates,
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              isDark: isDark,
              onChanged: (v) {
                setState(() => _householdUpdates = v);
                _savePref('notif_household', v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color textColor,
    required Color subtitleColor,
    required Color cardColor,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }
}
