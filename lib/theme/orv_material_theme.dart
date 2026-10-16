import 'package:flutter/material.dart';
import '../config/reader_config.dart';

class OrvMaterialTheme {
  // Star Stream Dark Colors
  static const Color voidBlack = Color(0xFF090C10);
  static const Color surfaceDark = Color(0xFF131720);
  static const Color surfaceElevated = Color(0xFF1C2230);
  static const Color borderSubtle = Color(0xFF2A3245);

  // Star Stream System Accents
  static const Color celestialGold = Color(0xFFE5C07B);
  static const Color fourthWallCyan = Color(0xFF56B6C2);
  static const Color fourthWallGreen = Color(0xFF98C379);
  static const Color crimsonHazard = Color(0xFFE06C75);
  static const Color starlightWhite = Color(0xFFECEFF4);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData themeFor(ReaderThemePreset preset) {
    switch (preset) {
      case ReaderThemePreset.oledDark:
        return _buildDarkTheme(
          background: Colors.black,
          surface: const Color(0xFF0D0D0D),
          surfaceElevated: const Color(0xFF1A1A1A),
          border: const Color(0xFF2B2B2B),
          accent: fourthWallCyan,
        );
      case ReaderThemePreset.paperLight:
      default:
        return _buildLightTheme();
    }
  }

  static ThemeData _buildDarkTheme({
    required Color background,
    required Color surface,
    required Color surfaceElevated,
    required Color border,
    required Color accent,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        surface: surface,
        primary: accent,
        secondary: fourthWallCyan,
        tertiary: fourthWallGreen,
        error: crimsonHazard,
        onSurface: starlightWhite,
        onPrimary: Colors.black,
        outline: border,
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 0.8),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: starlightWhite,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      colorScheme: const ColorScheme.light(
        surface: Colors.white,
        primary: Color(0xFF2B5B84),
        secondary: Color(0xFF2C7A7B),
        onSurface: Color(0xFF1A202C),
        outline: Color(0xFFE2E8F0),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}
