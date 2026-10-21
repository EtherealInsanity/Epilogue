import 'package:flutter/material.dart';
import '../config/reader_config.dart';

class ThemePalette {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color starGold;
  final Color cyanAccent;
  final Color greenAccent;
  final Color dangerAccent;
  final Brightness brightness;

  const ThemePalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.starGold,
    required this.cyanAccent,
    required this.greenAccent,
    required this.dangerAccent,
    required this.brightness,
  });

  static const ThemePalette paperLight = ThemePalette(
    background: Color(0xFFF9FAFB),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF3F4F6),
    border: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFD1D5DB),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF9CA3AF),
    accent: Color(0xFF1E293B),
    starGold: Color(0xFFB45309),
    cyanAccent: Color(0xFF0284C7),
    greenAccent: Color(0xFF16A34A),
    dangerAccent: Color(0xFFDC2626),
    brightness: Brightness.light,
  );

  static const ThemePalette sepiaWarm = ThemePalette(
    background: Color(0xFFFBF0D9),
    surface: Color(0xFFF4E8C1),
    surfaceElevated: Color(0xFFEDE0B7),
    border: Color(0xFFDECBA4),
    borderStrong: Color(0xFFCCA97E),
    textPrimary: Color(0xFF2C2416),
    textSecondary: Color(0xFF5E4F39),
    textMuted: Color(0xFF8F7B5E),
    accent: Color(0xFF78350F),
    starGold: Color(0xFFD97706),
    cyanAccent: Color(0xFF0D9488),
    greenAccent: Color(0xFF15803D),
    dangerAccent: Color(0xFFB91C1C),
    brightness: Brightness.light,
  );

  static const ThemePalette slateGray = ThemePalette(
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceElevated: Color(0xFF334155),
    border: Color(0xFF334155),
    borderStrong: Color(0xFF475569),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    accent: Color(0xFF38BDF8),
    starGold: Color(0xFFF59E0B),
    cyanAccent: Color(0xFF38BDF8),
    greenAccent: Color(0xFF22C55E),
    dangerAccent: Color(0xFFEF4444),
    brightness: Brightness.dark,
  );

  static const ThemePalette oledDark = ThemePalette(
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceElevated: Color(0xFF1E1E1E),
    border: Color(0xFF272727),
    borderStrong: Color(0xFF3F3F46),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    accent: Color(0xFF38BDF8),
    starGold: Color(0xFFFBBF24),
    cyanAccent: Color(0xFF06B6D4),
    greenAccent: Color(0xFF4ADE80),
    dangerAccent: Color(0xFFF87171),
    brightness: Brightness.dark,
  );

  static ThemePalette fourthWall(String hexCode) {
    Color bg = _parseColor(hexCode, const Color(0xFF0A192F));
    // Ensure dark tone for 4th Wall
    final surface = Color.alphaBlend(Colors.white.withValues(alpha: 0.08), bg);
    final surfaceElevated = Color.alphaBlend(Colors.white.withValues(alpha: 0.15), bg);
    final border = Color.alphaBlend(const Color(0xFF64FFDA).withValues(alpha: 0.22), bg);
    final borderStrong = Color.alphaBlend(const Color(0xFF64FFDA).withValues(alpha: 0.40), bg);

    return ThemePalette(
      background: bg,
      surface: surface,
      surfaceElevated: surfaceElevated,
      border: border,
      borderStrong: borderStrong,
      textPrimary: const Color(0xFFE6F1FF), // Luminescent frosty silver
      textSecondary: const Color(0xFF8892B0), // Slate cyan-silver
      textMuted: const Color(0xFF5D6B88),
      accent: const Color(0xFF64FFDA), // 4th Wall Mint-Cyan Glow
      starGold: const Color(0xFFFFD166),
      cyanAccent: const Color(0xFF64FFDA),
      greenAccent: const Color(0xFF64FFDA),
      dangerAccent: const Color(0xFFFF5370),
      brightness: Brightness.dark,
    );
  }

  static Color _parseColor(String hex, Color fallback) {
    try {
      String clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}

class EpilogueTheme {
  static ThemePalette _currentPalette = ThemePalette.paperLight;

  static void applyConfig(ReaderConfig config) {
    if (config.fourthWallActive) {
      _currentPalette = ThemePalette.fourthWall(config.fourthWallHexColor);
    } else {
      switch (config.themePreset) {
        case ReaderThemePreset.paperLight:
          _currentPalette = ThemePalette.paperLight;
          break;
        case ReaderThemePreset.sepiaWarm:
          _currentPalette = ThemePalette.sepiaWarm;
          break;
        case ReaderThemePreset.slateGray:
          _currentPalette = ThemePalette.slateGray;
          break;
        case ReaderThemePreset.oledDark:
          _currentPalette = ThemePalette.oledDark;
          break;
      }
    }
  }

  static Color get background => _currentPalette.background;
  static Color get surface => _currentPalette.surface;
  static Color get surfaceElevated => _currentPalette.surfaceElevated;
  static Color get border => _currentPalette.border;
  static Color get borderStrong => _currentPalette.borderStrong;

  static Color get textPrimary => _currentPalette.textPrimary;
  static Color get textSecondary => _currentPalette.textSecondary;
  static Color get textMuted => _currentPalette.textMuted;

  static Color get accent => _currentPalette.accent;
  static Color get starGold => _currentPalette.starGold;
  static Color get cyanAccent => _currentPalette.cyanAccent;
  static Color get greenAccent => _currentPalette.greenAccent;
  static Color get dangerAccent => _currentPalette.dangerAccent;

  static Brightness get brightness => _currentPalette.brightness;

  static ThemeData lightTheme() => buildThemeData(const ReaderConfig());

  static ThemeData buildThemeData([ReaderConfig? config]) {
    if (config != null) {
      applyConfig(config);
    }

    final isDark = _currentPalette.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: _currentPalette.brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: _currentPalette.brightness,
        primary: accent,
        onPrimary: isDark ? const Color(0xFF0A192F) : Colors.white,
        secondary: cyanAccent,
        onSecondary: isDark ? const Color(0xFF0A192F) : Colors.white,
        tertiary: greenAccent,
        onTertiary: Colors.white,
        error: dangerAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        outline: border,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        elevation: 0,
      ),
    );
  }
}
