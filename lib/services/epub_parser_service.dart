import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:epubx/epubx.dart' as epubx;
import 'package:path_provider/path_provider.dart';
import '../models/book_info.dart';
import '../models/chapter.dart';

class GrepMatch {
  final int chapterIndex;
  final String chapterTitle;
  final int lineNumber;
  final String lineText;
  final int matchStartIndex;
  final int matchEndIndex;

  const GrepMatch({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.lineNumber,
    required this.lineText,
    required this.matchStartIndex,
    required this.matchEndIndex,
  });
}

class ChapterRefMeta {
  final int index;
  final String title;
  final String? href;
  final int estimatedWordCount;

  const ChapterRefMeta({
    required this.index,
    required this.title,
    this.href,
    this.estimatedWordCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'title': title,
        'href': href,
        'estimatedWordCount': estimatedWordCount,
      };

  factory ChapterRefMeta.fromMap(Map<String, dynamic> map) => ChapterRefMeta(
        index: (map['index'] as num?)?.toInt() ?? 0,
        title: map['title'] as String? ?? 'Chapter',
        href: map['href'] as String?,
        estimatedWordCount: (map['estimatedWordCount'] as num?)?.toInt() ?? 0,
      );
}

class BookIndexInfo {
  final String filePath;
  final String title;
  final String author;
  final int totalChapters;
  final List<ChapterRefMeta> chapterMetas;
  final String? coverPath;

  const BookIndexInfo({
    required this.filePath,
    required this.title,
    required this.author,
    required this.totalChapters,
    required this.chapterMetas,
    this.coverPath,
  });

  Map<String, dynamic> toMap() => {
        'filePath': filePath,
        'title': title,
        'author': author,
        'totalChapters': totalChapters,
        'chapterMetas': chapterMetas.map((c) => c.toMap()).toList(),
        'coverPath': coverPath,
      };

  factory BookIndexInfo.fromMap(Map<String, dynamic> map) => BookIndexInfo(
        filePath: map['filePath'] as String? ?? '',
        title: map['title'] as String? ?? 'Untitled',
        author: map['author'] as String? ?? 'Unknown Author',
        totalChapters: (map['totalChapters'] as num?)?.toInt() ?? 0,
        chapterMetas: (map['chapterMetas'] as List<dynamic>?)
                ?.map((c) => ChapterRefMeta.fromMap(c as Map<String, dynamic>))
                .toList() ??
            [],
        coverPath: map['coverPath'] as String?,
      );

  String toJson() => jsonEncode(toMap());
  factory BookIndexInfo.fromJson(String source) =>
      BookIndexInfo.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

// Top-level regexes for high performance and isolate isolation
final RegExp _scriptRegex = RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false);
final RegExp _styleRegex = RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false);
final RegExp _brRegex = RegExp(r'<br\s*\/?>', caseSensitive: false);
final RegExp _blockCloseRegex = RegExp(r'<\/(p|div|h[1-6]|li|blockquote|tr)>', caseSensitive: false);
final RegExp _blockOpenRegex = RegExp(r'<(p|div|h[1-6]|li|blockquote|tr)[^>]*>', caseSensitive: false);
final RegExp _tagStripRegex = RegExp(r'<[^>]+>');
final RegExp _imgRegex = RegExp(r'<img[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false);
final RegExp _styleTagRegex = RegExp(r'<style[^>]*>([\s\S]*?)<\/style>', caseSensitive: false);

/// Top-level function for isolate text cleanup
String _computeHtmlToPlainText(String html) {
  if (html.isEmpty) return '';
  String text = html;
  text = text.replaceAll(_scriptRegex, '');
  text = text.replaceAll(_styleRegex, '');
  text = text.replaceAll(_brRegex, '\n');
  text = text.replaceAll(_blockCloseRegex, '\n\n');
  text = text.replaceAll(_blockOpenRegex, '');
  text = text.replaceAll(_tagStripRegex, '');
  text = EpubParserService.decodeHtmlEntities(text);

  final lines = text.split('\n');
  final cleanedLines = <String>[];
  int consecutiveEmptyLines = 0;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      consecutiveEmptyLines++;
      if (consecutiveEmptyLines <= 1) {
        cleanedLines.add('');
      }
    } else {
      consecutiveEmptyLines = 0;
      cleanedLines.add(trimmed);
    }
  }

  return cleanedLines.join('\n').trim();
}

