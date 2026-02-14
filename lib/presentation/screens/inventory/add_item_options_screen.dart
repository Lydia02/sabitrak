import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import 'manual_entry_screen.dart';

class AddItemOptionsScreen extends StatelessWidget {
  const AddItemOptionsScreen({super.key});

  /// Call this to show the Add Item dialog from anywhere.
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _AddItemDialog(parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _AddItemDialog extends StatelessWidget {
  final BuildContext parentContext;

  const _AddItemDialog({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Add Item',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              const Text(
                'Choose an option below to add an item.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: AppTheme.subtitleGrey,
                ),
              ),
              const SizedBox(height: 24),

              // ── Scan Barcode (filled green button) ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: Navigate to barcode scanner
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Scan Barcode',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.qr_code,
                        size: 20,
                        color: AppTheme.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fastest for packaged foods.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: AppTheme.subtitleGrey,
                ),
              ),
              const SizedBox(height: 18),

              // ── Add Manually (outlined button) ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(parentContext).push(
                      MaterialPageRoute(
                        builder: (_) => const ManualEntryScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Add Manually',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.edit, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'For local or unpackaged foods.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: AppTheme.subtitleGrey,
                ),
              ),
              const SizedBox(height: 18),

              // ── Capture Expiry Date (outlined button) ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: Navigate to AI expiry capture
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Capture Expiry Date',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.camera_alt_outlined, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Scan expiry label using camera.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: AppTheme.subtitleGrey,
                ),
              ),
              const SizedBox(height: 20),

              // ── Cancel ──
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.subtitleGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
