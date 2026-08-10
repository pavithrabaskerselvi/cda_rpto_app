import 'package:flutter/material.dart';

/// Dark mode has been removed from the app. The app is light-theme only.
/// This provider is kept so existing `context.watch<ThemeProvider>()` calls
/// throughout the codebase keep compiling, but it always reports light mode
/// and the toggle methods are no-ops.
class ThemeProvider extends ChangeNotifier {
  final bool _isDark = false;

  // ── Original API (used elsewhere in the app already) ───────────────────
  bool get isDarkMode => _isDark;
  Future<void> toggleTheme([bool? value]) async {}

  // ── New API (used by the Profile screen) ───────────────────────────────
  bool get isDark => _isDark;
  Future<void> toggle(bool value) async {}
}