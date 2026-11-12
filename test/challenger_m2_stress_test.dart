import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilogue/config/reader_config.dart';
import 'package:epilogue/models/book_info.dart';
import 'package:epilogue/models/chapter.dart';
import 'package:epilogue/screens/modern_reader_screen.dart';
import 'package:epilogue/services/epub_parser_service.dart';
import 'package:epilogue/services/storage_service.dart';

// =============================================================================
// Helper: In-memory Zip Archive Creator
// =============================================================================
int _crc32(List<int> data) {
  int crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = (crc ^ byte) & 0xFFFFFFFF;
    for (int i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = ((crc >> 1) ^ 0xEDB88320) & 0xFFFFFFFF;
      } else {
        crc = (crc >> 1) & 0xFFFFFFFF;
      }
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

Uint8List _createZipArchive(Map<String, List<int>> files) {
  final out = BytesBuilder();
  final centralDir = BytesBuilder();
  int offset = 0;

  for (final entry in files.entries) {
    final nameBytes = utf8.encode(entry.key);
    final data = entry.value;
    final crc = _crc32(data);

    final local = ByteData(30);
    local.setUint32(0, 0x04034b50, Endian.little);
    local.setUint16(4, 20, Endian.little);
    local.setUint16(6, 0, Endian.little);
    local.setUint16(8, 0, Endian.little);
    local.setUint16(10, 0, Endian.little);
    local.setUint16(12, 0, Endian.little);
    local.setUint32(14, crc, Endian.little);
    local.setUint32(18, data.length, Endian.little);
    local.setUint32(22, data.length, Endian.little);
    local.setUint16(26, nameBytes.length, Endian.little);
    local.setUint16(28, 0, Endian.little);

    out.add(local.buffer.asUint8List());
    out.add(nameBytes);
    out.add(data);

    final cd = ByteData(46);
    cd.setUint32(0, 0x02014b50, Endian.little);
    cd.setUint16(4, 20, Endian.little);
    cd.setUint16(6, 20, Endian.little);
    cd.setUint16(8, 0, Endian.little);
    cd.setUint16(10, 0, Endian.little);
    cd.setUint16(12, 0, Endian.little);
    cd.setUint16(14, 0, Endian.little);
    cd.setUint32(16, crc, Endian.little);
    cd.setUint32(20, data.length, Endian.little);
    cd.setUint32(24, data.length, Endian.little);
    cd.setUint16(28, nameBytes.length, Endian.little);
    cd.setUint16(30, 0, Endian.little);
    cd.setUint16(32, 0, Endian.little);
    cd.setUint16(34, 0, Endian.little);
    cd.setUint16(36, 0, Endian.little);
    cd.setUint32(38, 0, Endian.little);
    cd.setUint32(42, offset, Endian.little);

    centralDir.add(cd.buffer.asUint8List());
    centralDir.add(nameBytes);

    offset += 30 + nameBytes.length + data.length;
  }

  final cdBytes = centralDir.takeBytes();
  final cdOffset = offset;
  final cdSize = cdBytes.length;

  final eocd = ByteData(22);
  eocd.setUint32(0, 0x06054b50, Endian.little);
  eocd.setUint16(4, 0, Endian.little);
  eocd.setUint16(6, 0, Endian.little);
  eocd.setUint16(8, files.length, Endian.little);
  eocd.setUint16(10, files.length, Endian.little);
  eocd.setUint32(12, cdSize, Endian.little);
  eocd.setUint32(16, cdOffset, Endian.little);
  eocd.setUint16(20, 0, Endian.little);

  out.add(cdBytes);
  out.add(eocd.buffer.asUint8List());

  return out.takeBytes();
}

// 1x1 PNG fixture
final _k1x1Png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

// 1x1 JPG fixture
final _k1x1Jpg = Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x03, 0x03,
  0x03, 0x04, 0x03, 0x03, 0x04, 0x05, 0x08, 0x05, 0x05, 0x04, 0x04, 0x05, 0x0A, 0x07, 0x07, 0x06,
  0x08, 0x0C, 0x0A, 0x0C, 0x0C, 0x0B, 0x0A, 0x0B, 0x0B, 0x0D, 0x0E, 0x12, 0x10, 0x0D, 0x0E, 0x11,
  0x0E, 0x0B, 0x0B, 0x10, 0x16, 0x10, 0x11, 0x13, 0x14, 0x15, 0x15, 0x15, 0x0C, 0x0F, 0x17, 0x18,
  0x16, 0x14, 0x18, 0x12, 0x14, 0x15, 0x14, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01,
  0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01,
  0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
  0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xBF,
  0x80, 0xFF, 0xD9,
]);

