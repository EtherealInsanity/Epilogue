import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/book_info.dart';
import '../models/book_highlight.dart';
import '../models/book_shelf.dart';
import '../models/bookmark.dart';
import '../models/daily_reading_record.dart';
import '../models/orv_state.dart';
import '../models/reading_session.dart';
import 'storage_service.dart';

class DataSyncService {
  final StorageService storageService;

  DataSyncService(this.storageService);

  /// Generates a complete JSON backup snapshot of all app data
  String generateBackupJson() {
    final books = storageService.loadBooks().map((b) => b.toMap()).toList();
    final config = storageService.loadConfig().toMap();
    final orvState = storageService.loadOrvState().toMap();
    final allBookmarks = storageService.loadAllBookmarks().map((b) => b.toMap()).toList();
    final highlights = storageService.loadAllHighlights().map((h) => h.toMap()).toList();
    final shelves = storageService.loadShelves().map((s) => s.toMap()).toList();
    final sessions = storageService.loadRecentSessions(limit: 500).map((s) => s.toMap()).toList();
    final dailyRecords = storageService.loadDailyRecords().map((k, v) => MapEntry(k, v.toMap()));

    final snapshot = {
      'epilogue_version': '2.0.0',
      'exported_at': DateTime.now().millisecondsSinceEpoch,
      'books': books,
      'config': config,
      'orv_state': orvState,
      'bookmarks': allBookmarks,
      'highlights': highlights,
      'shelves': shelves,
      'reading_sessions': sessions,
      'daily_records': dailyRecords,
    };

    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  /// Exports backup JSON directly to device Downloads or Documents folder
  Future<String> exportBackupToFile() async {
    final jsonContent = generateBackupJson();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'epilogue_backup_$timestamp.json';

    Directory? targetDir;
    try {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        targetDir = downloads;
      }
    } catch (_) {}

    targetDir ??= await getApplicationDocumentsDirectory();
    final file = File('${targetDir.path}/$filename');
    await file.writeAsString(jsonContent);
    return file.path;
  }

  /// Imports a backup JSON snapshot with Smart Auto-Merge
  Future<bool> importBackupFromJson(String jsonString, {bool smartMerge = true}) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // 1. Books with Highest Progress Merge
      if (data.containsKey('books') && data['books'] is List) {
        final importedBooks = (data['books'] as List)
            .map((e) => BookInfo.fromMap(e as Map<String, dynamic>))
            .toList();

        if (smartMerge) {
          final currentBooks = storageService.loadBooks();
          final bookMap = {for (final b in currentBooks) b.id: b};

          for (final imp in importedBooks) {
            if (bookMap.containsKey(imp.id)) {
              final cur = bookMap[imp.id]!;
              final maxChapter = imp.lastReadChapterIndex > cur.lastReadChapterIndex
                  ? imp.lastReadChapterIndex
                  : cur.lastReadChapterIndex;
              final maxProgress = imp.lastReadProgressPercent > cur.lastReadProgressPercent
                  ? imp.lastReadProgressPercent
                  : cur.lastReadProgressPercent;
              final maxWords = imp.totalWordsRead > cur.totalWordsRead
                  ? imp.totalWordsRead
                  : cur.totalWordsRead;
              final maxSeconds = imp.totalSecondsSpentReading > cur.totalSecondsSpentReading
                  ? imp.totalSecondsSpentReading
                  : cur.totalSecondsSpentReading;

              bookMap[imp.id] = cur.copyWith(
                lastReadChapterIndex: maxChapter,
                lastReadProgressPercent: maxProgress,
                totalWordsRead: maxWords,
                totalSecondsSpentReading: maxSeconds,
                coverImagePath: cur.coverImagePath ?? imp.coverImagePath,
              );
            } else {
              bookMap[imp.id] = imp;
            }
          }
          await storageService.saveBooks(bookMap.values.toList());
        } else {
          await storageService.saveBooks(importedBooks);
        }
      }

      // 2. ORV State Union Merge
      if (data.containsKey('orv_state') && data['orv_state'] is Map) {
        final importedOrv = OrvState.fromMap(data['orv_state'] as Map<String, dynamic>);
        if (smartMerge) {
          final currentOrv = storageService.loadOrvState();
          final mergedCoins = currentOrv.coins > importedOrv.coins ? currentOrv.coins : importedOrv.coins;
          final mergedScenarios = {...currentOrv.completedScenarioIds, ...importedOrv.completedScenarioIds}.toList();
          final mergedFables = {...currentOrv.acquiredFables, ...importedOrv.acquiredFables}.toList();
          final mergedModifiers = {...currentOrv.unlockedModifiers, ...importedOrv.unlockedModifiers}.toList();
          final mergedAttributes = {...currentOrv.unlockedAttributes, ...importedOrv.unlockedAttributes}.toList();

          final updatedOrv = currentOrv.copyWith(
            coins: mergedCoins,
            completedScenarioIds: mergedScenarios,
            acquiredFables: mergedFables,
            unlockedModifiers: mergedModifiers,
            unlockedAttributes: mergedAttributes,
          );
          await storageService.saveOrvState(updatedOrv);
        } else {
          await storageService.saveOrvState(importedOrv);
        }
      }

