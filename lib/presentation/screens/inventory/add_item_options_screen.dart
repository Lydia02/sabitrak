import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import 'manual_entry_screen.dart';

class AddItemOptionsScreen extends StatelessWidget {
  const AddItemOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.primaryGreen),
                  ),
                  const Expanded(
                    child: Text(
                      'Add New Item',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppTheme.fieldBorderColor),
            const SizedBox(height: 24),

            // ── Options ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Scan Barcode — primary / highlighted
                  _OptionCard(
                    icon: Icons.qr_code_scanner,
                    title: 'Scan Barcode',
                    subtitle: 'Instant product lookup',
                    badge: 'FASTEST',
                    isPrimary: true,
                    onTap: () {
                      // TODO: Navigate to barcode scanner
                    },
                  ),
                  const SizedBox(height: 14),

                  // Scan Expiry Date
                  _OptionCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Scan Expiry Date',
                    subtitle: 'AI-powered detection',
                    badge: 'AI',
                    isPrimary: false,
                    onTap: () {
                      // TODO: Navigate to AI expiry capture
                    },
                  ),
                  const SizedBox(height: 14),

                  // Manual Entry
                  _OptionCard(
                    icon: Icons.edit_note,
                    title: 'Manual Entry',
                    subtitle: 'Traditional text input',
                    badge: null,
                    isPrimary: false,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ManualEntryScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isPrimary;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppTheme.primaryGreen.withValues(alpha: 0.06)
              : AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? AppTheme.primaryGreen
                : AppTheme.fieldBorderColor.withValues(alpha: 0.5),
            width: isPrimary ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPrimary
                    ? AppTheme.primaryGreen
                    : AppTheme.fieldBorderColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPrimary ? AppTheme.white : AppTheme.subtitleGrey,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isPrimary
                              ? AppTheme.primaryGreen
                              : AppTheme.primaryGreen,
                        ),
                      ),
                      if (badge != null && badge != 'FASTEST') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: AppTheme.subtitleGrey,
                    ),
                  ),
                ],
              ),
            ),
            // Badge or arrow
            if (badge == 'FASTEST')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'FASTEST',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.white,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                color: AppTheme.subtitleGrey,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
