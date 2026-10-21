import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/reader_config.dart';
import '../models/book_info.dart';
import '../models/book_highlight.dart';
import '../models/book_shelf.dart';
import '../models/bookmark.dart';
import '../models/daily_reading_record.dart';
import '../models/orv_state.dart';
import '../models/reading_session.dart';

class StorageService {
  static const String _keyConfig = 'epilogue_config';
  static const String _legacyKeyConfig = 'ani_read_config';
  static const String _keyBooks = 'epilogue_books';
  static const String _legacyKeyBooks = 'ani_read_books';
  static const String _keyLastBookId = 'epilogue_last_book_id';
  static const String _legacyKeyLastBookId = 'ani_read_last_book_id';
  static const String _keyHighlights = 'epilogue_highlights';
  static const String _legacyKeyHighlights = 'ani_read_highlights';
  static const String _keySessions = 'epilogue_reading_sessions';
  static const String _keyDailyRecords = 'epilogue_daily_records';
  static const String _keyShelves = 'epilogue_book_shelves';
  static const String _prefixBookmarks = 'epilogue_bookmarks_';
  static const String _legacyPrefixBookmarks = 'ani_read_bookmarks_';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Configuration ---

  ReaderConfig loadConfig() {
    final raw = _prefs.getString(_keyConfig) ?? _prefs.getString(_legacyKeyConfig);
    if (raw == null || raw.isEmpty) {
      return const ReaderConfig();
    }
    try {
      return ReaderConfig.fromJson(raw);
    } catch (_) {
      return const ReaderConfig();
    }
  }

  Future<bool> saveConfig(ReaderConfig config) async {
    return await _prefs.setString(_keyConfig, config.toJson());
  }

  // --- Library Books & Progress ---

