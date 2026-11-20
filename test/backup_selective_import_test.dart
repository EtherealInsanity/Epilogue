import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilogue/config/reader_config.dart';
import 'package:epilogue/models/book_info.dart';
import 'package:epilogue/models/book_highlight.dart';
import 'package:epilogue/models/bookmark.dart';
import 'package:epilogue/models/daily_reading_record.dart';
import 'package:epilogue/models/orv_state.dart';
import 'package:epilogue/models/reading_session.dart';
import 'package:epilogue/services/data_sync_service.dart';
import 'package:epilogue/services/storage_service.dart';
import 'package:epilogue/widgets/dialog_backup_import_selection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Selective Backup Import & Options Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    final testBackupMap = {
      'epilogue_version': '2.0.0',
      'exported_at': 1700000000000,
      'books': [
        {
          'id': 'book_1',
          'title': 'Omniscient Reader',
          'author': 'Sing Shong',
          'filePath': '/path/orv.epub',
          'totalChapters': 551,
          'lastReadChapterIndex': 10,
          'lastReadProgressPercent': 45.0,
          'totalWordsRead': 15000,
          'totalSecondsSpentReading': 3600,
        }
      ],
      'bookmarks': [
        {
          'id': 'bm_1',
          'bookId': 'book_1',
          'chapterIndex': 5,
          'paragraphIndex': 2,
          'textSnippet': 'Three ways to survive in a ruined world.',
          'createdAt': 1700000001000,
        }
      ],
      'highlights': [
        {
          'id': 'hl_1',
          'bookId': 'book_1',
          'chapterIndex': 10,
          'text': 'Tell me, fool. If I regress, will that moment be the real me?',
          'colorHex': '#FFE082',
          'createdAt': 1700000002000,
        }
      ],
      'reading_sessions': [
        {
          'id': 'session_1',
          'bookId': 'book_1',
          'startTimeMillis': 1700000000000,
          'durationSeconds': 1800,
          'wordsRead': 8000,
        }
      ],
      'daily_records': {
        '2026-11-14': {
          'dateKey': '2026-11-14',
          'totalSeconds': 1800,
          'totalWords': 8000,
          'chaptersCompleted': 3,
        }
      },
      'shelves': [
        {
          'id': 'shelf_fav',
          'name': 'Favorites',
          'bookIds': ['book_1'],
        }
      ],
      'orv_state': {
        'coins': 50000,
        'completedScenarioIds': ['scenario_1'],
        'acquiredFables': ['Fable of the Stars'],
        'unlockedModifiers': ['Watcher of the End'],
        'unlockedAttributes': ['Reader'],
      },
      'config': {
        'themePreset': 'midnightOled',
        'fontSize': 20.0,
      },
    };

    final testBackupJson = jsonEncode(testBackupMap);

    test('BackupSummary inspects and counts backup components accurately', () {
      final summary = BackupSummary.fromJson(testBackupJson);
      expect(summary, isNotNull);
      expect(summary!.isEmpty, isFalse);
      expect(summary.bookCount, equals(1));
      expect(summary.bookmarkCount, equals(1));
      expect(summary.highlightCount, equals(1));
      expect(summary.sessionCount, equals(1));
      expect(summary.dailyRecordCount, equals(1));
      expect(summary.shelfCount, equals(1));
      expect(summary.hasOrvState, isTrue);
      expect(summary.hasSettings, isTrue);

      final emptySummary = BackupSummary.fromJson('{}');
      expect(emptySummary, isNotNull);
      expect(emptySummary!.isEmpty, isTrue);

      final invalidSummary = BackupSummary.fromJson('not-a-json');
      expect(invalidSummary, isNull);
    });

    test('DataSyncService imports only bookmarks when only bookmarks selected', () async {
      final storage = await StorageService.initialize();
      final syncService = DataSyncService(storage);

      const options = BackupImportOptions(
        importBooks: false,
        importBookmarks: true,
        importHighlights: false,
        importTelemetry: false,
        importShelves: false,
        importOrvState: false,
        importSettings: false,
      );

      final ok = await syncService.importBackupFromJson(testBackupJson, options: options);
      expect(ok, isTrue);

      // Bookmarks imported
      final bms = storage.loadBookmarks('book_1');
      expect(bms.length, equals(1));
      expect(bms.first.id, equals('bm_1'));

      // Other items should NOT be imported
      expect(storage.loadBooks().isEmpty, isTrue);
      expect(storage.loadHighlightsForBook('book_1').isEmpty, isTrue);
      expect(storage.loadDailyRecords().isEmpty, isTrue);
      expect(storage.loadShelves().any((s) => s.id == 'shelf_fav'), isFalse);
      expect(storage.loadOrvState().coins, equals(0)); // default blank slate
    });

    test('DataSyncService imports only highlights and telemetry when selected', () async {
      final storage = await StorageService.initialize();
      final syncService = DataSyncService(storage);

      const options = BackupImportOptions(
        importBooks: false,
        importBookmarks: false,
        importHighlights: true,
        importTelemetry: true,
        importShelves: false,
        importOrvState: false,
        importSettings: false,
      );

      final ok = await syncService.importBackupFromJson(testBackupJson, options: options);
      expect(ok, isTrue);

      // Highlights & Telemetry imported
      final hls = storage.loadHighlightsForBook('book_1');
      expect(hls.length, equals(1));
      expect(hls.first.id, equals('hl_1'));

      final daily = storage.loadDailyRecords();
      expect(daily.containsKey('2026-11-14'), isTrue);
      expect(daily['2026-11-14']!.totalWords, equals(8000));

      final sessions = storage.loadRecentSessions();
      expect(sessions.length, equals(1));
      expect(sessions.first.id, equals('session_1'));

      // Books and Bookmarks NOT imported
      expect(storage.loadBooks().isEmpty, isTrue);
      expect(storage.loadBookmarks('book_1').isEmpty, isTrue);
    });

    test('DataSyncService returns false when no options selected', () async {
      final storage = await StorageService.initialize();
      final syncService = DataSyncService(storage);

      const options = BackupImportOptions(
        importBooks: false,
        importBookmarks: false,
        importHighlights: false,
        importTelemetry: false,
        importShelves: false,
        importOrvState: false,
        importSettings: false,
      );

      final ok = await syncService.importBackupFromJson(testBackupJson, options: options);
      expect(ok, isFalse);
    });

    testWidgets('DialogBackupImportSelection displays counts and allows category selection', (tester) async {
      final summary = BackupSummary.fromJson(testBackupJson)!;
      BackupImportOptions? chosenOptions;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  chosenOptions = await showDialog<BackupImportOptions>(
                    context: ctx,
                    builder: (_) => DialogBackupImportSelection(summary: summary),
                  );
                },
                child: const Text('OPEN DIALOG'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      expect(find.text('Select What to Import'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('Highlights & Notes'), findsOneWidget);
      expect(find.text('Reading Telemetry'), findsOneWidget);
      expect(find.text('Books & Reading Progress'), findsOneWidget);

      // Verify counts in subtitles
      expect(find.text('1 bookmark(s) found'), findsOneWidget);
      expect(find.text('1 highlight(s) found'), findsOneWidget);
      expect(find.text('1 book(s) found'), findsOneWidget);

      // Tap CLEAR ALL
      await tester.tap(find.text('CLEAR ALL'));
      await tester.pumpAndSettle();

      // IMPORT button should be disabled when nothing selected
      final importBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'IMPORT SELECTED'));
      expect(importBtn.onPressed, isNull);

      // Re-select Bookmarks only
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();

      final importBtnActive = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'IMPORT SELECTED'));
      expect(importBtnActive.onPressed, isNotNull);

      // Tap IMPORT SELECTED
      await tester.tap(find.widgetWithText(FilledButton, 'IMPORT SELECTED'));
      await tester.pumpAndSettle();

      expect(chosenOptions, isNotNull);
      expect(chosenOptions!.importBookmarks, isTrue);
      expect(chosenOptions!.importHighlights, isFalse);
      expect(chosenOptions!.importTelemetry, isFalse);
      expect(chosenOptions!.importBooks, isFalse);
    });
  });
}
