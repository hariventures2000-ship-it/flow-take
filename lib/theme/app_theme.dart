import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFAFAFA);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color brandBlack = Color(0xFF0F172A);
  static const Color brandGray = Color(0xFFF3F4F6);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: brandBlack,
        onPrimary: Colors.white,
        surface: background,
        onSurface: textPrimary,
        error: error,
      ),
      fontFamily: null, // Clean default system sans-serif
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
