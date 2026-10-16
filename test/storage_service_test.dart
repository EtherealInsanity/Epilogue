import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilogue/config/reader_config.dart';
import 'package:epilogue/models/book_info.dart';
import 'package:epilogue/models/bookmark.dart';
import 'package:epilogue/models/book_highlight.dart';
import 'package:epilogue/services/storage_service.dart';
import 'package:epilogue/services/orv_service.dart';
import 'package:epilogue/models/scenario.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService & Model Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ReaderConfig serialize and deserialize matches', () {
      const config = ReaderConfig(
        themePreset: ReaderThemePreset.oledDark,
        navigationStyle: AppNavigationStyle.floatingDock,
        pageAnimation: PageAnimationType.continuousScroll,
        fontSize: 18.0,
        lineSpacing: 1.8,
        fontFamily: 'serif',
        keepScreenAwake: true,
        volumeKeysPaging: false,
        hapticFeedback: false,
        libraryFolderPath: '/sdcard/Books',
      );

      final jsonString = config.toJson();
      final loaded = ReaderConfig.fromJson(jsonString);

      expect(loaded.themePreset, equals(ReaderThemePreset.oledDark));
      expect(loaded.navigationStyle, equals(AppNavigationStyle.floatingDock));
      expect(loaded.pageAnimation, equals(PageAnimationType.continuousScroll));
      expect(loaded.fontSize, equals(18.0));
      expect(loaded.lineSpacing, equals(1.8));
      expect(loaded.fontFamily, equals('serif'));
      expect(loaded.keepScreenAwake, isTrue);
      expect(loaded.volumeKeysPaging, isFalse);
      expect(loaded.libraryFolderPath, equals('/sdcard/Books'));
    });

    test('StorageService persists books and updates progress', () async {
      final storage = await StorageService.initialize();

      const book1 = BookInfo(
        id: '/path/lotm.epub',
        title: 'Lord of the Mysteries',
        author: 'Cuttlefish That Loves Diving',
        filePath: '/path/lotm.epub',
        totalChapters: 1432,
      );

      await storage.saveBooks([book1]);
      var loadedBooks = storage.loadBooks();
      expect(loadedBooks.length, equals(1));
      expect(loadedBooks.first.title, equals('Lord of the Mysteries'));

      await storage.updateBookProgress(
        bookId: '/path/lotm.epub',
        chapterIndex: 451,
        progressPercent: 64.2,
      );

      final lastRead = storage.getLastReadBook();
      expect(lastRead, isNotNull);
      expect(lastRead!.lastReadChapterIndex, equals(451));
      expect(lastRead.lastReadProgressPercent, equals(64.2));
    });

    test('StorageService adds and deletes bookmarks', () async {
      final storage = await StorageService.initialize();

      const bookmark = Bookmark(
        id: 'bm_001',
        bookId: 'book_lotm',
        chapterIndex: 12,
        chapterTitle: 'Chapter 12: Divination',
        scrollOffset: 120.0,
        snippet: 'The silver coin spun in the air...',
        timestamp: 1690000000,
      );

      await storage.addBookmark(bookmark);
      final list = storage.loadBookmarks('book_lotm');
      expect(list.length, equals(1));
      expect(list.first.snippet, contains('silver coin'));

      await storage.deleteBookmark('book_lotm', 'bm_001');
      final afterDelete = storage.loadBookmarks('book_lotm');
      expect(afterDelete.isEmpty, isTrue);
    });

    test('StorageService records reading telemetry and aggregates stats', () async {
      final storage = await StorageService.initialize();

      const book = BookInfo(
        id: '/path/test.epub',
        title: 'Test Novel',
        author: 'Tester',
        filePath: '/path/test.epub',
        totalChapters: 10,
      );
      await storage.saveBooks([book]);

      await storage.addReadingSessionTime(
        bookId: '/path/test.epub',
        seconds: 120,
        wordsRead: 440,
      );

      final updatedBooks = storage.loadBooks();
      expect(updatedBooks.first.totalSecondsSpentReading, equals(120));
      expect(updatedBooks.first.totalWordsRead, equals(440));

      expect(storage.getTotalLibraryReadingSeconds(), equals(120));
      expect(storage.getTotalLibraryWordsRead(), equals(440));
      expect(storage.getAverageReadingWpm(), equals(220));
    });

    test('StorageService removeBook removes book and clears lastRead if matched', () async {
      final storage = await StorageService.initialize();

      const book = BookInfo(
        id: '/path/to/remove.epub',
        title: 'Disposable Book',
        author: 'Unknown',
        filePath: '/path/to/remove.epub',
        totalChapters: 5,
        coverImagePath: '/covers/cover.jpg',
      );
      await storage.saveBooks([book]);
      await storage.updateBookProgress(
        bookId: '/path/to/remove.epub',
        chapterIndex: 1,
        progressPercent: 20.0,
      );

      expect(storage.getLastReadBook()?.title, equals('Disposable Book'));
      expect(storage.loadBooks().first.coverImagePath, equals('/covers/cover.jpg'));

      await storage.removeBook('/path/to/remove.epub');
      expect(storage.loadBooks().isEmpty, isTrue);
      expect(storage.getLastReadBook(), isNull);
    });

    test('StorageService toggles grid view state', () async {
      final storage = await StorageService.initialize();

      expect(storage.isGridView(), isFalse);
      await storage.setGridView(true);
      expect(storage.isGridView(), isTrue);
      await storage.setGridView(false);
      expect(storage.isGridView(), isFalse);
    });

    test('StorageService saves, loads, and deletes highlights', () async {
      final storage = await StorageService.initialize();

      const hl = BookHighlight(
        id: 'hl_test_1',
        bookId: 'book_orv',
        bookTitle: 'ORV',
        chapterIndex: 0,
        chapterTitle: 'Prologue',
        selectedText: 'There are three ways to survive in a ruined world.',
        note: 'Dokja favorite phrase',
        colorHex: '#06B6D4',
        timestamp: 1700000000,
      );

      await storage.saveHighlight(hl);
      final all = storage.loadAllHighlights();
      expect(all.length, equals(1));
      expect(all.first.note, equals('Dokja favorite phrase'));
      expect(all.first.colorHex, equals('#06B6D4'));

      await storage.deleteHighlight('hl_test_1');
      expect(storage.loadAllHighlights().isEmpty, isTrue);
    });

    test('StorageService tracks manual past reading with pages', () async {
      final storage = await StorageService.initialize();

      await storage.addManualPastReading(
        additionalSeconds: 3600,
        additionalWords: 15000,
        additionalVolumes: 1,
        additionalPages: 350,
      );

      final state = storage.loadOrvState();
      expect(state.manualPastSeconds, equals(3600));
      expect(state.manualPastWords, equals(15000));
      expect(state.manualPastVolumes, equals(1));
      expect(state.manualPastPages, equals(350));
    });

    test('OrvService blank slate initial state, 10x pricing, and progression reset', () async {
      final storage = await StorageService.initialize();
      final orv = OrvService(storage);

      // Check initial state is a true blank slate
      var state = storage.loadOrvState();
      expect(state.coins, equals(0));
      expect(state.incarnationName, equals('Unnamed Incarnation'));
      expect(state.constellationModifier, isEmpty);
      expect(state.equippedFable, isEmpty);
      expect(state.equippedAttribute, isEmpty);
      expect(state.unlockedModifiers, isEmpty);
      expect(state.unlockedAttributes, isEmpty);
      expect(state.acquiredFables, isEmpty);

      // Set custom incarnation name
      await orv.setIncarnationName('Kim Dokja');
      state = storage.loadOrvState();
      expect(state.incarnationName, equals('Kim Dokja'));

      // Give 50,000 coins for unlocking tests
      await storage.saveOrvState(state.copyWith(coins: 50000));

      // Transcendent items cannot be purchased with coins (lore integrity)
      final transcendentFail = await orv.unlockFableWithCoins('Eternity and the Epilogue');
      expect(transcendentFail, isFalse);

      final transModFail = await orv.unlockModifierWithCoins('Demon King of Salvation');
      expect(transModFail, isFalse);

      // Unlock and equip buyable general fable (15,000 coins under 10x scale)
      const fableToUnlock = 'Survivor of the Han River';
      final fableSuccess = await orv.unlockFableWithCoins(fableToUnlock);
      expect(fableSuccess, isTrue);

      final equipFableSuccess = await orv.equipFable(fableToUnlock);
      expect(equipFableSuccess, isTrue);

      // Unlock and equip buyable general attribute (15,000 coins under 10x scale)
      const attrToUnlock = 'Insect Collector';
      final attrSuccess = await orv.unlockAttributeWithCoins(attrToUnlock);
      expect(attrSuccess, isTrue);

      final equipAttrSuccess = await orv.equipAttribute(attrToUnlock);
      expect(equipAttrSuccess, isTrue);

      state = storage.loadOrvState();
      expect(state.equippedFable, equals(fableToUnlock));
      expect(state.equippedAttribute, equals(attrToUnlock));
      expect(state.coins, equals(20000)); // 50,000 - 15,000 - 15,000
      expect(OrvService.allCanonFables.contains(fableToUnlock), isTrue);
      expect(OrvService.allCanonAttributes.contains(attrToUnlock), isTrue);

      // Test resetOrvStateToBlankSlate
      await storage.resetOrvStateToBlankSlate(incarnationName: 'Dusk Reader');
      state = storage.loadOrvState();
      expect(state.coins, equals(0));
      expect(state.incarnationName, equals('Dusk Reader'));
      expect(state.unlockedModifiers, isEmpty);
      expect(state.unlockedAttributes, isEmpty);
      expect(state.acquiredFables, isEmpty);
      expect(state.equippedFable, isEmpty);
      expect(state.equippedAttribute, isEmpty);
    });

    test('ReaderConfig supports useOriginalBookStyles', () {
      const config = ReaderConfig(useOriginalBookStyles: true);
      final json = config.toJson();
      final loaded = ReaderConfig.fromJson(json);
      expect(loaded.useOriginalBookStyles, isTrue);
    });

    test('markBookAsFullyRead completes novel and moves to completed shelf', () async {
      final storage = await StorageService.initialize();
      const testBook = BookInfo(
        id: 'book_finish_test',
        title: 'Omniscient Reader v2',
        author: 'Sing Shong',
        filePath: '/test/orv.epub',
        totalChapters: 551,
        lastReadChapterIndex: 10,
        lastReadProgressPercent: 1.8,
      );
      await storage.saveBooks([testBook]);

      await storage.markBookAsFullyRead('book_finish_test');

      final updatedBooks = storage.loadBooks();
      final finished = updatedBooks.firstWhere((b) => b.id == 'book_finish_test');
      expect(finished.lastReadProgressPercent, equals(100.0));
      expect(finished.lastReadChapterIndex, equals(550));
      expect(finished.lastReadTimestamp, isNotNull);

      final shelves = storage.loadShelves();
      final completedShelf = shelves.firstWhere((s) => s.id == 'completed');
      expect(completedShelf.bookIds.contains('book_finish_test'), isTrue);
    });

    test('Book shelves add and remove books accurately', () async {
      final storage = await StorageService.initialize();
      await storage.addBookToShelf('favorites', 'orv_part_1');
      await storage.addBookToShelf('favorites', 'orv_part_2');

      var shelves = storage.loadShelves();
      var favShelf = shelves.firstWhere((s) => s.id == 'favorites');
      expect(favShelf.bookIds, containsAll(['orv_part_1', 'orv_part_2']));

      await storage.removeBookFromShelf('favorites', 'orv_part_1');
      shelves = storage.loadShelves();
      favShelf = shelves.firstWhere((s) => s.id == 'favorites');
      expect(favShelf.bookIds.contains('orv_part_1'), isFalse);
      expect(favShelf.bookIds.contains('orv_part_2'), isTrue);
    });

    test('Daily reading records and current streak calculate accurately', () async {
      final storage = await StorageService.initialize();
      await storage.recordDailyReading(seconds: 1200, words: 4500, completedChapters: 1);

      final currentStreak = storage.getCurrentStreakDays();
      expect(currentStreak, greaterThanOrEqualTo(1));

      final longestStreak = storage.getLongestStreakDays();
      expect(longestStreak, greaterThanOrEqualTo(1));
    });

    test('ORV Service contains 150+ scaled scenarios with prerequisite locks', () async {
      final allScenarios = Scenario.defaultScenarios();
      expect(allScenarios.length, greaterThanOrEqualTo(150));

      // Main scenario 1 is available initially
      final main1 = allScenarios.firstWhere((s) => s.id == 'main_01');
      expect(main1.requiredPrerequisiteScenarioId, isNull);

      // Later scenarios must require prerequisites
      final main2 = allScenarios.firstWhere((s) => s.id == 'main_02');
      expect(main2.requiredPrerequisiteScenarioId, equals('main_01'));

      final epilogueScenario = allScenarios.firstWhere((s) => s.id == 'main_100');
      expect(epilogueScenario.requiredPrerequisiteScenarioId, equals('main_99'));
    });

    test('Archive novel positioning prioritizes last read with secondary added tie-breaker', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final bookA = BookInfo(
        id: 'a',
        title: 'Book A',
        author: 'Author',
        filePath: '/path/a.epub',
        lastReadTimestamp: now - 1000,
        addedTimestamp: now - 5000,
      );
      final bookB = BookInfo(
        id: 'b',
        title: 'Book B',
        author: 'Author',
        filePath: '/path/b.epub',
        lastReadTimestamp: now - 100, // Read more recently than A
        addedTimestamp: now - 10000,
      );
      final bookCUnreadOld = BookInfo(
        id: 'c',
        title: 'Book C',
        author: 'Author',
        filePath: '/path/c.epub',
        lastReadTimestamp: null,
        addedTimestamp: now - 20000,
      );
      final bookDUnreadNew = BookInfo(
        id: 'd',
        title: 'Book D',
        author: 'Author',
        filePath: '/path/d.epub',
        lastReadTimestamp: null,
        addedTimestamp: now - 1000, // Added more recently than C
      );

      final list = [bookCUnreadOld, bookA, bookDUnreadNew, bookB];

      list.sort((x, y) {
        final xRead = x.lastReadTimestamp ?? 0;
        final yRead = y.lastReadTimestamp ?? 0;
        if (yRead != xRead) {
          return yRead.compareTo(xRead);
        }
        final xAdded = x.addedTimestamp ?? 0;
        final yAdded = y.addedTimestamp ?? 0;
        if (yAdded != xAdded) {
          return yAdded.compareTo(xAdded);
        }
        return x.title.toLowerCase().compareTo(y.title.toLowerCase());
      });

      // Expected order:
      // 1. Book B (most recently read)
      // 2. Book A (read earlier)
      // 3. Book D (unread, but imported newly)
      // 4. Book C (unread, imported older)
      expect(list[0].id, equals('b'));
      expect(list[1].id, equals('a'));
      expect(list[2].id, equals('d'));
      expect(list[3].id, equals('c'));
    });
  });
}