// 1x1 WebP fixture
final _k1x1Webp = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0x1A, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x4C,
  0x0E, 0x00, 0x00, 0x00, 0x2F, 0x00, 0x00, 0x00, 0x10, 0x07, 0x10, 0x11, 0x11, 0x88, 0x88, 0xFE,
  0x07, 0x00,
]);

// Standalone SVG vector fixture (pure XML text)
final _kVectorSvg = utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
  <rect width="100" height="100" fill="#3b82f6"/>
  <circle cx="50" cy="50" r="30" fill="#ffffff"/>
</svg>''');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('epilogue_challenger_m2_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Adversarial Challenge 1: Path Resolution Stress Testing', () {
    final mockIndex = <String, String>{
      'OEBPS/images/art.png': '/cache/art.png',
      'art.png': '/cache/art.png',
      'OEBPS/media/COVER.WEBP': '/cache/cover.webp',
      'cover.webp': '/cache/cover.webp',
      'OEBPS/images/UPPER.PNG': '/cache/upper.png',
      'upper.png': '/cache/upper.png',
      'OEBPS/images/scene space.jpg': '/cache/scene_space.jpg',
      'scene space.jpg': '/cache/scene_space.jpg',
      'OEBPS/images/vector.svg': '/cache/vector.svg',
      'vector.svg': '/cache/vector.svg',
    };

    test('1.1 Malformed URIs do not throw uncaught exceptions and resolve when possible', () {
      // Incomplete percent encodings
      expect(() => EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: '%ZZ%GG/art.png',
      ), returnsNormally);

      final resMalformedPercent = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: '%ZZ%GG/art.png',
      );
      // Basename art.png should be extracted and matched
      expect(resMalformedPercent, equals('/cache/art.png'));

      // Dangling single percent sign
      final resSinglePercent = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: '%/art.png',
      );
      expect(resSinglePercent, equals('/cache/art.png'));

      // Truncated percent
      final resTruncatedPercent = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: 'art.png%2',
      );
      expect(resTruncatedPercent, isNull);

      // Complex query and fragment with URL encoding
      final resComplex = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: 'scene%20space.jpg?token=abc%26def=1#figure_anchor',
      );
      expect(resComplex, equals('/cache/scene_space.jpg'));

      // Empty string, spaces, or slashes only
      expect(EpubParserService.resolveImagePath(imageIndex: mockIndex, src: ''), isNull);
      expect(EpubParserService.resolveImagePath(imageIndex: mockIndex, src: '   '), isNull);
      expect(EpubParserService.resolveImagePath(imageIndex: mockIndex, src: '///'), isNull);
      expect(EpubParserService.resolveImagePath(imageIndex: mockIndex, src: '?onlyquery'), isNull);
      expect(EpubParserService.resolveImagePath(imageIndex: mockIndex, src: '#onlyfrag'), isNull);

      // Foreign web URLs should not falsely resolve to local assets
      expect(
        EpubParserService.resolveImagePath(imageIndex: mockIndex, src: 'https://cdn.example.com/missing.png'),
        isNull,
      );
    });

    test('1.2 Deeply nested relative paths (../../../../art.png) exceeding directory tree depth', () {
      // Chapter is at OEBPS/Text/ch1.xhtml (depth = 2 directories: OEBPS, Text)
      // Path tries to traverse 5 levels up: ../../../../../art.png
      final resExcessiveUp = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: '../../../../../art.png',
        chapterHref: 'OEBPS/Text/ch1.xhtml',
      );
      // Should not crash and should fall back gracefully to basename lookup
      expect(resExcessiveUp, equals('/cache/art.png'));

      // Traversal with redundant . and .. segments
      final resRedundant = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: '././../images/../images/./art.png',
        chapterHref: 'OEBPS/Text/ch1.xhtml',
      );
      expect(resRedundant, equals('/cache/art.png'));

      // Backslash normalization in relative paths
      final resBackslash = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: r'..\images\art.png',
        chapterHref: r'OEBPS\Text\ch1.xhtml',
      );
      expect(resBackslash, equals('/cache/art.png'));
    });

    test('1.3 Case insensitivity and uppercase extensions (.WEBP, .PNG)', () {
      // Lowercase query for uppercase indexed asset
      final res1 = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: 'cover.webp',
      );
      expect(res1, equals('/cache/cover.webp'));

      // Uppercase query for uppercase indexed asset
      final res2 = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: 'COVER.WEBP',
      );
      expect(res2, equals('/cache/cover.webp'));

      // Uppercase query for lowercase indexed asset
      final res3 = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: 'ART.PNG',
      );
      expect(res3, equals('/cache/art.png'));

      // Mixed case query
      final res4 = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: 'OEBPS/IMAGES/Art.png',
      );
      expect(res4, equals('/cache/art.png'));
    });

    test('1.4 Corrupted and edge-case Base64 strings in resolveImagePath', () {
      // Corrupted Base64 data URI should be returned as-is by resolver (ModernReaderScreen handles parsing/error)
      const corruptedDataUri = 'data:image/png;base64,???NOT_VALID_B64&&&';
      final resB64 = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: corruptedDataUri,
      );
      expect(resB64, equals(corruptedDataUri));

      // Malformed prefix without comma
      const noCommaUri = 'data:image/png;base64';
      final resNoComma = EpubParserService.resolveImagePath(
        imageIndex: mockIndex,
        src: noCommaUri,
      );
      expect(resNoComma, equals(noCommaUri));
    });
  });

  group('Adversarial Challenge 2: Extraction, Uppercase Extensions & Cache Poisoning Invalidation', () {
    test('2.1 EPUB archive containing uppercase extensions (.WEBP, .PNG) extracts cleanly', () async {
      final epubFiles = <String, List<int>>{
        'mimetype': utf8.encode('application/epub+zip'),
        'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''),
        'OEBPS/content.opf': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Uppercase Test</dc:title>
    <dc:identifier id="BookId">upper-001</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="Images/PHOTO.PNG" media-type="image/png"/>
    <item id="img2" href="Images/HERO.WEBP" media-type="image/webp"/>
    <item id="img3" href="Images/DIAGRAM.SVG" media-type="image/svg+xml"/>
  </manifest>
  <spine toc="ncx"><itemref idref="ch1"/></spine>
</package>'''),
        'OEBPS/toc.ncx': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="upper-001"/></head>
  <docTitle><text>Uppercase Test</text></docTitle>
  <navMap><navPoint id="np1" playOrder="1"><navLabel><text>C1</text></navLabel><content src="Text/ch1.xhtml"/></navPoint></navMap>