class EpubParserService {
  // In-memory LRU and cache structures
  static final Map<String, BookIndexInfo> _cachedBookIndexes = {};
  static final Map<String, Map<int, Chapter>> _cachedChapterWindow = {};
  static final Map<String, Map<String, String>> _cachedImagesMap = {};
  static final Map<String, String> _cachedCss = {};
  static final Map<String, List<Chapter>> _cachedChapters = {};
  static final Map<String, epubx.EpubBookRef> _openBookRefCache = {};

  /// Fast-indexes an EPUB using disk caching. Reopening is near-instant (< 50ms).
  static Future<BookIndexInfo> parseAndCacheBookIndex(String filePath) async {
    if (_cachedBookIndexes.containsKey(filePath)) {
      return _cachedBookIndexes[filePath]!;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('EPUB file not found', filePath);
    }

    // 1. Check persistent disk cache
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/epub_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/${filePath.hashCode}.idx.json');
      if (await cacheFile.exists()) {
        final cacheStat = await cacheFile.stat();
        final fileStat = await file.stat();
        // Valid if cache is newer than epub modification
        if (cacheStat.modified.isAfter(fileStat.modified)) {
          final content = await cacheFile.readAsString();
          final indexInfo = BookIndexInfo.fromJson(content);
          _cachedBookIndexes[filePath] = indexInfo;
          return indexInfo;
        }
      }
    } catch (_) {}

    // 2. Parse EPUB metadata and chapters structure lazily
    final bytes = await file.readAsBytes();
    final bookRef = await epubx.EpubReader.openBook(bytes);
    _openBookRefCache[filePath] = bookRef;

    final title = (bookRef.Title != null && bookRef.Title!.trim().isNotEmpty)
        ? bookRef.Title!.trim()
        : file.uri.pathSegments.last.replaceAll('.epub', '');
    final author = (bookRef.Author != null && bookRef.Author!.trim().isNotEmpty)
        ? bookRef.Author!.trim()
        : 'Unknown Author';

    final chapters = await bookRef.getChapters();
    final flattened = <epubx.EpubChapterRef>[];
    _flattenChapterRefs(chapters, flattened);

    final chapterMetas = <ChapterRefMeta>[];
    for (int i = 0; i < flattened.length; i++) {
      final raw = flattened[i];
      final chTitle = (raw.Title != null && raw.Title!.trim().isNotEmpty)
          ? raw.Title!.trim()
          : 'Chapter ${i + 1}';
      chapterMetas.add(ChapterRefMeta(
        index: i,
        title: chTitle,
        href: raw.ContentFileName,
      ));
    }

    String? coverPath;
    try {
      coverPath = await extractCoverImageFromBookRef(bookRef, filePath);
    } catch (_) {}

    final indexInfo = BookIndexInfo(
      filePath: filePath,
      title: title,
      author: author,
      totalChapters: chapterMetas.length,
      chapterMetas: chapterMetas,
      coverPath: coverPath,
    );

