import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilogue/config/reader_config.dart';
import 'package:epilogue/screens/main_shell_screen.dart';
import 'package:epilogue/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Stress Test: Milestone 1 Studio Removal & Legacy Invariants', () {
    test('Legacy Config Deserialization Stress Test: ReaderConfig handles legacy maps with enableEpubStudio without crashing', () {
      // 1. Legacy map with enableEpubStudio: true
      final legacyMapTrue = <String, dynamic>{
        'enableEpubStudio': true,
        'fontSize': 21.0,
        'fontFamily': 'serif',
        'themePreset': 'slateGray',
      };

      final configTrue = ReaderConfig.fromMap(legacyMapTrue);
      expect(configTrue.fontSize, 21.0);
      expect(configTrue.fontFamily, 'serif');
      expect(configTrue.themePreset, ReaderThemePreset.slateGray);

      // 2. Legacy map with enableEpubStudio: false
      final legacyMapFalse = <String, dynamic>{
        'enableEpubStudio': false,
        'fontSize': 14.5,
      };
      final configFalse = ReaderConfig.fromMap(legacyMapFalse);
      expect(configFalse.fontSize, 14.5);

      // 3. Legacy JSON string with enableEpubStudio and malformed unexpected types
      final rawLegacyJson = jsonEncode({
        'enableEpubStudio': true,
        'legacyStudioProjectCount': 5,
        'unknownFieldX': 'orphan',
        'themePreset': 'oledDark',
        'fontSize': 19.0,
      });

      final configFromJson = ReaderConfig.fromJson(rawLegacyJson);
      expect(configFromJson.fontSize, 19.0);
      expect(configFromJson.themePreset, ReaderThemePreset.oledDark);

      // 4. Verify serialized output strips legacy keys cleanly
      final exportedMap = configFromJson.toMap();
      expect(exportedMap.containsKey('enableEpubStudio'), isFalse);
      expect(exportedMap.containsKey('legacyStudioProjectCount'), isFalse);
      expect(configFromJson.toJson().contains('enableEpubStudio'), isFalse);
    });

    test('Legacy StorageService Invariant: SharedPreferences migration with legacy keys containing enableEpubStudio', () async {
      final legacyConfigJson = jsonEncode({
        'enableEpubStudio': true,
        'fontSize': 22.0,
        'fontFamily': 'mono',
        'themePreset': 'paperLight',
      });

      // Scenario A: Stored under primary epilogue_config key
      SharedPreferences.setMockInitialValues({
        'epilogue_config': legacyConfigJson,
      });
      var prefs = await SharedPreferences.getInstance();
      var storage = StorageService(prefs);

      var loaded = storage.loadConfig();
      expect(loaded.fontSize, 22.0);
      expect(loaded.fontFamily, 'mono');

      // Resave should not re-introduce enableEpubStudio
      await storage.saveConfig(loaded);
      final rawSaved = prefs.getString('epilogue_config')!;
      expect(rawSaved.contains('enableEpubStudio'), isFalse);

      // Scenario B: Stored under legacy ani_read_config key
      SharedPreferences.setMockInitialValues({
        'ani_read_config': legacyConfigJson,
      });
      prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);

      loaded = storage.loadConfig();
      expect(loaded.fontSize, 22.0);
      expect(loaded.fontFamily, 'mono');
    });

    testWidgets('Navigation Destination Clamping Stress Test: MainShellScreen safeIndex prevents out-of-bounds crash', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(storageService: storage),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly 4 destinations exist
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 4);
      expect(navBar.selectedIndex, 0);

      // Tap through all 4 destinations (0: Archive, 1: Scenarios, 2: Attributes, 3: Settings)
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byType(NavigationDestination).at(i));
        await tester.pumpAndSettle();

        final updatedNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(updatedNavBar.selectedIndex, i);
      }

      // Directly invoke onDestinationSelected with out-of-bounds index (e.g. 4, the old studio tab index)
      // MainShellScreen should clamp this to 3 without RangeError or assertion crash
      navBar.onDestinationSelected!(4);
      await tester.pumpAndSettle();

      final clampedNavBar4 = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(clampedNavBar4.selectedIndex, 3); // Clamped to 3 (Settings)

      // Invoke onDestinationSelected with extreme out-of-bounds (e.g. 99 and -5)
      navBar.onDestinationSelected!(99);
      await tester.pumpAndSettle();
      final clampedNavBar99 = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(clampedNavBar99.selectedIndex, 3);

      navBar.onDestinationSelected!(-5);
      await tester.pumpAndSettle();
      final clampedNavBarNeg = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(clampedNavBarNeg.selectedIndex, 0);
    });

    test('Empirical Grep & Purge Verification: No active studio references or files remain', () {
      final deletedFiles = [
        'lib/screens/studio_dashboard_screen.dart',
        'lib/screens/studio_editor_screen.dart',
        'lib/screens/studio_linter_screen.dart',
        'lib/screens/studio_metadata_screen.dart',
        'lib/screens/studio_spine_screen.dart',
        'lib/services/studio_project_service.dart',
        'lib/services/epub_builder_service.dart',
        'lib/services/epub_linter_service.dart',
        'lib/models/epub_project.dart',
        'lib/models/linter_issue.dart',
        'test/epub_studio_test.dart',
        'assets/images/icon_studio.png',
      ];

      for (final p in deletedFiles) {
        expect(File(p).existsSync(), isFalse, reason: 'File $p must not exist');
      }

      // Check pubspec.yaml
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('archive:'), isFalse, reason: 'archive dependency must be purged from pubspec.yaml');

      // Check lib/ directory: zero mentions of enableEpubStudio
      final libDir = Directory('lib');
      for (final f in libDir.listSync(recursive: true)) {
        if (f is File && f.path.endsWith('.dart')) {
          final content = f.readAsStringSync();
          expect(
            content.contains('enableEpubStudio'),
            isFalse,
            reason: 'lib file ${f.path} contains enableEpubStudio',
          );
          if (!f.path.endsWith('changelog_screen.dart')) {
            expect(
              content.toLowerCase().contains('studio'),
              isFalse,
              reason: 'Non-changelog file ${f.path} contains studio reference',
            );
          }
        }
      }
    });
  });
}
