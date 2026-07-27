import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    _isDark = _prefs.getBool('darkMode') ?? false;
  }

  final SharedPreferences _prefs;

  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeMode get themeMode =>
      _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> setDarkMode(bool value) async {
    _isDark = value;
    await _prefs.setBool('darkMode', value);
    notifyListeners();
  }
}