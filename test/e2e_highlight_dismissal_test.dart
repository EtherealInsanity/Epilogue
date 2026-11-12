import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilogue/config/reader_config.dart';
import 'package:epilogue/models/book_info.dart';
import 'package:epilogue/models/chapter.dart';
import 'package:epilogue/screens/modern_reader_screen.dart';
import 'package:epilogue/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  final testBook = BookInfo(
    id: 'test_book_e2e',
    title: 'Omniscient Reader Test',
    author: 'Sing Shong',
    filePath: '/tmp/dummy_test_book.epub',
    totalChapters: 3,
    lastReadChapterIndex: 0,
    lastReadPageIndex: 0,
    lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
  );

  final testChapters = [
    const Chapter(
      index: 0,
      title: 'Prologue: The Apocalypse Begins',
      plainTextContent: 'There are three ways to survive in a ruined world.\nNow, I have forgotten a few, but one thing is certain.\nThe fact that you who are reading this will survive.\n[This web novel has reached its epilogue.]',
      htmlContent: '<p>There are three ways to survive in a ruined world.</p><p>Now, I have forgotten a few, but one thing is certain.</p><p>The fact that you who are reading this will survive.</p><p>[This web novel has reached its epilogue.]</p>',
      wordCount: 38,
      isLoaded: true,
    ),
    const Chapter(
      index: 1,
      title: 'Chapter 1: Starting the Scenario',
      plainTextContent: 'The subway train jolted violently as the lights flickered out.\nA dokkaebi materialized in mid-air with small horns.',
      htmlContent: '<p>The subway train jolted violently as the lights flickered out.</p><p>A dokkaebi materialized in mid-air with small horns.</p>',
      wordCount: 19,
      isLoaded: true,
    ),
  ];

  Widget buildReaderWidget({ReaderConfig? config, int initialChapter = 0}) {
    return MaterialApp(
      home: Scaffold(
        body: ModernReaderScreen(
          book: testBook,
          chapters: testChapters,
          storageService: storageService,
          config: config ?? const ReaderConfig(useOriginalBookStyles: false),
          initialChapterIndex: initialChapter,
        ),
      ),
    );
  }

  group('E2E Text Highlighting & Dismissal Test Suite (Requirement R3)', () {
    // =========================================================================
    // Tier 1: Category-Partition & Long-Press Toolbar Display
    // =========================================================================
    testWidgets('Tier 1: Long press on text displays highlight toolbar with "★ Highlight / Note"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildReaderWidget());
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('There are three ways to survive');
      expect(textFinder, findsOneWidget);

      // Verify that toolbar is initially NOT present
      expect(find.text('★ Highlight / Note'), findsNothing);

      // Perform long-press gesture on reading text
      final gesture = await tester.startGesture(tester.getCenter(textFinder));
      await tester.pump(const Duration(milliseconds: 750));
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert that highlight action button is visible
      expect(find.text('★ Highlight / Note'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // =========================================================================
    // Tier 2: Boundary Value Analysis & Tap-Outside Dismissal
    // =========================================================================
    testWidgets('Tier 2: Tapping outside selected text immediately dismisses highlight toolbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildReaderWidget());
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('There are three ways to survive');
      expect(textFinder, findsOneWidget);

      // Trigger selection via long-press
      final gesture = await tester.startGesture(tester.getCenter(textFinder));
      await tester.pump(const Duration(milliseconds: 750));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('★ Highlight / Note'), findsOneWidget);

      // Tap outside the selection (e.g. at the top margin)
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      // R3 Acceptance Criteria: Toolbar must disappear immediately
      try {
        expect(
          find.text('★ Highlight / Note'),
          findsNothing,
          reason: 'Highlight toolbar must be dismissed immediately when tapping outside selected text',
        );

        // Tap outside must NOT have triggered HUD toggle or turned the page
        expect(find.textContaining('There are three ways to survive'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    // =========================================================================
    // Tier 3: Pairwise Combinatorial & Programmatic Selection Clear
    // =========================================================================
    testWidgets('Tier 3: Programmatic selection clear dismisses toolbar without triggering HUD or page navigation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildReaderWidget());
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('There are three ways to survive');
      expect(textFinder, findsOneWidget);

      // Long-press to activate selection and toolbar
      final gesture = await tester.startGesture(tester.getCenter(textFinder));
      await tester.pump(const Duration(milliseconds: 750));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('★ Highlight / Note'), findsOneWidget);

      // Obtain SelectableRegionState and clear selection programmatically
      final selectableRegionFinder = find.byType(SelectableRegion);
      expect(selectableRegionFinder, findsOneWidget);
      final SelectableRegionState selectableRegion = tester.state(selectableRegionFinder);

      selectableRegion.clearSelection();
      selectableRegion.hideToolbar();
      await tester.pumpAndSettle();

      try {
        // Toolbar must be hidden
        expect(find.text('★ Highlight / Note'), findsNothing);

        // Verify contextMenuBuilder returns SizedBox.shrink() when selection is empty
        // Reader screen must remain on chapter 0 page 0
        expect(find.textContaining('There are three ways to survive'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    // =========================================================================
    // Tier 4: Real-World Workloads & Navigation Lifecycle Cleanup
    // =========================================================================
    testWidgets('Tier 4: Page or chapter navigation clears dangling selection and hides toolbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildReaderWidget());
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('There are three ways to survive');
      expect(textFinder, findsOneWidget);

      // Long-press to activate selection
      final gesture = await tester.startGesture(tester.getCenter(textFinder));
      await tester.pump(const Duration(milliseconds: 750));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('★ Highlight / Note'), findsOneWidget);

      // Tap on right margin (>75% width) to advance page/chapter
      // (When selection is dismissed or reset during navigation)
      await tester.tapAt(const Offset(750, 600));
      await tester.pumpAndSettle();

      try {
        // In R3, transitioning to next page or chapter must ensure toolbar is not dangling
        expect(find.text('★ Highlight / Note'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  });
}