      // 3. Bookmarks Union
      if (data.containsKey('bookmarks') && data['bookmarks'] is List) {
        final importedBookmarks = (data['bookmarks'] as List)
            .map((e) => Bookmark.fromMap(e as Map<String, dynamic>))
            .toList();
        final currentBookmarks = storageService.loadAllBookmarks();
        final existingIds = {for (final b in currentBookmarks) b.id};

        for (final bm in importedBookmarks) {
          if (!existingIds.contains(bm.id)) {
            await storageService.addBookmark(bm);
          }
        }
      }

      // 4. Highlights Union
      if (data.containsKey('highlights') && data['highlights'] is List) {
        final importedHighlights = (data['highlights'] as List)
            .map((e) => BookHighlight.fromMap(e as Map<String, dynamic>))
            .toList();
        final currentHighlights = storageService.loadAllHighlights();
        final existingHlIds = {for (final h in currentHighlights) h.id};

        for (final hl in importedHighlights) {
          if (!existingHlIds.contains(hl.id)) {
            await storageService.saveHighlight(hl);
          }
        }
      }

      // 5. Shelves Union
      if (data.containsKey('shelves') && data['shelves'] is List) {
        final importedShelves = (data['shelves'] as List)
            .map((e) => BookShelf.fromMap(e as Map<String, dynamic>))
            .toList();
        final currentShelves = storageService.loadShelves();
        final shelfMap = {for (final s in currentShelves) s.id: s};

        for (final impShelf in importedShelves) {
          if (shelfMap.containsKey(impShelf.id)) {
            final mergedBooks = {...shelfMap[impShelf.id]!.bookIds, ...impShelf.bookIds}.toList();
            shelfMap[impShelf.id] = shelfMap[impShelf.id]!.copyWith(bookIds: mergedBooks);
          } else {
            shelfMap[impShelf.id] = impShelf;
          }
        }
        await storageService.saveShelves(shelfMap.values.toList());
      }

      // 6. Reading Sessions Union
      if (data.containsKey('reading_sessions') && data['reading_sessions'] is List) {
        final importedSessions = (data['reading_sessions'] as List)
            .map((e) => ReadingSession.fromMap(e as Map<String, dynamic>))
            .toList();
        final currentSessions = storageService.loadRecentSessions(limit: 500);
        final existingIds = {for (final s in currentSessions) s.id};
        final merged = List<ReadingSession>.from(currentSessions);
        for (final s in importedSessions) {
          if (!existingIds.contains(s.id)) {
            merged.add(s);
          }
        }
        merged.sort((a, b) => b.startTimeMillis.compareTo(a.startTimeMillis));
        await storageService.saveSessions(merged.take(500).toList());
      }

      // 7. Daily Records Union
      if (data.containsKey('daily_records') && data['daily_records'] is Map) {
        final imported = (data['daily_records'] as Map).map(
          (k, v) => MapEntry(k as String, DailyReadingRecord.fromMap(v as Map<String, dynamic>)),
        );
        if (smartMerge) {
          final current = storageService.loadDailyRecords();
          for (final entry in imported.entries) {
            if (current.containsKey(entry.key)) {
              final cur = current[entry.key]!;
              final maxSec = entry.value.totalSeconds > cur.totalSeconds ? entry.value.totalSeconds : cur.totalSeconds;
              final maxWords = entry.value.totalWords > cur.totalWords ? entry.value.totalWords : cur.totalWords;
              final maxCh = entry.value.chaptersCompleted > cur.chaptersCompleted ? entry.value.chaptersCompleted : cur.chaptersCompleted;
              current[entry.key] = cur.copyWith(totalSeconds: maxSec, totalWords: maxWords, chaptersCompleted: maxCh);
            } else {
              current[entry.key] = entry.value;
            }
          }
          await storageService.saveDailyRecords(current);
        } else {
          await storageService.saveDailyRecords(imported);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Syncs with WebDAV endpoint using native HttpClient
  Future<bool> pushToWebDav({
    required String serverUrl,
    required String username,
    required String password,
    String remoteFileName = 'epilogue_sync.json',
  }) async {
    try {
      final client = HttpClient();

      final uri = Uri.parse(serverUrl.endsWith('/') ? '$serverUrl$remoteFileName' : '$serverUrl/$remoteFileName');
      final request = await client.putUrl(uri);

      if (username.isNotEmpty || password.isNotEmpty) {
        final auth = base64Encode(utf8.encode('$username:$password'));
        request.headers.set('Authorization', 'Basic $auth');
      }

      request.headers.contentType = ContentType.json;
      final payload = generateBackupJson();
      request.write(payload);

      final response = await request.close();
      client.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Pulls backup from WebDAV and merges into local state
  Future<bool> pullFromWebDav({
    required String serverUrl,
    required String username,
    required String password,
    String remoteFileName = 'epilogue_sync.json',
  }) async {
    try {
      final client = HttpClient();

      final uri = Uri.parse(serverUrl.endsWith('/') ? '$serverUrl$remoteFileName' : '$serverUrl/$remoteFileName');
      final request = await client.getUrl(uri);

      if (username.isNotEmpty || password.isNotEmpty) {
        final auth = base64Encode(utf8.encode('$username:$password'));
        request.headers.set('Authorization', 'Basic $auth');
      }

      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final content = await response.transform(utf8.decoder).join();
        client.close();
        return await importBackupFromJson(content, smartMerge: true);
      }
      client.close();
      return false;
    } catch (_) {
      return false;
    }
  }
}
