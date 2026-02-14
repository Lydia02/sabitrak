import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static const _key = 'theme_mode';
  static final ThemeNotifier instance = ThemeNotifier._();

  ThemeNotifier._() : super(ThemeMode.light);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'dark') {
      value = ThemeMode.dark;
    } else {
      value = ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => value == ThemeMode.dark;
}
