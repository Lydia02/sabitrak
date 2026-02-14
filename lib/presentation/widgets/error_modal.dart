import 'package:flutter/material.dart';
import '../../config/theme/app_theme.dart';

/// Shows a modal dialog for errors, validation messages, or confirmations.
Future<void> showErrorModal(
  BuildContext context, {
  required String title,
  required String message,
  String buttonText = 'OK',
  VoidCallback? onPressed,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final dialogColor = isDark ? AppTheme.darkCard : AppTheme.white;
  final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
  final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: dialogColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red.withValues(alpha: 0.15)
                    : const Color(0xFFFFEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: Colors.red, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onPressed?.call();
              },
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a success modal dialog.
Future<void> showSuccessModal(
  BuildContext context, {
  required String title,
  required String message,
  String buttonText = 'OK',
  VoidCallback? onPressed,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final dialogColor = isDark ? AppTheme.darkCard : AppTheme.white;
  final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
  final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: dialogColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                    : const Color(0xFFEEF7EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppTheme.primaryGreen, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onPressed?.call();
              },
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    ),
  );
}
