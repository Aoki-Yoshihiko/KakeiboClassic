// lib/services/theme_service.dart を以下のように修正

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeService extends StateNotifier<ThemeMode> {
  static const String _themeBoxName = 'theme_settings';
  late Box _themeBox;

  ThemeService() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _initBox() async {
    _themeBox = await Hive.openBox(_themeBoxName);
  }

  Future<void> _loadTheme() async {
    await _initBox();
    final savedTheme = _themeBox.get('theme_mode', defaultValue: 'system');
    switch (savedTheme) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    state = themeMode;
    await _themeBox.put('theme_mode', themeMode.name);
  }

  // toggleThemeメソッドを追加
  Future<void> toggleTheme() async {
    final newTheme = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(newTheme);
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

final themeServiceProvider = StateNotifierProvider<ThemeService, ThemeMode>((ref) {
  return ThemeService();
});