import 'package:flutter/material.dart';
import '../../config/theme/app_theme.dart';

class SabiTrakLogo extends StatelessWidget {
  final double fontSize;
  final double iconSize;
  final bool showText;

  const SabiTrakLogo({
    super.key,
    this.fontSize = 24,
    this.iconSize = 28,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;

    final icon = Image.asset(
      'assets/images/leaf_icon.png',
      width: iconSize,
      height: iconSize,
      errorBuilder: (_, __, ___) => Icon(
        Icons.eco,
        color: AppTheme.primaryGreen,
        size: iconSize,
      ),
    );

    if (!showText) return icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Text(
          'SabiTrak',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
