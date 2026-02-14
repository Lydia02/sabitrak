import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../config/theme/theme_notifier.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../services/firebase_service.dart';
import '../welcome/welcome_screen.dart';
import 'change_password_screen.dart';
import 'members_screen.dart';
import 'notifications_screen.dart';
import 'faq_screen.dart';
import 'contact_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebase = FirebaseService();
  final AuthRepository _authRepo = AuthRepository();
  UserModel? _user;
  String? _householdId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firebase.users.doc(uid).get();
    if (doc.exists) {
      setState(() => _user = UserModel.fromFirestore(doc));
    }

    final hQuery = await _firebase.households
        .where('members', arrayContains: uid)
        .limit(1)
        .get();
    if (hQuery.docs.isNotEmpty) {
      final hDoc = hQuery.docs.first;
      setState(() {
        _householdId = hDoc.id;
        _isAdmin = (hDoc.data() as Map<String, dynamic>)['adminUid'] == uid;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out',
            style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(fontFamily: 'Roboto')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: 'Roboto', color: AppTheme.subtitleGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out',
                style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _authRepo.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _shareInviteCode() async {
    if (_householdId == null) return;
    final doc = await _firebase.households.doc(_householdId).get();
    final code =
        (doc.data() as Map<String, dynamic>)['inviteCode'] as String? ?? '';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Code',
            style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with others to join your household:',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(
                    fontFamily: 'Roboto', color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    backgroundImage: _user?.photoUrl != null
                        ? NetworkImage(_user!.photoUrl!)
                        : null,
                    child: _user?.photoUrl == null
                        ? Text(
                            _user != null
                                ? '${_user!.firstName[0]}${_user!.lastName[0]}'
                                : '',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user != null
                              ? '${_user!.firstName} ${_user!.lastName}'
                              : 'Loading...',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _user?.email ?? '',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Menu items
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.lock_outline,
                        label: 'Change Password',
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onTap: () => _push(const ChangePasswordScreen()),
                      ),
                      _Divider(color: dividerColor),
                      _MenuItem(
                        icon: Icons.people_outline,
                        label: 'Household Members',
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onTap: () => _push(MembersScreen(
                          householdId: _householdId ?? '',
                          isAdmin: _isAdmin,
                        )),
                      ),
                      _Divider(color: dividerColor),
                      _MenuItem(
                        icon: Icons.share_outlined,
                        label: 'Share Invite Code',
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onTap: _shareInviteCode,
                      ),
                      _Divider(color: dividerColor),
                      _ThemeMenuItem(
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                      ),
                      _Divider(color: dividerColor),
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onTap: () => _push(const NotificationsScreen()),
                      ),
                      _Divider(color: dividerColor),
                      _MenuItem(
                        icon: Icons.help_outline,
                        label: 'FAQ',
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onTap: () => _push(const FaqScreen()),
                      ),
                      _Divider(color: dividerColor),
                      _MenuItem(
                        icon: Icons.mail_outline,
                        label: 'Contact Us',
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onTap: () => _push(const ContactScreen()),
                      ),
                      _Divider(color: dividerColor),
                      _MenuItem(
                        icon: Icons.shield_outlined,
                        label: 'Privacy Policy',
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onTap: () => _push(const PrivacyPolicyScreen()),
                      ),
                      const Spacer(),
                      _Divider(color: dividerColor),
                      _MenuItem(
                        icon: Icons.logout,
                        label: 'Log Out',
                        textColor: Colors.red,
                        subtitleColor: Colors.red,
                        isLogout: true,
                        onTap: _handleLogout,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final Color subtitleColor;
  final bool isLogout;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.subtitleColor,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isLogout ? Colors.red : textColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15,
                  fontWeight: isLogout ? FontWeight.w600 : FontWeight.w500,
                  color: isLogout ? Colors.red : textColor,
                ),
              ),
            ),
            if (!isLogout)
              Icon(Icons.chevron_right, size: 20, color: subtitleColor),
          ],
        ),
      ),
    );
  }
}

class _ThemeMenuItem extends StatelessWidget {
  final Color textColor;
  final Color subtitleColor;

  const _ThemeMenuItem({
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return InkWell(
          onTap: () => ThemeNotifier.instance.toggle(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 22,
                  color: textColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Theme',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                SizedBox(
                  height: 28,
                  width: 46,
                  child: Switch(
                    value: isDark,
                    onChanged: (_) => ThemeNotifier.instance.toggle(),
                    activeColor: AppTheme.primaryGreen,
                    activeTrackColor:
                        AppTheme.primaryGreen.withValues(alpha: 0.3),
                    inactiveThumbColor: AppTheme.subtitleGrey,
                    inactiveTrackColor:
                        AppTheme.subtitleGrey.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: color),
    );
  }
}