  List<BookInfo> loadBooks() {
    final raw = _prefs.getString(_keyBooks) ?? _prefs.getString(_legacyKeyBooks);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => BookInfo.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveBooks(List<BookInfo> books) async {
    final list = books.map((b) => b.toMap()).toList();
    return await _prefs.setString(_keyBooks, jsonEncode(list));
  }

  Future<void> updateBookProgress({
    required String bookId,
    required int chapterIndex,
    required double progressPercent,
  }) async {
    final books = loadBooks();
    final index = books.indexWhere((b) => b.id == bookId);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (index >= 0) {
      final updated = books[index].copyWith(
        lastReadChapterIndex: chapterIndex,
        lastReadProgressPercent: progressPercent,
        lastReadTimestamp: now,
      );
      books[index] = updated;
    }
    await saveBooks(books);
    await _prefs.setString(_keyLastBookId, bookId);
  }

  BookInfo? getLastReadBook() {
    final books = loadBooks();
    if (books.isEmpty) return null;

    final lastId = _prefs.getString(_keyLastBookId) ?? _prefs.getString(_legacyKeyLastBookId);
    if (lastId != null) {
      try {
        return books.firstWhere((b) => b.id == lastId);
      } catch (_) {}
    }

    // Fallback to book with the most recent lastReadTimestamp
    final readBooks = books.where((b) => (b.lastReadTimestamp ?? 0) > 0).toList();
    if (readBooks.isNotEmpty) {
      readBooks.sort((a, b) => (b.lastReadTimestamp ?? 0).compareTo(a.lastReadTimestamp ?? 0));
      return readBooks.first;
    }

    return null;
  }

  Future<bool> removeBook(String bookId) async {
    final books = loadBooks();
    books.removeWhere((b) => b.id == bookId);
    final lastId = _prefs.getString(_keyLastBookId) ?? _prefs.getString(_legacyKeyLastBookId);
    if (lastId == bookId) {
      await _prefs.remove(_keyLastBookId);
      await _prefs.remove(_legacyKeyLastBookId);
    }
    // Also remove from shelves
    final shelves = loadShelves();
    for (int i = 0; i < shelves.length; i++) {
      if (shelves[i].bookIds.contains(bookId)) {
        final updatedIds = List<String>.from(shelves[i].bookIds)..remove(bookId);
        shelves[i] = shelves[i].copyWith(bookIds: updatedIds);
      }
    }
    await saveShelves(shelves);
    return await saveBooks(books);
  }

  bool isGridView() {
    return _prefs.getBool('library_grid_view') ?? true;
  }

  Future<bool> setGridView(bool value) async {
    return await _prefs.setBool('library_grid_view', value);
  }

  // --- Mark as Read ---

  /// Marks a book as 100% completed, updates chapters and credits words/time
  Future<void> markBookAsFullyRead(String bookId) async {
    final books = loadBooks();
    final index = books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;

    final book = books[index];
    final totalChapters = book.totalChapters > 0 ? book.totalChapters : (book.lastReadChapterIndex + 1);
    final estimatedWords = (book.totalWordsRead > 0 && book.lastReadChapterIndex > 0)
        ? (book.totalWordsRead / (book.lastReadChapterIndex + 1)).round()
        : 3500;
    final remainingChapters = totalChapters - (book.lastReadChapterIndex + 1);
    final additionalWords = remainingChapters > 0 ? remainingChapters * estimatedWords : 0;
    final additionalSeconds = ((additionalWords / 220.0) * 60).round();

    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedBook = book.copyWith(
      lastReadChapterIndex: totalChapters - 1,
      lastReadProgressPercent: 100.0,
      lastReadTimestamp: now,
      totalWordsRead: book.totalWordsRead + additionalWords,
      totalSecondsSpentReading: book.totalSecondsSpentReading + additionalSeconds,
    );
    books[index] = updatedBook;
    await saveBooks(books);

    // Record session and daily record
    if (additionalSeconds > 0 || additionalWords > 0) {
      await recordDailyReading(
        seconds: additionalSeconds,
        words: additionalWords,
        completedChapters: remainingChapters > 0 ? remainingChapters : 1,
      );
    }

    // Move to completed shelf
    await addBookToShelf('completed', bookId);
  }

  // --- Bookmarks ---

  List<Bookmark> loadBookmarks(String bookId) {
    final key = '$_prefixBookmarks$bookId';
    final legacyKey = '$_legacyPrefixBookmarks$bookId';
    final raw = _prefs.getString(key) ?? _prefs.getString(legacyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => Bookmark.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> addBookmark(Bookmark bookmark) async {
    final bookmarks = loadBookmarks(bookmark.bookId);
    bookmarks.insert(0, bookmark);
    final key = '$_prefixBookmarks${bookmark.bookId}';
    final list = bookmarks.map((b) => b.toMap()).toList();
    return await _prefs.setString(key, jsonEncode(list));
  }

  Future<bool> deleteBookmark(String bookId, String bookmarkId) async {
    final bookmarks = loadBookmarks(bookId);
    bookmarks.removeWhere((b) => b.id == bookmarkId);
    final key = '$_prefixBookmarks$bookId';
    final legacyKey = '$_legacyPrefixBookmarks$bookId';
    final list = bookmarks.map((b) => b.toMap()).toList();
    await _prefs.remove(legacyKey);
    return await _prefs.setString(key, jsonEncode(list));
  }

  List<Bookmark> loadAllBookmarks() {
    final all = <Bookmark>[];
    for (final book in loadBooks()) {
      all.addAll(loadBookmarks(book.id));
    }
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  // --- Highlights & Notes ---

  List<BookHighlight> loadAllHighlights() {
    final raw = _prefs.getString(_keyHighlights) ?? _prefs.getString(_legacyKeyHighlights);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => BookHighlight.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  List<BookHighlight> loadHighlightsForBook(String bookId) {
    return loadAllHighlights().where((h) => h.bookId == bookId).toList();
  }

  Future<bool> saveHighlight(BookHighlight highlight) async {
    final list = loadAllHighlights();
    final idx = list.indexWhere((h) => h.id == highlight.id);
    if (idx >= 0) {
      list[idx] = highlight;
    } else {
      list.insert(0, highlight);
    }
    return await _prefs.setString(_keyHighlights, jsonEncode(list.map((h) => h.toMap()).toList()));
  }

  Future<bool> deleteHighlight(String highlightId) async {
    final list = loadAllHighlights();
    list.removeWhere((h) => h.id == highlightId);
    return await _prefs.setString(_keyHighlights, jsonEncode(list.map((h) => h.toMap()).toList()));
  }

  // --- Reading Sessions & Telemetry ---

  List<ReadingSession> loadRecentSessions({int limit = 50}) {
    final raw = _prefs.getString(_keySessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      final sessions = list.map((e) => ReadingSession.fromMap(e as Map<String, dynamic>)).toList();
      sessions.sort((a, b) => b.startTimeMillis.compareTo(a.startTimeMillis));
      return sessions.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveReadingSession(ReadingSession session) async {
    final sessions = loadRecentSessions(limit: 200);
    sessions.insert(0, session);
    await _prefs.setString(_keySessions, jsonEncode(sessions.map((s) => s.toMap()).toList()));

    await recordDailyReading(
      seconds: session.durationSeconds,
      words: session.wordsRead,
      completedChapters: 0,
    );
  }

  // --- Daily Reading Records & Streaks ---

  String _formatTodayDateKey() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Map<String, DailyReadingRecord> loadDailyRecords() {
    final raw = _prefs.getString(_keyDailyRecords);
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> map = jsonDecode(raw);
      return map.map((key, val) => MapEntry(key, DailyReadingRecord.fromMap(val as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> recordDailyReading({
    required int seconds,
    required int words,
    int completedChapters = 0,
  }) async {
    if (seconds <= 0 && words <= 0 && completedChapters <= 0) return;
    final records = loadDailyRecords();
    final todayKey = _formatTodayDateKey();

    final current = records[todayKey] ?? DailyReadingRecord(dateKey: todayKey, totalSeconds: 0, totalWords: 0);
    final updated = current.copyWith(
      totalSeconds: current.totalSeconds + seconds,
      totalWords: current.totalWords + words,
      chaptersCompleted: current.chaptersCompleted + completedChapters,
    );
    records[todayKey] = updated;

    final map = records.map((key, val) => MapEntry(key, val.toMap()));
    await _prefs.setString(_keyDailyRecords, jsonEncode(map));
  }

  DailyReadingRecord getTodayStats() {
    final records = loadDailyRecords();
    return records[_formatTodayDateKey()] ?? DailyReadingRecord(dateKey: _formatTodayDateKey(), totalSeconds: 0, totalWords: 0);
  }

  int getCurrentStreakDays() {
    final records = loadDailyRecords();
    if (records.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = DateTime.now();

    final todayKey = "${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
    final todayRec = records[todayKey];
    if (todayRec != null && (todayRec.totalSeconds > 60 || todayRec.totalWords > 50)) {
      streak++;
    }

    while (true) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      final dateKey = "${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      final rec = records[dateKey];
      if (rec != null && (rec.totalSeconds > 60 || rec.totalWords > 50)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int getLongestStreakDays() {
    final records = loadDailyRecords();
    if (records.isEmpty) return 0;

    final sortedDates = records.keys.toList()..sort();
    int longest = 0;
    int current = 0;
    DateTime? prev;

    for (final key in sortedDates) {
      final parts = key.split('-').map(int.parse).toList();
      final dt = DateTime(parts[0], parts[1], parts[2]);

      final rec = records[key]!;
      if (rec.totalSeconds > 60 || rec.totalWords > 50) {
        if (prev != null && dt.difference(prev).inDays == 1) {
          current++;
        } else {
          current = 1;
        }
        if (current > longest) longest = current;
        prev = dt;
      }
    }
    return longest;
  }

  /// Checks if yesterday was missed, breaking the consecutive streak.
  bool isStreakBroken() {
    final records = loadDailyRecords();
    if (records.isEmpty) return true;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey = "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
    final rec = records[yesterdayKey];
    return rec == null || (rec.totalSeconds <= 60 && rec.totalWords <= 50);
  }

  /// Imports past consecutive reading streak days by generating daily records for the past N days.
  Future<void> importPastStreakDays(int days) async {
    if (days <= 0) return;
    final records = loadDailyRecords();
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      if (!records.containsKey(dateKey) || (records[dateKey]!.totalSeconds < 120 && records[dateKey]!.totalWords < 100)) {
        records[dateKey] = DailyReadingRecord(
          dateKey: dateKey,
          totalSeconds: 1800,
          totalWords: 1500,
        );
      }
    }
    final map = records.map((key, val) => MapEntry(key, val.toMap()));
    await _prefs.setString(_keyDailyRecords, jsonEncode(map));
  }

  /// Restores a broken streak by backfilling yesterday's reading record with qualifying reading stats.
  Future<bool> restoreBrokenStreak() async {
    final records = loadDailyRecords();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey = "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    final existing = records[yesterdayKey];
    final addedSeconds = (existing?.totalSeconds ?? 0) < 1800 ? 1800 : existing!.totalSeconds;
    final addedWords = (existing?.totalWords ?? 0) < 1000 ? 1000 : existing!.totalWords;

    records[yesterdayKey] = DailyReadingRecord(
      dateKey: yesterdayKey,
      totalSeconds: addedSeconds,
      totalWords: addedWords,
    );

    final todayKey = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final todayRec = records[todayKey];
    records[todayKey] = DailyReadingRecord(
      dateKey: todayKey,
      totalSeconds: (todayRec?.totalSeconds ?? 0) < 600 ? 600 : todayRec!.totalSeconds,
      totalWords: (todayRec?.totalWords ?? 0) < 500 ? 500 : todayRec!.totalWords,
    );

    final map = records.map((key, val) => MapEntry(key, val.toMap()));
    await _prefs.setString(_keyDailyRecords, jsonEncode(map));
    return true;
  }

  // --- Reading Session Telemetry ---

  Future<void> addReadingSessionTime({
    required String bookId,
    required int seconds,
    required int wordsRead,
  }) async {
    if (seconds <= 0 && wordsRead <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final books = loadBooks();
    final index = books.indexWhere((b) => b.id == bookId);
    if (index >= 0) {
      final book = books[index];
      books[index] = book.copyWith(
        totalSecondsSpentReading: book.totalSecondsSpentReading + seconds,
        totalWordsRead: book.totalWordsRead + wordsRead,
        lastReadTimestamp: now,
      );
      await saveBooks(books);
      await _prefs.setString(_keyLastBookId, bookId);
    }
    await recordDailyReading(seconds: seconds, words: wordsRead);
  }

  int getTotalLibraryReadingSeconds() {
    return loadBooks().fold(0, (sum, b) => sum + b.totalSecondsSpentReading);
  }

  int getTotalLibraryWordsRead() {
    return loadBooks().fold(0, (sum, b) => sum + b.totalWordsRead);
  }

  int getAverageReadingWpm() {
    final totalSeconds = getTotalLibraryReadingSeconds() + loadOrvState().manualPastSeconds;
    final totalWords = getTotalLibraryWordsRead() + loadOrvState().manualPastWords;
    if (totalSeconds < 60 || totalWords < 50) return 220;
    return (totalWords / (totalSeconds / 60.0)).round().clamp(50, 999);
  }

  int getTotalLibraryPagesRead() {
    final pagesFromWords = (getTotalLibraryWordsRead() / 300).round();
    return pagesFromWords + loadOrvState().manualPastPages;
  }

  Future<void> batchMarkChaptersRead({
    required String bookId,
    required int targetChapterIndex,
    required int estimatedWordsPerChapter,
  }) async {
    final books = loadBooks();
    final index = books.indexWhere((b) => b.id == bookId);
    if (index >= 0) {
      final book = books[index];
      final chaptersCount = targetChapterIndex + 1;
      final addedWords = chaptersCount * estimatedWordsPerChapter;
      final addedSeconds = ((addedWords / 220.0) * 60).round();

      final totalChapters = book.totalChapters > 0 ? book.totalChapters : chaptersCount;
      final progressPercent = ((chaptersCount / totalChapters) * 100).clamp(0.0, 100.0);

      books[index] = book.copyWith(
        lastReadChapterIndex: targetChapterIndex,
        lastReadProgressPercent: progressPercent,
        totalWordsRead: book.totalWordsRead + addedWords,
        totalSecondsSpentReading: book.totalSecondsSpentReading + addedSeconds,
        lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await saveBooks(books);

      await recordDailyReading(
        seconds: addedSeconds,
        words: addedWords,
        completedChapters: chaptersCount,
      );
    }
  }

  // --- Shelves & Collections ---

  List<BookShelf> loadShelves() {
    final raw = _prefs.getString(_keyShelves);
    if (raw == null || raw.isEmpty) {
      return List<BookShelf>.from(BookShelf.defaultShelves());
    }
    try {
      final List<dynamic> list = jsonDecode(raw);
      final loaded = list.map((e) => BookShelf.fromMap(e as Map<String, dynamic>)).toList();
      for (final def in BookShelf.defaultShelves()) {
        if (!loaded.any((s) => s.id == def.id)) {
          loaded.add(def);
        }
      }
      return loaded;
    } catch (_) {
      return List<BookShelf>.from(BookShelf.defaultShelves());
    }
  }

  Future<bool> saveShelves(List<BookShelf> shelves) async {
    final list = shelves.map((s) => s.toMap()).toList();
    return await _prefs.setString(_keyShelves, jsonEncode(list));
  }

  Future<void> addBookToShelf(String shelfId, String bookId) async {
    final shelves = List<BookShelf>.from(loadShelves());
    final idx = shelves.indexWhere((s) => s.id == shelfId);
    if (idx >= 0) {
      if (!shelves[idx].bookIds.contains(bookId)) {
        final updatedIds = List<String>.from(shelves[idx].bookIds)..add(bookId);
        shelves[idx] = shelves[idx].copyWith(bookIds: updatedIds);
        await saveShelves(shelves);
      }
    }
  }

  Future<void> removeBookFromShelf(String shelfId, String bookId) async {
    final shelves = List<BookShelf>.from(loadShelves());
    final idx = shelves.indexWhere((s) => s.id == shelfId);
    if (idx >= 0) {
      if (shelves[idx].bookIds.contains(bookId)) {
        final updatedIds = List<String>.from(shelves[idx].bookIds)..remove(bookId);
        shelves[idx] = shelves[idx].copyWith(bookIds: updatedIds);
        await saveShelves(shelves);
      }
    }
  }

  List<String> getShelvesForBook(String bookId) {
    return loadShelves().where((s) => s.bookIds.contains(bookId)).map((s) => s.id).toList();
  }

  // --- ORV / Star Stream Progression ---

  static const String _keyOrvState = 'orv_system_state';

  OrvState loadOrvState() {
    final raw = _prefs.getString(_keyOrvState);
    if (raw == null || raw.isEmpty) return const OrvState();
    try {
      final state = OrvState.fromJson(raw);
      // Legacy sanitizer: enforce true blank slate on existing installs that had hardcoded defaults
      if (state.completedScenarioIds.isEmpty &&
          (state.unlockedModifiers.contains('Demon King of Salvation') ||
           state.unlockedAttributes.contains('King of a Kingless World') ||
           state.acquiredFables.contains('One Who Began the Journey'))) {
        final sanitized = state.copyWith(
          coins: state.coins > 10000 ? 0 : state.coins,
          constellationModifier: '',
          unlockedModifiers: const [],
          unlockedAttributes: const [],
          acquiredFables: const [],
          equippedFable: '',
          equippedAttribute: '',
        );
        saveOrvState(sanitized);
        return sanitized;
      }
      return state;
    } catch (_) {
      return const OrvState();
    }
  }

  Future<bool> saveOrvState(OrvState state) async {
    return await _prefs.setString(_keyOrvState, state.toJson());
  }

  Future<void> resetOrvStateToBlankSlate({String? incarnationName}) async {
    final current = loadOrvState();
    final blank = OrvState(
      incarnationName: incarnationName ?? (current.incarnationName.isNotEmpty ? current.incarnationName : 'Unnamed Incarnation'),
      coins: 0,
      constellationModifier: '',
      unlockedModifiers: const [],
      completedScenarioIds: const [],
      acquiredFables: const [],
      equippedFable: '',
      equippedAttribute: '',
      unlockedAttributes: const [],
      customAvatarPath: current.customAvatarPath,
      presetAvatarId: current.presetAvatarId,
      manualPastSeconds: 0,
      manualPastWords: 0,
      manualPastVolumes: 0,
      manualPastPages: 0,
    );
    await saveOrvState(blank);
  }

  Future<void> addManualPastReading({
    required int additionalSeconds,
    required int additionalWords,
    required int additionalVolumes,
    int additionalPages = 0,
  }) async {
    final current = loadOrvState();
    final updated = current.copyWith(
      manualPastSeconds: current.manualPastSeconds + additionalSeconds,
      manualPastWords: current.manualPastWords + additionalWords,
      manualPastVolumes: current.manualPastVolumes + additionalVolumes,
      manualPastPages: current.manualPastPages + additionalPages,
    );
    await saveOrvState(updated);
  }
}
