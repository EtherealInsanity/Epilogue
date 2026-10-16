import 'dart:io';

class OpdsEntry {
  final String id;
  final String title;
  final String author;
  final String summary;
  final String? coverUrl;
  final String? epubDownloadUrl;
  final String? catalogUrl; // For navigation links
  final bool isDirectory;

  const OpdsEntry({
    required this.id,
    required this.title,
    required this.author,
    this.summary = '',
    this.coverUrl,
    this.epubDownloadUrl,
    this.catalogUrl,
    this.isDirectory = false,
  });
}

class OpdsServerProfile {
  final String id;
  final String name;
  final String url;
  final String? username;
  final String? password;

  const OpdsServerProfile({
    required this.id,
    required this.name,
    required this.url,
    this.username,
    this.password,
  });
}

class OpdsService {
  static List<OpdsServerProfile> defaultProfiles() {
    return const [
      OpdsServerProfile(
        id: 'standard_ebooks',
        name: 'Standard Ebooks',
        url: 'https://standardebooks.org/opds/all',
      ),
      OpdsServerProfile(
        id: 'feedbooks',
        name: 'Feedbooks Public Domain',
        url: 'https://www.feedbooks.com/publicdomain/catalog.atom',
      ),
    ];
  }

  /// Parses an Atom/OPDS XML feed into structured [OpdsEntry] models
  static Future<List<OpdsEntry>> fetchCatalog(
    String url, {
    String? username,
    String? password,
  }) async {
    try {
      final client = HttpClient();
      client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);

      if (username != null && username.isNotEmpty) {
        final auth = 'Basic ${username.trim()}:${password?.trim() ?? ''}';
        request.headers.set('Authorization', auth);
      }

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close();
        return [];
      }

      final xml = await response.transform(const SystemEncoding().decoder).join();
      client.close();

      return parseOpdsXml(xml, baseUrl: url);
    } catch (_) {
      return [];
    }
  }

  /// Lightweight zero-dependency regex-based OPDS XML parser
  static List<OpdsEntry> parseOpdsXml(String xml, {required String baseUrl}) {
    final entries = <OpdsEntry>[];
    final entryRegex = RegExp(r'<entry[^>]*>([\s\S]*?)<\/entry>', caseSensitive: false);
    final titleRegex = RegExp(r'<title[^>]*>([\s\S]*?)<\/title>', caseSensitive: false);
    final authorRegex = RegExp(r'<author[^>]*>[\s\S]*?<name[^>]*>([\s\S]*?)<\/name>[\s\S]*?<\/author>', caseSensitive: false);
    final summaryRegex = RegExp(r'<(summary|content)[^>]*>([\s\S]*?)<\/\1>', caseSensitive: false);
    final linkRegex = RegExp(r'<link\s+([^>]+)\/?>', caseSensitive: false);

    final baseUri = Uri.parse(baseUrl);

    for (final match in entryRegex.allMatches(xml)) {
      final chunk = match.group(1)!;

      final titleMatch = titleRegex.firstMatch(chunk);
      final title = titleMatch != null ? _cleanXmlText(titleMatch.group(1)!) : 'Untitled';

      final authorMatch = authorRegex.firstMatch(chunk);
      final author = authorMatch != null ? _cleanXmlText(authorMatch.group(1)!) : 'Unknown Author';

      final summaryMatch = summaryRegex.firstMatch(chunk);
      final summary = summaryMatch != null ? _cleanXmlText(summaryMatch.group(2)!) : '';

      String? coverUrl;
      String? epubUrl;
      String? catalogUrl;
      bool isDir = false;

      for (final linkMatch in linkRegex.allMatches(chunk)) {
        final attrs = linkMatch.group(1)!;
        final href = _extractAttribute(attrs, 'href');
        final rel = _extractAttribute(attrs, 'rel');
        final type = _extractAttribute(attrs, 'type');

        if (href == null || href.isEmpty) continue;
        final resolvedUrl = baseUri.resolve(href).toString();

        if (type != null && (type.contains('application/epub+zip') || href.toLowerCase().endsWith('.epub'))) {
          epubUrl = resolvedUrl;
        } else if (rel != null && (rel.contains('image') || rel.contains('thumbnail')) || (type != null && type.startsWith('image/'))) {
          coverUrl = resolvedUrl;
        } else if (type != null && (type.contains('atom+xml') || type.contains('opds'))) {
          catalogUrl = resolvedUrl;
          isDir = true;
        }
      }

      entries.add(OpdsEntry(
        id: title + author,
        title: title,
        author: author,
        summary: summary,
        coverUrl: coverUrl,
        epubDownloadUrl: epubUrl,
        catalogUrl: catalogUrl,
        isDirectory: isDir && epubUrl == null,
      ));
    }

    return entries;
  }

  static String _cleanXmlText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  static String? _extractAttribute(String tagAttributes, String attrName) {
    final reg = RegExp('$attrName=["\x27]([^"\x27]+)["\x27]', caseSensitive: false);
    return reg.firstMatch(tagAttributes)?.group(1);
  }

  /// Downloads an EPUB directly from a URL into the destination folder
  static Future<File?> downloadEpub({
    required String downloadUrl,
    required String targetFolderPath,
    String? customFilename,
  }) async {
    try {
      final client = HttpClient();
      client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

      final uri = Uri.parse(downloadUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close();
        return null;
      }

      String filename = customFilename ?? uri.pathSegments.last;
      if (!filename.toLowerCase().endsWith('.epub')) {
        filename = '$filename.epub';
      }

      final targetDir = Directory(targetFolderPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final file = File('${targetDir.path}/$filename');
      final sink = file.openWrite();
      await response.pipe(sink);
      client.close();

      return file;
    } catch (_) {
      return null;
    }
  }
}
