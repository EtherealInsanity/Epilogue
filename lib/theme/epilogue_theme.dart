import 'package:flutter/material.dart';

class EpilogueTheme {
  // Pure Clean Frost / Paper Light Colors (Zero Yellow)
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF3F4F6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFD1D5DB);

  // Typography
  static const Color textPrimary = Color(0xFF111827); // Ink Black
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Accents
  static const Color accent = Color(0xFF1E293B); // Deep Slate / Dokkaebi Ink
  static const Color starGold = Color(0xFFB45309); // Muted Dark Gold for badges
  static const Color cyanAccent = Color(0xFF0284C7); // Clean Azure Blue
  static const Color greenAccent = Color(0xFF16A34A); // Emerald Clear
  static const Color dangerAccent = Color(0xFFDC2626); // Crimson Alert

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        surface: surface,
        primary: accent,
        secondary: cyanAccent,
        tertiary: greenAccent,
        error: dangerAccent,
        onSurface: textPrimary,
        onPrimary: Colors.white,
        outline: border,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        elevation: 0,
      ),
    );
  }
}
