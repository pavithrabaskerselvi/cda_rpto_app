import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------
/// ThemeColors — context-based helpers used by the Student detail/edit/
/// tabs/history screens. Reads Theme.of(context).brightness, which is
/// driven by ThemeProvider via MaterialApp.themeMode in main.dart.
/// ---------------------------------------------------------------------
class ThemeColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? const Color(0xFF05070D) : const Color(0xFFF5F7FA);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF10141F) : const Color(0xFFFFFFFF);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF5F6FA) : const Color(0xFF0B1220);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF8A93A6) : const Color(0xFF5B6472);

  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF6B7280) : const Color(0xFF9AA3B2);

  static Color divider(BuildContext context) =>
      isDark(context) ? const Color(0xFF1F2937) : const Color(0xFFE2E5EA);
}

/// ---------------------------------------------------------------------
/// CompanyColors — instance-based palette used by the Company list/
/// detail/add screens (`CompanyColors.of(isDark)`).
/// ---------------------------------------------------------------------
class CompanyColors {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color accent; // teal
  final Color gold;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color danger;
  final Color borderSubtle;

  const CompanyColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.accent,
    required this.gold,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.danger,
    required this.borderSubtle,
  });

  static const CompanyColors dark = CompanyColors(
    background: Color(0xFF05070D),
    surface: Color(0xFF10141F),
    surfaceElevated: Color(0xFF161B29),
    accent: Color(0xFF2DD4BF),
    gold: Color(0xFFC9A24B),
    textPrimary: Color(0xFFF5F6FA),
    textSecondary: Color(0xFF8A93A6),
    success: Color(0xFF3FCE8E),
    danger: Color(0xFFE0685A),
    borderSubtle: Colors.white,
  );

  static const CompanyColors light = CompanyColors(
    background: Color(0xFFF6F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F1F5),
    accent: Color(0xFF0D9488),
    gold: Color(0xFFAD7C1B),
    textPrimary: Color(0xFF11151C),
    textSecondary: Color(0xFF5B6472),
    success: Color(0xFF1F9D5A),
    danger: Color(0xFFD64545),
    borderSubtle: Colors.black,
  );

  static CompanyColors of(bool isDark) => isDark ? dark : light;
}
