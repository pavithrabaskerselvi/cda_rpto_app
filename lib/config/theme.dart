import 'package:flutter/material.dart';

/// Design tokens - same dark navy system as CDA Inventory app
class AppColors {
  static const Color bg = Color(0xFF050A14);
  static const Color blue = Color(0xFF1E5FC8);
  static const Color navy = Color(0xFF0B1220);
  static const Color surface = Color(0xFF10192B);
  static const Color teal = Color(0xFF14B8A6);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color amber = Color(0xFFFFB020);
  static const Color green = Color(0xFF2ECC71);
  static const Color purple = Color(0xFF9B59B6);
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF8A94A6);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFF1F2937);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.blue,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.teal,
        surface: AppColors.surface,
        error: AppColors.coral,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardColor: AppColors.surface,

      // ---- Centralized text styles used by ALL screen headers ----
      // DroneList, Drone Details, and Company Details should all read
      // from this instead of hardcoding their own TextStyle, so the
      // whole app stays visually consistent from one place.
      textTheme: const TextTheme(
        // Big screen titles ("DroneList", "Company Details", "Drone Details")
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        // Slightly smaller section headers
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        // Card titles (drone name, company name)
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      dividerColor: AppColors.border,
      useMaterial3: true,
    );
  }

  /// Light counterpart, only needed so MaterialApp.themeMode can actually
  /// flip Theme.of(context).brightness for the screens that check it
  /// (Student + Company modules). Dashboard/Login/Profile/etc still read
  /// AppColors directly and stay dark regardless — unchanged from before.
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      primaryColor: AppColors.blue,
      colorScheme: const ColorScheme.light(
        primary: AppColors.blue,
        secondary: AppColors.teal,
        surface: Colors.white,
        error: AppColors.coral,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7FA),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0B1220)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0B1220),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE2E5EA),
      useMaterial3: true,
    );
  }
}
