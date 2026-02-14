import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand Colors
  static const Color primaryGreen = Color(0xFF33401C);
  static const Color buttonGreen = Color(0xFF3B4A1C);
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color subtitleGrey = Color(0xFF6B6B6B);

  // Form Colors
  static const Color fieldHintColor = Color(0xFFA0A4B8);
  static const Color fieldBorderColor = Color(0xFFD0D0D0);
  static const Color backButtonColor = Color(0xFFA0A4B8);

  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        surface: backgroundColor,
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: fieldHintColor,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: fieldBorderColor, width: 1.0),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primaryGreen, width: 1.5),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonGreen,
          foregroundColor: white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonGreen,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: buttonGreen, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // Dark Theme
  static const Color darkScaffold = Color(0xFF1A1A1A);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkText = Color(0xFFE8E8E8);
  static const Color darkSubtitle = Color(0xFF9E9E9E);

  static ThemeData get darkTheme {
    return ThemeData(
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScaffold,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        surface: darkSurface,
        onPrimary: white,
        onSurface: darkText,
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkSubtitle,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: darkSubtitle, width: 1.0),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primaryGreen, width: 1.5),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonGreen,
          foregroundColor: white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonGreen,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: buttonGreen, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
