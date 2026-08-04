import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'rpto_dark_mode';
  bool _isDark = true;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> _setDark(bool value) async {
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  // ── Original API (used elsewhere in the app already) ───────────────────
  bool get isDarkMode => _isDark;
  Future<void> toggleTheme([bool? value]) => _setDark(value ?? !_isDark);

  // ── New API (used by the Profile screen) ───────────────────────────────
  bool get isDark => _isDark;
  Future<void> toggle(bool value) => _setDark(value);
}