    // Save to disk cache
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${appDir.path}/epub_cache/${filePath.hashCode}.idx.json');
      await cacheFile.writeAsString(indexInfo.toJson());
    } catch (_) {}

    _cachedBookIndexes[filePath] = indexInfo;
    return indexInfo;
  }

  /// Extracts metadata for a book (using the fast index).
  static Future<BookInfo> parseMetadata(String filePath) async {
    final index = await parseAndCacheBookIndex(filePath);
    final file = File(filePath);
    final fileSize = await file.exists() ? await file.length() : 0;

    return BookInfo(
      id: filePath,
      title: index.title,
      author: index.author,
      filePath: filePath,
      fileSizeBytes: fileSize,
      totalChapters: index.totalChapters,
      coverImagePath: index.coverPath,
      addedTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Lazily loads a single chapter by index with memory sliding window.
  static Future<Chapter> loadChapterLazy(String filePath, int chapterIndex) async {
    _cachedChapterWindow[filePath] ??= {};
    final window = _cachedChapterWindow[filePath]!;

    if (window.containsKey(chapterIndex)) {
      return window[chapterIndex]!;
    }

    final indexInfo = await parseAndCacheBookIndex(filePath);
    if (chapterIndex < 0 || chapterIndex >= indexInfo.chapterMetas.length) {
      return Chapter(
        index: chapterIndex,
        title: 'Chapter ${chapterIndex + 1}',
        plainTextContent: '',
        htmlContent: '<p>[End of Novel]</p>',
        wordCount: 0,
      );
    }

    epubx.EpubBookRef? bookRef = _openBookRefCache[filePath];
    if (bookRef == null) {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      bookRef = await epubx.EpubReader.openBook(bytes);
      _openBookRefCache[filePath] = bookRef;
    }

    final rawChapters = await bookRef.getChapters();
    final flattened = <epubx.EpubChapterRef>[];
    _flattenChapterRefs(rawChapters, flattened);

    String html = '';
    if (chapterIndex < flattened.length) {
      try {
        html = await flattened[chapterIndex].readHtmlContent();
      } catch (_) {}
    }

    // Process plain text in isolate if large, or synchronously if small
    final plain = html.length > 20000
        ? await compute(_computeHtmlToPlainText, html)
        : htmlToPlainText(html);

    final imageSrcs = _imgRegex.allMatches(html).map((m) => m.group(1)!).toList();
    final meta = indexInfo.chapterMetas[chapterIndex];

    final chapter = Chapter.fromHtml(
      index: chapterIndex,
      title: meta.title,
      htmlContent: html,
      plainTextContent: plain,
      imageSrcs: imageSrcs,
    );

    // Keep window bounded to 5 chapters to prevent memory leaks on 1,000+ chapter books
    if (window.length > 5) {
      final keysToRemove = window.keys.where((k) => (k - chapterIndex).abs() > 2).toList();
      for (final k in keysToRemove) {
        window.remove(k);
      }
    }

    window[chapterIndex] = chapter;
    return chapter;
  }

  /// Extracts cover image from an opened EpubBookRef into the app documents directory.
  static Future<String?> extractCoverImageFromBookRef(
    epubx.EpubBookRef bookRef,
    String bookFilePath,
  ) async {
    final images = bookRef.Content?.Images;
    if (images == null || images.isEmpty) {
      return null;
    }

    String? coverKey;
    for (final key in images.keys) {
      final lower = key.toLowerCase();
      if (lower.contains('cover')) {
        coverKey = key;
        break;
      }
    }

    coverKey ??= images.keys.firstWhere(
      (k) => k.toLowerCase().endsWith('.jpg') || k.toLowerCase().endsWith('.png') || k.toLowerCase().endsWith('.jpeg'),
      orElse: () => images.keys.first,
    );

    try {
      final imgBytes = await images[coverKey]!.readContentAsBytes();
      if (imgBytes.isEmpty) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final ext = coverKey.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final coverFile = File('${coversDir.path}/${bookFilePath.hashCode}_cover.$ext');
      await coverFile.writeAsBytes(imgBytes);
      return coverFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Extracts cover image directly from a file path.
  static Future<String?> extractCoverImage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final bookRef = await epubx.EpubReader.openBook(bytes);
      return await extractCoverImageFromBookRef(bookRef, filePath);
    } catch (_) {
      return null;
    }
  }

  /// Lazily extracts a single illustration on-demand when rendered on screen.
  static Future<String?> extractImageOnDemand(String filePath, String imageSrc) async {
    final normalized = imageSrc.replaceAll('\\', '/');
    final simpleName = normalized.split('/').last;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${appDir.path}/epub_images/${filePath.hashCode}/$simpleName');
      if (await targetFile.exists()) {
        return targetFile.path;
      }

      final imagesDir = Directory('${appDir.path}/epub_images/${filePath.hashCode}');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      epubx.EpubBookRef? bookRef = _openBookRefCache[filePath];
      if (bookRef == null) {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        bookRef = await epubx.EpubReader.openBook(bytes);
        _openBookRefCache[filePath] = bookRef;
      }

      final images = bookRef.Content?.Images;
      if (images == null || images.isEmpty) return null;

      dynamic fileRef;
      if (images.containsKey(imageSrc)) {
        fileRef = images[imageSrc];
      } else {
        for (final entry in images.entries) {
          if (entry.key.endsWith(simpleName)) {
            fileRef = entry.value;
            break;
          }
        }
      }

      if (fileRef != null) {
        final content = await fileRef.readContentAsBytes() as List<int>;
        if (content.isNotEmpty) {
          await targetFile.writeAsBytes(content);
          return targetFile.path;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Extracts all embedded CSS stylesheets and <style> blocks from the EPUB.
  static Future<String> extractAllBookCss(String filePath) async {
    if (_cachedCss.containsKey(filePath)) {
      return _cachedCss[filePath]!;
    }

    final file = File(filePath);
    if (!await file.exists()) return '';

    final buffer = StringBuffer();
    try {
      final bytes = await file.readAsBytes();
      final bookRef = await epubx.EpubReader.openBook(bytes);

      final cssFiles = bookRef.Content?.Css;
      if (cssFiles != null && cssFiles.isNotEmpty) {
        for (final entry in cssFiles.entries) {
          try {
            final cssText = await entry.value.readContentAsText();
            if (cssText.isNotEmpty) {
              buffer.writeln('/* ${entry.key} */');
              buffer.writeln(cssText);
            }
          } catch (_) {}
        }
      }

      final rawChapters = await bookRef.getChapters();
      final sampleChapters = rawChapters.take(10);
      for (final ch in sampleChapters) {
        try {
          final html = await ch.readHtmlContent();
          final matches = _styleTagRegex.allMatches(html);
          for (final m in matches) {
            final inlineCss = m.group(1)?.trim();
            if (inlineCss != null && inlineCss.isNotEmpty) {
              buffer.writeln(inlineCss);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    final result = buffer.toString().trim();
    _cachedCss[filePath] = result;
    return result;
  }

  /// Extracts all images embedded in the EPUB to local cache directory.
  static Future<Map<String, String>> extractAllBookImages(String filePath) async {
    if (_cachedImagesMap.containsKey(filePath)) {
      return _cachedImagesMap[filePath]!;
    }

    final file = File(filePath);
    if (!await file.exists()) return {};

    final map = <String, String>{};
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/epub_images/${filePath.hashCode}');

      if (await imagesDir.exists()) {
        final existingFiles = imagesDir.listSync().whereType<File>();
        if (existingFiles.isNotEmpty) {
          for (final f in existingFiles) {
            final simpleName = f.uri.pathSegments.last;
            map[simpleName] = f.path;
            map['../images/$simpleName'] = f.path;
            map['images/$simpleName'] = f.path;
            map['../Images/$simpleName'] = f.path;
            map['Images/$simpleName'] = f.path;
          }
          _cachedImagesMap[filePath] = map;
          return map;
        }
      } else {
        await imagesDir.create(recursive: true);
      }

      final bytes = await file.readAsBytes();
      final bookRef = await epubx.EpubReader.openBook(bytes);
      final images = bookRef.Content?.Images;
      if (images == null || images.isEmpty) {
        _cachedImagesMap[filePath] = map;
        return map;
      }

      for (final entry in images.entries) {
        final key = entry.key;
        final simpleName = key.replaceAll('\\', '/').split('/').last;
        final targetFile = File('${imagesDir.path}/$simpleName');
        if (!await targetFile.exists()) {
          try {
            final content = await entry.value.readContentAsBytes();
            if (content.isNotEmpty) {
              await targetFile.writeAsBytes(content);
            }
          } catch (_) {}
        }
        if (await targetFile.exists()) {
          map[key] = targetFile.path;
          map[simpleName] = targetFile.path;
          map['../images/$simpleName'] = targetFile.path;
          map['images/$simpleName'] = targetFile.path;
          map['../Images/$simpleName'] = targetFile.path;
          map['Images/$simpleName'] = targetFile.path;
        }
      }
    } catch (_) {}

    _cachedImagesMap[filePath] = map;
    return map;
  }

  /// Extracts all linear chapters into structured [Chapter] models.
  static Future<List<Chapter>> extractChapters(String filePath) async {
    if (_cachedChapters.containsKey(filePath)) {
      return _cachedChapters[filePath]!;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('EPUB file not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final chapters = await extractChaptersFromBytes(bytes);
    _cachedChapters[filePath] = chapters;
    return chapters;
  }

  /// Extracts chapters directly from byte buffer.
  static Future<List<Chapter>> extractChaptersFromBytes(Uint8List bytes) async {
    final bookRef = await epubx.EpubReader.openBook(bytes);
    final rawChapters = await bookRef.getChapters();
    final flattened = <epubx.EpubChapterRef>[];
    _flattenChapterRefs(rawChapters, flattened);

    final results = <Chapter>[];
    int index = 0;
    for (final raw in flattened) {
      String html = '';
      try {
        html = await raw.readHtmlContent();
      } catch (_) {}

      final plain = htmlToPlainText(html);
      final imageSrcs = _imgRegex.allMatches(html).map((m) => m.group(1)!).toList();

      if (plain.trim().isEmpty && imageSrcs.isEmpty && (raw.SubChapters == null || raw.SubChapters!.isEmpty)) {
        continue;
      }

      String title = (raw.Title != null && raw.Title!.trim().isNotEmpty)
          ? raw.Title!.trim()
          : 'Chapter ${index + 1}';

      results.add(Chapter.fromHtml(
        index: index,
        title: title,
        htmlContent: html,
        plainTextContent: plain,
        imageSrcs: imageSrcs,
      ));
      index++;
    }

    return results;
  }

  static void _flattenChapterRefs(
    List<epubx.EpubChapterRef> source,
    List<epubx.EpubChapterRef> target,
  ) {
    for (final ch in source) {
      target.add(ch);
      if (ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
        _flattenChapterRefs(ch.SubChapters!, target);
      }
    }
  }

  /// Strips HTML tags into clean, human-readable monospace plain text.
  static String htmlToPlainText(String html) => _computeHtmlToPlainText(html);

  /// Decodes HTML entities into literal characters.
  static String decodeHtmlEntities(String input) {
    var out = input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’');

    out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1)!);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });

    out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });

    return out;
  }

  /// Word-wraps text into columns with maximum width.
  static String wrapToColumns(String text, int columnWidth) {
    if (text.isEmpty || columnWidth <= 0) return text;
    final words = text.split(' ');
    final buffer = StringBuffer();
    int currentLineLength = 0;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (currentLineLength == 0) {
        buffer.write(word);
        currentLineLength = word.length;
      } else if (currentLineLength + 1 + word.length <= columnWidth) {
        buffer.write(' $word');
        currentLineLength += 1 + word.length;
      } else {
        buffer.write('\n$word');
        currentLineLength = word.length;
      }
    }
    return buffer.toString();
  }

  /// Grep search across a specific chapter's plain text content.
  static List<GrepMatch> grepChapter({
    required Chapter chapter,
    required String query,
    bool caseSensitive = false,
  }) {
    if (query.isEmpty) return [];

    final matches = <GrepMatch>[];
    final lines = chapter.plainTextContent.split('\n');

    final pattern = RegExp(
      RegExp.escape(query),
      caseSensitive: caseSensitive,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineMatches = pattern.allMatches(line);

      for (final m in lineMatches) {
        matches.add(GrepMatch(
          chapterIndex: chapter.index,
          chapterTitle: chapter.title,
          lineNumber: i + 1,
          lineText: line.trim(),
          matchStartIndex: m.start,
          matchEndIndex: m.end,
        ));
      }
    }

    return matches;
  }
}
