import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilogue/config/reader_config.dart';
import 'package:epilogue/models/book_info.dart';
import 'package:epilogue/models/chapter.dart';
import 'package:epilogue/screens/modern_reader_screen.dart';
import 'package:epilogue/screens/settings_screen.dart';
import 'package:epilogue/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reader Settings Persistence & Position Restoration Tests', () {
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('epilogue_pos_test_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('1. Continuous Scroll mode restores non-zero scrollOffset and does not reset to 0.0', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      // Save config with continuousScroll
      await storage.saveConfig(const ReaderConfig(
        pageAnimation: PageAnimationType.continuousScroll,
        fontSize: 18.0,
      ));

      // Long chapter text so maxScrollExtent > 3000
      final paragraphs = List.generate(100, (i) => 'Paragraph $i: The quick brown fox jumps over the lazy dog repeatedly to generate substantial vertical height.').join('\n\n');

      final book = BookInfo(
        id: 'book_continuous',
        title: 'Continuous Novel',
        author: 'Author',
        filePath: '${tempDir.path}/book.epub',
        totalChapters: 1,
        lastReadChapterIndex: 0,
        lastReadScrollOffset: 1200.0,
        lastReadPageIndex: 0,
        lastReadProgressPercent: 50.0,
      );
      await storage.saveBooks([book]);

      final chapters = [
        Chapter(
          index: 0,
          title: 'Chapter 1',
          plainTextContent: paragraphs,
          htmlContent: '<div><p>${paragraphs.replaceAll('\n\n', '</p><p>')}</p></div>',
          wordCount: 1500,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernReaderScreen(
              book: book,
              chapters: chapters,
              initialChapterIndex: 0,
              config: storage.loadConfig(),
              storageService: storage,
            ),
          ),
        ),
      );

      // Pump frames for layout and restoration
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Find the scrollable
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      final currentOffset = scrollable.position.pixels;

      // Verify scroll offset was restored close to or at 1200.0 (not 0.0)
      expect(currentOffset, greaterThan(0.0), reason: 'Scroll offset should be restored, not reset to 0.0');
      expect((currentOffset - 1200.0).abs(), lessThanOrEqualTo(10.0), reason: 'Scroll offset should match saved offset');
    });

    testWidgets('2. Paginated mode restores non-zero pageIndex and starts at saved page', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      // Save config with smoothSlide (paged mode)
      await storage.saveConfig(const ReaderConfig(
        pageAnimation: PageAnimationType.smoothSlide,
        fontSize: 18.0,
      ));

      // Content with enough paragraphs to form at least 5 pages
      final paragraphs = List.generate(120, (i) => 'Page chunk content paragraph $i with plenty of text words and story dialogue for chapter pagination.').join('\n\n');

      final book = BookInfo(
        id: 'book_paged',
        title: 'Paged Novel',
        author: 'Author',
        filePath: '${tempDir.path}/book_paged.epub',
        totalChapters: 1,
        lastReadChapterIndex: 0,
        lastReadScrollOffset: 0.0,
        lastReadPageIndex: 3,
        lastReadProgressPercent: 40.0,
      );
      await storage.saveBooks([book]);

      final chapters = [
        Chapter(
          index: 0,
          title: 'Chapter 1',
          plainTextContent: paragraphs,
          htmlContent: '<div><p>${paragraphs.replaceAll('\n\n', '</p><p>')}</p></div>',
          wordCount: 2000,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernReaderScreen(
              book: book,
              chapters: chapters,
              initialChapterIndex: 0,
              config: storage.loadConfig(),
              storageService: storage,
            ),
          ),
        ),
      );

      // Pump frames for layout, chunk splitting, and controller jump
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);
      final pageView = tester.widget<PageView>(pageViewFinder);
      expect(pageView.controller, isNotNull);
      expect(pageView.controller!.page?.round(), equals(3), reason: 'PageView should be at page 3');
    });

    testWidgets('3. SettingsScreen allows toggling Reading Mode between Vertical Scroll and Page Turn', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      ReaderConfig current = const ReaderConfig(pageAnimation: PageAnimationType.smoothSlide);
      await storage.saveConfig(current);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            initialConfig: current,
            storageService: storage,
            onConfigChanged: (c) => current = c,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate into 'Reading Engine & Controls' subpage
      final categoryTile = find.text('Reading Engine & Controls');
      expect(categoryTile, findsOneWidget);
      await tester.tap(categoryTile);
      await tester.pumpAndSettle();

      // Find 'Vertical Scroll' button and tap it
      final verticalButton = find.widgetWithText(OutlinedButton, 'Vertical Scroll');
      expect(verticalButton, findsOneWidget);
      await tester.tap(verticalButton);
      await tester.pumpAndSettle();

      expect(current.pageAnimation, equals(PageAnimationType.continuousScroll));
      expect(storage.loadConfig().pageAnimation, equals(PageAnimationType.continuousScroll));

      // Find 'Page Turn' button and tap it
      final pagedButton = find.widgetWithText(OutlinedButton, 'Page Turn');
      expect(pagedButton, findsOneWidget);
      await tester.tap(pagedButton);
      await tester.pumpAndSettle();

      expect(current.pageAnimation, equals(PageAnimationType.smoothSlide));
      expect(storage.loadConfig().pageAnimation, equals(PageAnimationType.smoothSlide));
    });

    testWidgets('4. Reader settings changed via BottomSheetReaderSettings are saved and persisted', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      // Persist paperLight and smoothSlide in storage
      await storage.saveConfig(const ReaderConfig(
        themePreset: ReaderThemePreset.paperLight,
        pageAnimation: PageAnimationType.smoothSlide,
        fontSize: 16.0,
      ));

      final book = BookInfo(
        id: 'book_settings',
        title: 'Settings Test',
        author: 'Author',
        filePath: '${tempDir.path}/book_s.epub',
      );

      final chapters = [
        Chapter(
          index: 0,
          title: 'Chapter 1',
          plainTextContent: 'Some text content here',
          htmlContent: '<p>Some text content here</p>',
          wordCount: 10,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final activeConfig = storage.loadConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernReaderScreen(
              book: book,
              chapters: chapters,
              initialChapterIndex: 0,
              config: activeConfig,
              storageService: storage,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap center of screen to toggle HUD
      await tester.tapAt(const Offset(400, 600));
      await tester.pumpAndSettle();

      // Open settings HUD by tapping the reader settings icon (Icons.tune)
      final settingsIconFinder = find.byIcon(Icons.tune);
      expect(settingsIconFinder, findsOneWidget);
      await tester.tap(settingsIconFinder);
      await tester.pumpAndSettle();

      // Tap 'Vertical Scroll' button in reader settings bottom sheet
      final verticalBtn = find.widgetWithText(OutlinedButton, 'Vertical Scroll');
      expect(verticalBtn, findsOneWidget);
      await tester.tap(verticalBtn);
      await tester.pumpAndSettle();

      // Verify that StorageService has saved the new config immediately
      final savedConfig = storage.loadConfig();
      expect(savedConfig.pageAnimation, equals(PageAnimationType.continuousScroll));
    });
  });
}
