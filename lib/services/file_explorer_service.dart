import 'dart:io';
import '../models/book_info.dart';
import 'epub_parser_service.dart';
import 'storage_service.dart';

class FileExplorerService {
  final StorageService storageService;

  FileExplorerService(this.storageService);

  static const String rootStoragePath = '/storage/emulated/0';

  static Map<String, String> getQuickDirectories() {
    return {
      'Manga': '$rootStoragePath/Documents/Manga',
      'Archives': '$rootStoragePath/Documents/archives',
      'Documents': '$rootStoragePath/Documents',
      'Downloads': '$rootStoragePath/Download',
      'Books': '$rootStoragePath/Books',
      'Root': rootStoragePath,
    };
  }

  /// Lists entries in [directoryPath] sorted with directories first, then EPUBs, then others
  Future<List<FileSystemEntity>> listDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    try {
      final list = await dir.list(followLinks: false).toList();
      list.sort((a, b) {
        final isDirA = a is Directory;
        final isDirB = b is Directory;
        if (isDirA && !isDirB) return -1;
        if (!isDirA && isDirB) return 1;

        final isEpubA = a.path.toLowerCase().endsWith('.epub');
        final isEpubB = b.path.toLowerCase().endsWith('.epub');
        if (isEpubA && !isEpubB) return -1;
        if (!isEpubA && isEpubB) return 1;

        return a.uri.pathSegments.last.toLowerCase().compareTo(b.uri.pathSegments.last.toLowerCase());
      });
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Automated folder sync: scans [directoryPath] for .epub files and imports new ones
  Future<int> syncLibraryFolder(String directoryPath, {bool recursive = true}) async {
    return await importFolderEpubs(directoryPath, recursive: recursive);
  }

  /// Scans [directoryPath] recursively or non-recursively for .epub files and imports them
  Future<int> importFolderEpubs(String directoryPath, {bool recursive = true}) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return 0;

    final existing = {for (final b in storageService.loadBooks()) b.id: b};
    final updated = List<BookInfo>.from(storageService.loadBooks());
    int importedCount = 0;

    try {
      final stream = dir.list(recursive: recursive, followLinks: false);
      await for (final entity in stream) {
        if (entity is File && entity.path.toLowerCase().endsWith('.epub')) {
          if (!existing.containsKey(entity.path)) {
            try {
              final parsed = await EpubParserService.parseMetadata(entity.path);
              updated.add(parsed);
              existing[entity.path] = parsed;
              importedCount++;
            } catch (_) {
              final name = entity.uri.pathSegments.last.replaceAll('.epub', '');
              final fallback = BookInfo(
                id: entity.path,
                title: name,
                author: 'Unknown',
                filePath: entity.path,
                fileSizeBytes: await entity.length(),
                totalChapters: 0,
                addedTimestamp: DateTime.now().millisecondsSinceEpoch,
              );
              updated.add(fallback);
              existing[entity.path] = fallback;
              importedCount++;
            }
          }
        }
      }
    } catch (_) {}

    if (importedCount > 0) {
      await storageService.saveBooks(updated);
    }
    return importedCount;
  }

  /// Imports a single EPUB file directly
  Future<BookInfo> importSingleEpub(String filePath) async {
    final existing = {for (final b in storageService.loadBooks()) b.id: b};
    if (existing.containsKey(filePath)) {
      return existing[filePath]!;
    }

    BookInfo book;
    try {
      book = await EpubParserService.parseMetadata(filePath);
    } catch (_) {
      final file = File(filePath);
      final name = file.uri.pathSegments.last.replaceAll('.epub', '');
      book = BookInfo(
        id: filePath,
        title: name,
        author: 'Unknown',
        filePath: filePath,
        fileSizeBytes: await file.length(),
        totalChapters: 0,
        addedTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final updated = List<BookInfo>.from(storageService.loadBooks())..add(book);
    await storageService.saveBooks(updated);
    return book;
  }
}