</ncx>'''),
        'OEBPS/Text/ch1.xhtml': utf8.encode('<html><body><p>Hello</p></body></html>'),
        'OEBPS/Images/PHOTO.PNG': _k1x1Png,
        'OEBPS/Images/HERO.WEBP': _k1x1Webp,
        'OEBPS/Images/DIAGRAM.SVG': _kVectorSvg,
      };

      final epubFile = File('${tempDir.path}/uppercase_book.epub');
      await epubFile.writeAsBytes(_createZipArchive(epubFiles));

      final extracted = await EpubParserService.extractAllBookImages(epubFile.path);

      expect(extracted.containsKey('PHOTO.PNG') || extracted.containsKey('photo.png'), isTrue);
      expect(extracted.containsKey('HERO.WEBP') || extracted.containsKey('hero.webp'), isTrue);
      expect(extracted.containsKey('DIAGRAM.SVG') || extracted.containsKey('diagram.svg'), isTrue);
    });

    test('2.2 Cache invalidation: modified EPUB with new images invalidates cache via mtime marker', () async {
      // Step 1: Create EPUB Version 1 with image_v1.png
      final v1Files = <String, List<int>>{
        'mimetype': utf8.encode('application/epub+zip'),
        'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
        'OEBPS/content.opf': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>V1</dc:title><dc:language>en</dc:language><dc:identifier id="BookId">v1</dc:identifier></metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="image_v1.png" media-type="image/png"/>
  </manifest>
  <spine toc="ncx"><itemref idref="ch1"/></spine>
</package>'''),
        'OEBPS/toc.ncx': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="v1"/></head>
  <docTitle><text>V1</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="ch1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>'''),
        'OEBPS/ch1.xhtml': utf8.encode('<html><body>V1</body></html>'),
        'OEBPS/image_v1.png': _k1x1Png,
      };

      final testEpub = File('${tempDir.path}/mutation_test.epub');
      await testEpub.writeAsBytes(_createZipArchive(v1Files));

      // Extract V1
      final extractedV1 = await EpubParserService.extractAllBookImages(testEpub.path);
      expect(extractedV1.containsKey('image_v1.png'), isTrue);
      expect(extractedV1.containsKey('image_v2.png'), isFalse);

      // Verify mtime marker file was created
      final imagesDir = Directory('${tempDir.path}/epub_images/${testEpub.path.hashCode}');
      final mtimeMarkerFile = File('${imagesDir.path}/.extracted_mtime');
      expect(mtimeMarkerFile.existsSync(), isTrue);
      final v1MtimeRecorded = mtimeMarkerFile.readAsStringSync().trim();
      expect(v1MtimeRecorded, equals((await testEpub.lastModified()).millisecondsSinceEpoch.toString()));

      // Step 2: Modify the EPUB file with Version 2 (add image_v2.png and remove image_v1.png)
      // Ensure file timestamp definitely advances
      await Future.delayed(const Duration(milliseconds: 1050));

      final v2Files = <String, List<int>>{
        'mimetype': utf8.encode('application/epub+zip'),
        'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
        'OEBPS/content.opf': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>V2</dc:title><dc:language>en</dc:language><dc:identifier id="BookId">v2</dc:identifier></metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img2" href="image_v2.png" media-type="image/png"/>
  </manifest>
  <spine toc="ncx"><itemref idref="ch1"/></spine>
</package>'''),
        'OEBPS/toc.ncx': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="v2"/></head>
  <docTitle><text>V2</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="ch1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>'''),
        'OEBPS/ch1.xhtml': utf8.encode('<html><body>V2</body></html>'),
        'OEBPS/image_v2.png': _k1x1Png,
      };

      await testEpub.writeAsBytes(_createZipArchive(v2Files));
      final v2FileMtime = (await testEpub.lastModified()).millisecondsSinceEpoch.toString();
      expect(v2FileMtime, isNot(equals(v1MtimeRecorded)));

      // Clear in-memory caches to simulate app reopen or fresh extraction on mutated file
      EpubParserService.clearCache();

      // Extract V2
      final extractedV2 = await EpubParserService.extractAllBookImages(testEpub.path);

      // Verify V2 was extracted and contains image_v2.png
      expect(extractedV2.containsKey('image_v2.png'), isTrue, reason: 'Cache invalidation must extract new image_v2.png');

      // Verify mtime marker was updated to V2 timestamp
      final v2MtimeRecorded = mtimeMarkerFile.readAsStringSync().trim();
      expect(v2MtimeRecorded, equals(v2FileMtime));
    });

    test('2.3 Corrupted / poisoned cache marker or corrupted index causes clean recovery without crash', () async {
      final epubFiles = <String, List<int>>{
        'mimetype': utf8.encode('application/epub+zip'),
        'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
        'OEBPS/content.opf': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Recovery</dc:title><dc:language>en</dc:language><dc:identifier id="BookId">rec</dc:identifier></metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="recover.png" media-type="image/png"/>
  </manifest>
  <spine toc="ncx"><itemref idref="ch1"/></spine>
</package>'''),
        'OEBPS/toc.ncx': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="rec"/></head>
  <docTitle><text>Recovery</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="ch1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>'''),
        'OEBPS/ch1.xhtml': utf8.encode('<html><body>R</body></html>'),
        'OEBPS/recover.png': _k1x1Png,
      };

      final testEpub = File('${tempDir.path}/recovery_test.epub');
      await testEpub.writeAsBytes(_createZipArchive(epubFiles));

      // Artificially poison the cache directory before extraction
      final imagesDir = Directory('${tempDir.path}/epub_images/${testEpub.path.hashCode}');
      await imagesDir.create(recursive: true);
      final indexFile = File('${imagesDir.path}/.index.json');
      final mtimeMarkerFile = File('${imagesDir.path}/.extracted_mtime');

      // Write corrupted JSON to .index.json and matching mtime
      final currentMtime = (await testEpub.lastModified()).millisecondsSinceEpoch.toString();
      await indexFile.writeAsString('{ MALFORMED_JSON_CORRUPT: true');
      await mtimeMarkerFile.writeAsString(currentMtime);

      EpubParserService.clearCache();

      // extractAllBookImages should not crash on malformed .index.json; should re-extract
      final recovered = await EpubParserService.extractAllBookImages(testEpub.path);
      expect(recovered.containsKey('recover.png'), isTrue);

      // Verify the poisoned file was rewritten with valid JSON
      final validJson = await indexFile.readAsString();
      expect(() => jsonDecode(validJson), returnsNormally);
    });
  });

  group('Adversarial Challenge 3: Widget Tests for ImageCodecException, Standalone Vectors & Missing Assets', () {
    testWidgets('3.1 Standalone vector SVG and missing images do not crash ModernReaderScreen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.binding.setSurfaceSize(const Size(800, 1200));

      // Write a standalone vector SVG file to disk
      final svgFile = File('${tempDir.path}/vector_drawing.svg');
      svgFile.writeAsBytesSync(_kVectorSvg);

      final dummyEpub = File('${tempDir.path}/widget_test.epub');
      dummyEpub.writeAsBytesSync(_createZipArchive({
        'mimetype': utf8.encode('application/epub+zip'),
        'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
        'OEBPS/content.opf': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Widget Test</dc:title><dc:identifier id="BookId">w1</dc:identifier></metadata>
  <manifest><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch1"/></spine>
</package>'''),
        'OEBPS/ch1.xhtml': utf8.encode('<html><body>Test</body></html>'),
      }));

      final book = BookInfo(
        id: 'widget_stress_book',
        title: 'Adversarial Stress Book',
        author: 'Sing Shong',
        filePath: dummyEpub.path,
        totalChapters: 1,
        lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // HTML containing:
      // 1. Missing image (404)
      // 2. Standalone SVG file via <img>
      // 3. SVG tag wrapping missing <image>
      // 4. Standalone pure SVG vector shape
      // 5. Corrupted Base64 data URIs
      // 6. Base64 of plain text "hello world" (valid base64 but invalid image bytes)
      const corruptedB64 = 'data:image/png;base64,!!!INVALID_BASE64_PAYLOAD???';
      final textB64 = 'data:image/png;base64,${base64Encode(utf8.encode('plain text not an image file'))}';

      final stressChapter = Chapter(
        index: 0,
        title: 'Adversarial Chapter',
        plainTextContent: 'Text line\n[EPILOGUE_IMG:${svgFile.path}]\n[EPILOGUE_IMG:nonexistent_file.png]',
        htmlContent: '''
          <div>
            <h1>Adversarial Test</h1>
            <!-- 1. Missing image -->
            <p><img src="completely_missing_asset.png" alt="Missing" /></p>
            <!-- 2. Standalone SVG file -->
            <p><img src="${svgFile.path}" alt="SVG Vector" /></p>
            <!-- 3. Inline SVG container without raster image -->
            <svg width="60" height="60"><circle cx="30" cy="30" r="25" fill="red"/></svg>
            <!-- 4. Corrupted Base64 -->
            <p><img src="$corruptedB64" alt="Corrupted Base64" /></p>
            <!-- 5. Valid Base64 of invalid image bytes -->
            <p><img src="$textB64" alt="Text as Base64" /></p>
          </div>
        ''',
        wordCount: 15,
        imageSrcs: [svgFile.path, 'completely_missing_asset.png'],
        isLoaded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernReaderScreen(
              book: book,
              chapters: [stressChapter],
              initialChapterIndex: 0,
              config: const ReaderConfig(useOriginalBookStyles: true),
              storageService: storage,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Absolutely zero unhandled exceptions
      expect(tester.takeException(), isNull, reason: 'Rendering standalone SVG, missing assets, and invalid Base64 must not throw unhandled exceptions');
      expect(find.text('Adversarial Test'), findsOneWidget);

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('3.2 Clean Text Mode inline images render with guards without crashing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final diskImg = File('${tempDir.path}/valid_clean_img.png');
      diskImg.writeAsBytesSync(_k1x1Png);

      final dummyEpub = File('${tempDir.path}/clean_text_test.epub');
      dummyEpub.writeAsBytesSync(_createZipArchive({
        'mimetype': utf8.encode('application/epub+zip'),
        'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
        'OEBPS/content.opf': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Clean Test</dc:title><dc:identifier id="BookId">c1</dc:identifier></metadata>
  <manifest><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch1"/></spine>
</package>'''),
        'OEBPS/ch1.xhtml': utf8.encode('<html><body>Clean</body></html>'),
      }));

      final book = BookInfo(
        id: 'clean_mode_book',
        title: 'Clean Text Book',
        author: 'Sing Shong',
        filePath: dummyEpub.path,
        totalChapters: 1,
        lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final cleanChapter = Chapter(
        index: 0,
        title: 'Clean Chapter',
        plainTextContent: 'First line.\n[EPILOGUE_IMG:${diskImg.path}]\nSecond line with missing:\n[EPILOGUE_IMG:not_found.png]\nThird line.',
        htmlContent: '<div><p>First line.</p><img src="${diskImg.path}"/><p>Second line.</p></div>',
        wordCount: 20,
        imageSrcs: [diskImg.path],
        isLoaded: true,
      );

      // Clean text mode: useOriginalBookStyles = false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernReaderScreen(
              book: book,
              chapters: [cleanChapter],
              initialChapterIndex: 0,
              config: const ReaderConfig(useOriginalBookStyles: false),
              storageService: storage,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('First line.'), findsWidgets);

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
