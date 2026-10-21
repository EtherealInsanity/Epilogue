import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epilogue/config/reader_config.dart';
import 'package:epilogue/theme/epilogue_theme.dart';
import 'package:epilogue/services/update_checker_service.dart';

void main() {
  group('Theme & Config & 4th Wall Tests', () {
    test('ReaderConfig serializes and deserializes fourthWall properties', () {
      const config = ReaderConfig(
        fourthWallActive: true,
        fourthWallHexColor: '#0B192C',
      );

      final map = config.toMap();
      expect(map['fourthWallActive'], true);
      expect(map['fourthWallHexColor'], '#0B192C');

      final fromMap = ReaderConfig.fromMap(map);
      expect(fromMap.fourthWallActive, true);
      expect(fromMap.fourthWallHexColor, '#0B192C');
    });

    test('EpilogueTheme dynamic palettes update on applyConfig', () {
      const paperConfig = ReaderConfig(themePreset: ReaderThemePreset.paperLight);
      EpilogueTheme.applyConfig(paperConfig);
      expect(EpilogueTheme.background, const Color(0xFFF9FAFB));

      const sepiaConfig = ReaderConfig(themePreset: ReaderThemePreset.sepiaWarm);
      EpilogueTheme.applyConfig(sepiaConfig);
      expect(EpilogueTheme.background, const Color(0xFFFBF0D9));

      const oledConfig = ReaderConfig(themePreset: ReaderThemePreset.oledDark);
      EpilogueTheme.applyConfig(oledConfig);
      expect(EpilogueTheme.background, const Color(0xFF000000));

      const fourthWallConfig = ReaderConfig(
        fourthWallActive: true,
        fourthWallHexColor: '#0A192F',
      );
      EpilogueTheme.applyConfig(fourthWallConfig);
      expect(EpilogueTheme.background, const Color(0xFF0A192F));
      expect(EpilogueTheme.accent, const Color(0xFF64FFDA));
    });

    test('UpdateCheckerService semantic comparison operates accurately', () {
      expect(UpdateCheckerService.currentVersion, '2.0.3+203');
      expect(UpdateCheckerService.currentSemantic, '2.0.3');
    });
  });
}
