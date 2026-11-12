import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilogue/config/reader_config.dart';
import 'package:epilogue/screens/main_shell_screen.dart';
import 'package:epilogue/screens/settings_screen.dart';
import 'package:epilogue/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Studio Removal Test Suite (Requirement R2)', () {
    // =========================================================================
    // Tier 1: Category-Partition & File Purge Verification
    // =========================================================================
    test('Tier 1: Verify all 11 studio files and studio assets do not exist on disk', () {
      final studioFiles = [
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

      final existingFiles = <String>[];
      for (final relPath in studioFiles) {
        final file = File(relPath);
        if (file.existsSync()) {
          existingFiles.add(relPath);
        }
      }

      expect(
        existingFiles,
        isEmpty,
        reason: 'Studio files should be completely purged from the repository. Found: $existingFiles',
      );
    });

    // =========================================================================
    // Tier 2: Boundary Value Analysis & Import Integrity
    // =========================================================================
    test('Tier 2: Verify zero studio imports across lib/ and test/ directories', () {
      final studioImportRegex = RegExp(
        r'''import\s+['"][^'"]*(?:studio_|epub_builder|epub_linter|epub_project|linter_issue)[^'"]*['"]''',
      );
      final archiveImportRegex = RegExp(
        r'''import\s+['"]package:archive/archive\.dart['"]''',
      );

      final violations = <String>[];

      void scanDirectory(Directory dir, {bool checkArchive = false}) {
        if (!dir.existsSync()) return;
        final entities = dir.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.dart')) {
            // Exclude this test file itself from self-matching
            if (entity.path.endsWith('e2e_studio_removal_test.dart')) continue;

            final lines = entity.readAsLinesSync();
            for (var i = 0; i < lines.length; i++) {
              final line = lines[i];
              if (studioImportRegex.hasMatch(line)) {
                violations.add('${entity.path}:${i + 1}: $line');
              }
              if (checkArchive && archiveImportRegex.hasMatch(line)) {
                violations.add('${entity.path}:${i + 1}: (Orphaned Archive) $line');
              }
            }
          }
        }
      }

      // Check lib/ for studio imports and orphaned package:archive
      scanDirectory(Directory('lib'), checkArchive: true);
      // Check test/ for studio imports
      scanDirectory(Directory('test'), checkArchive: false);

      expect(
        violations,
        isEmpty,
        reason: 'Found residual studio or orphaned archive imports:\n${violations.join('\n')}',
      );
    });

    // =========================================================================
    // Tier 3: Pairwise Combinatorial & Navigation Destinations Verification
    // =========================================================================
    testWidgets('Tier 3: Verify MainShellScreen renders exactly 4 navigation destinations without studio', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storageService = StorageService(prefs);

      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(storageService: storageService),
        ),
      );
      await tester.pumpAndSettle();

      // Find navigation destinations
      final destinations = find.byType(NavigationDestination);
      expect(destinations, findsNWidgets(4), reason: 'Expected exactly 4 destinations (Archive, Scenarios, Attributes, Settings)');

      // Verify explicit destination labels
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Scenarios'), findsOneWidget);
      expect(find.text('Attributes'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify that no Studio destination is rendered
      expect(find.text('Studio'), findsNothing);
      expect(find.byIcon(Icons.edit_note_outlined), findsNothing);
      expect(find.byIcon(Icons.edit_note), findsNothing);
    });

    // =========================================================================
    // Tier 4: Real-World Workloads & Configuration / Settings Purge
    // =========================================================================
    testWidgets('Tier 4: Verify ReaderConfig and SettingsScreen have no studio toggle', (tester) async {
      // 1. Verify ReaderConfig serialization does not contain enableEpubStudio
      const config = ReaderConfig();
      final map = config.toMap();
      expect(map.containsKey('enableEpubStudio'), isFalse, reason: 'enableEpubStudio must be removed from ReaderConfig');
      expect(config.toJson().contains('enableEpubStudio'), isFalse, reason: 'enableEpubStudio must be removed from ReaderConfig JSON');

      // Check reader_config.dart source code directly
      final configSource = File('lib/config/reader_config.dart').readAsStringSync();
      expect(configSource.contains('enableEpubStudio'), isFalse, reason: 'enableEpubStudio must not exist in lib/config/reader_config.dart');

      // 2. Verify BottomSheetBookDetail does not have "EDIT IN STUDIO" button
      final bottomSheetSource = File('lib/widgets/bottom_sheet_book_detail.dart').readAsStringSync();
      expect(bottomSheetSource.contains('EDIT IN STUDIO'), isFalse, reason: 'EDIT IN STUDIO button must be purged');
      expect(bottomSheetSource.contains('_editInStudio'), isFalse, reason: '_editInStudio helper must be purged');

      // 3. Verify SettingsScreen UI does not render studio switch
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storageService = StorageService(prefs);

      await tester.binding.setSurfaceSize(const Size(800, 1600));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              initialConfig: config,
              storageService: storageService,
              onConfigChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enable Epilogue Studio'), findsNothing, reason: 'SettingsScreen must not show studio toggle');
      expect(find.textContaining('EPUB 3.3 Authoring'), findsNothing);
    });
  });
}
