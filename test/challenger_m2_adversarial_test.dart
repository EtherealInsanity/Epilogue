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

// Standalone ZIP generator
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

Uint8List createZipArchive(Map<String, List<int>> files) {
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

final kAdv1x1PngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

final kAdv1x1JpgBytes = Uint8List.fromList([
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

final kAdv1x1WebpBytes = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0x1A, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x4C,
  0x0E, 0x00, 0x00, 0x00, 0x2F, 0x00, 0x00, 0x00, 0x10, 0x07, 0x10, 0x11, 0x11, 0x88, 0x88, 0xFE,
  0x07, 0x00,
]);

const kAdvSvgXmlString = '''<svg xmlns="http://www.w3.org/2000/svg" width="50" height="50" viewBox="0 0 50 50">
  <circle cx="25" cy="25" r="20" fill="red" />
</svg>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('epilogue_adversarial_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
    EpubParserService.clearCache();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    EpubParserService.clearCache();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Milestone 2 Adversarial Stress Test Suite', () {
    // =========================================================================
    // 1. Path Resolution Engine Adversarial Cases
    // =========================================================================
    group('1. Path Resolution Engine Adversarial Cases', () {
      final testIndex = <String, String>{
        'OEBPS/images/art.png': '/cache/art.png',
        'OEBPS/images/deep/nested/scene.WEBP': '/cache/scene.WEBP',
        'OEBPS/images/upper.PNG': '/cache/upper.PNG',
        'OEBPS/images/vector.svg': '/cache/vector.svg',
        'art.png': '/cache/art.png',
        'scene.WEBP': '/cache/scene.WEBP',
        'upper.PNG': '/cache/upper.PNG',
        'vector.svg': '/cache/vector.svg',
      };

      test('Deeply nested relative paths (../../../../art.png) with shallow chapter', () {
        final res = EpubParserService.resolveImagePath(
          imageIndex: testIndex,
          src: '../../../../art.png',
          chapterHref: 'OEBPS/Text/ch01.xhtml',
        );
        expect(res, equals('/cache/art.png'),
            reason: 'Excessive ../ segments must be clamped gracefully and resolve via basename/relative fallback');
      });

      test('Deeply nested relative paths from deeply nested chapter', () {
        final res = EpubParserService.resolveImagePath(
          imageIndex: testIndex,
          src: '../../../images/art.png',
          chapterHref: 'OEBPS/Content/Chapters/Level3/ch01.xhtml',
        );
        expect(res, equals('/cache/art.png'));
      });

      test('Malformed URIs with invalid percent-encoding (%zz, %, %E0%A4)', () {
        expect(() {
          final res1 = EpubParserService.resolveImagePath(
            imageIndex: testIndex,
            src: 'images/art%zz.png',
          );
          expect(res1, isNull);
        }, returnsNormally, reason: 'Malformed %zz must not throw FormatException');

        expect(() {
          final res2 = EpubParserService.resolveImagePath(
            imageIndex: testIndex,
            src: 'images/%/art.png',
          );
          expect(res2, equals('/cache/art.png'), reason: 'Basename lookup must salvage art.png');
        }, returnsNormally);

        expect(() {
          final res3 = EpubParserService.resolveImagePath(
            imageIndex: testIndex,
            src: 'images/art%E0%A4.png',
          );
          expect(res3, isNull);
        }, returnsNormally);
      });

      test('Uppercase extensions (.WEBP, .PNG, .SVG) and mixed case queries', () {
        final resWebp = EpubParserService.resolveImagePath(
          imageIndex: testIndex,
          src: '../images/deep/nested/scene.webp',
          chapterHref: 'OEBPS/Text/ch1.xhtml',
        );
        expect(resWebp, equals('/cache/scene.WEBP'),
            reason: 'Case-insensitive lookup must match .WEBP index with .webp query');

        final resPng = EpubParserService.resolveImagePath(
          imageIndex: testIndex,
          src: 'UPPER.png',
        );
        expect(resPng, equals('/cache/upper.PNG'));

        final resSvg = EpubParserService.resolveImagePath(
          imageIndex: testIndex,
          src: 'VECTOR.SVG',
        );
        expect(resSvg, equals('/cache/vector.svg'));
      });

      test('Corrupted and anomalous Base64 data strings', () {
        // Corrupted base64 passed to resolveImagePath: contract specifies it returns data:image/ as-is
        final corrupted = 'data:image/png;base64,@@@corrupted!!!';
        final resolved = EpubParserService.resolveImagePath(
          imageIndex: testIndex,
          src: corrupted,
        );
        expect(resolved, equals(corrupted));

        final emptyDataUri = 'data:image/jpeg;base64,';
        final resolvedEmpty = EpubParserService.resolveImagePath(
          imageIndex: testIndex,
          src: emptyDataUri,
        );
        expect(resolvedEmpty, equals(emptyDataUri));
      });

      test('Complex query strings, multiple fragments, and backslashes', () {
        final res = EpubParserService.resolveImagePath(
          imageIndex: testIndex,
          src: '..\\images\\art.png#page=1#view=fit?query=1&param=true',
          chapterHref: 'OEBPS/Text/ch01.xhtml',
        );
        expect(res, equals('/cache/art.png'));
      });

      test('Empty and null-like src strings', () {
        expect(EpubParserService.resolveImagePath(imageIndex: testIndex, src: ''), isNull);
        expect(EpubParserService.resolveImagePath(imageIndex: testIndex, src: '   '), isNull);
      });
    });

    // =========================================================================
    // 2. Cache Poisoning & MTime Invalidation Verification
    // =========================================================================
    group('2. Cache Poisoning & MTime Invalidation Verification', () {
      test('Initial extraction caches index and .extracted_mtime correctly', () async {
        final initialFiles = <String, List<int>>{
          'mimetype': utf8.encode('application/epub+zip'),
          'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''),
          'OEBPS/content.opf': utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="image_v1.png" media-type="image/png"/>
  </manifest>
  <spine><itemref idref="ch1"/></spine>
</package>'''),
          'OEBPS/ch1.xhtml': utf8.encode('<html><body><img src="image_v1.png"/></body></html>'),
          'OEBPS/image_v1.png': kAdv1x1PngBytes,
        };

        final epubFile = File('${tempDir.path}/poison_test.epub');
        epubFile.writeAsBytesSync(createZipArchive(initialFiles));

        final map1 = await EpubParserService.extractAllBookImages(epubFile.path);
        expect(map1.containsKey('image_v1.png'), isTrue);

        final cacheDir = Directory('${tempDir.path}/epub_images/${epubFile.path.hashCode}');
        expect(cacheDir.existsSync(), isTrue);
        final markerFile = File('${cacheDir.path}/.extracted_mtime');
        expect(markerFile.existsSync(), isTrue);
        final markerMtime = markerFile.readAsStringSync().trim();
        final actualMtime = epubFile.lastModifiedSync().millisecondsSinceEpoch.toString();
        expect(markerMtime, equals(actualMtime));

        // Re-run should use cache (fast path)
        final map2 = await EpubParserService.extractAllBookImages(epubFile.path);
        expect(map2.containsKey('image_v1.png'), isTrue);
      });

      test('Modified EPUB with new image invalidates cache via mtime marker', () async {
        final v1Files = <String, List<int>>{
          'mimetype': utf8.encode('application/epub+zip'),
          'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''),
          'OEBPS/content.opf': utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="img_old.png" media-type="image/png"/>
  </manifest>
  <spine><itemref idref="ch1"/></spine>
</package>'''),
          'OEBPS/ch1.xhtml': utf8.encode('<html><body><p>V1</p></body></html>'),
          'OEBPS/img_old.png': kAdv1x1PngBytes,
        };

        final epubFile = File('${tempDir.path}/mtime_update.epub');
        epubFile.writeAsBytesSync(createZipArchive(v1Files));

        final mapV1 = await EpubParserService.extractAllBookImages(epubFile.path);
        expect(mapV1.containsKey('img_old.png'), isTrue);
        expect(mapV1.containsKey('img_new.jpg'), isFalse);

        // Clear in-memory caches to simulate new session or updated state
        EpubParserService.clearCache();

        // Wait to guarantee a different timestamp on disk
        sleep(const Duration(milliseconds: 1100));

        // Modify EPUB on disk: add img_new.jpg
        final v2Files = Map<String, List<int>>.from(v1Files);
        v2Files['OEBPS/img_new.jpg'] = kAdv1x1JpgBytes;
        epubFile.writeAsBytesSync(createZipArchive(v2Files));

        // Ensure mtime has changed
        final newMtime = epubFile.lastModifiedSync().millisecondsSinceEpoch.toString();
        final cacheDir = Directory('${tempDir.path}/epub_images/${epubFile.path.hashCode}');
        final markerFile = File('${cacheDir.path}/.extracted_mtime');
        expect(markerFile.readAsStringSync().trim(), isNot(equals(newMtime)));

        // Extract again: mtime mismatch MUST trigger cache invalidation and re-extraction
        final mapV2 = await EpubParserService.extractAllBookImages(epubFile.path);
        expect(mapV2.containsKey('img_new.jpg'), isTrue,
            reason: 'Modified EPUB must invalidate stale cache and extract newly added image');
        expect(markerFile.readAsStringSync().trim(), equals(newMtime),
            reason: '.extracted_mtime marker must be updated to new mtime');
      });

      test('Corrupted cache files (.index.json corrupted or deleted) recover gracefully', () async {
        final initialFiles = <String, List<int>>{
          'mimetype': utf8.encode('application/epub+zip'),
          'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''),
          'OEBPS/content.opf': utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <manifest><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch1"/></spine>
</package>'''),
          'OEBPS/ch1.xhtml': utf8.encode('<html><body><p>Hi</p></body></html>'),
          'OEBPS/recovery.png': kAdv1x1PngBytes,
        };

        final epubFile = File('${tempDir.path}/corrupt_test.epub');
        epubFile.writeAsBytesSync(createZipArchive(initialFiles));

        await EpubParserService.extractAllBookImages(epubFile.path);
        EpubParserService.clearCache();

        final cacheDir = Directory('${tempDir.path}/epub_images/${epubFile.path.hashCode}');
        final indexFile = File('${cacheDir.path}/.index.json');

        // Corrupt index file with invalid JSON
        indexFile.writeAsStringSync('{{INVALID JSON GARBAGE');

        final mapRecovered = await EpubParserService.extractAllBookImages(epubFile.path);
        expect(mapRecovered.containsKey('recovery.png'), isTrue,
            reason: 'Parser must recover from corrupted cache and re-extract successfully');
      });
    });

    // =========================================================================
    // 3. Reader Mode Widget Stress Tests (ModernReaderScreen)
    // =========================================================================
    group('3. Reader Mode Widget Stress Tests (ModernReaderScreen)', () {
      testWidgets('Corrupted Base64 data URIs do not crash ModernReaderScreen', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = StorageService(prefs);

        await tester.binding.setSurfaceSize(const Size(800, 1200));

        final dummyEpub = File('${tempDir.path}/dummy_corrupt_b64.epub');
        dummyEpub.writeAsBytesSync(createZipArchive({
          'mimetype': utf8.encode('application/epub+zip'),
          'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
          'content.opf': utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <manifest><item id="ch" href="ch.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch"/></spine>
</package>'''),
          'ch.xhtml': utf8.encode('<html><body><p>Dummy</p></body></html>'),
        }));

        final book = BookInfo(
          id: 'test_corrupt_b64',
          title: 'Corrupted B64 Test',
          author: 'Tester',
          filePath: dummyEpub.path,
          totalChapters: 1,
        );

        final chapter = Chapter(
          index: 0,
          title: 'Adversarial Base64',
          plainTextContent: 'Text with corrupted base64:\n[EPILOGUE_IMG:data:image/png;base64,@@@invalid@@@]',
          htmlContent: '''
            <div>
              <p>Malformed Base64 1:</p>
              <img src="data:image/png;base64,!!!" />
              <p>Malformed Base64 2 (empty payload):</p>
              <img src="data:image/jpeg;base64," />
              <p>Malformed Base64 3 (no comma):</p>
              <img src="data:image/png;base64" />
              <p>Malformed Base64 4 (valid base64 but invalid image bytes):</p>
              <img src="data:image/png;base64,SGVsbG8gV29ybGQ=" />
            </div>
          ''',
          wordCount: 10,
          imageSrcs: const [],
          isLoaded: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernReaderScreen(
                book: book,
                chapters: [chapter],
                initialChapterIndex: 0,
                config: const ReaderConfig(useOriginalBookStyles: true),
                storageService: storage,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Expect zero unhandled exceptions
        expect(tester.takeException(), isNull,
            reason: 'Corrupted Base64 strings must not throw unhandled exceptions or crash reader');

        // Let background async tasks complete
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      testWidgets('Standalone SVG vector files and missing assets do not crash ModernReaderScreen', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = StorageService(prefs);

        await tester.binding.setSurfaceSize(const Size(800, 1200));

        // Write an SVG file on disk
        final svgFile = File('${tempDir.path}/standalone_vector.svg');
        svgFile.writeAsStringSync(kAdvSvgXmlString);

        final dummyEpub = File('${tempDir.path}/dummy_vector.epub');
        dummyEpub.writeAsBytesSync(createZipArchive({
          'mimetype': utf8.encode('application/epub+zip'),
          'META-INF/container.xml': utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
          'content.opf': utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <manifest><item id="ch" href="ch.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch"/></spine>
</package>'''),
          'ch.xhtml': utf8.encode('<html><body><p>Vector</p></body></html>'),
        }));

        final book = BookInfo(
          id: 'test_vector',
          title: 'Vector Test',
          author: 'Tester',
          filePath: dummyEpub.path,
          totalChapters: 1,
        );

        final chapter = Chapter(
          index: 0,
          title: 'Adversarial Vectors & Missing Assets',
          plainTextContent: 'Vector and missing:\n[EPILOGUE_IMG:${svgFile.path}]\n[EPILOGUE_IMG:/does/not/exist.png]',
          htmlContent: '''
            <div>
              <p>Standalone SVG via img tag:</p>
              <img src="${svgFile.path}" />
              <p>Standalone SVG element:</p>
              <svg width="60" height="60">
                <circle cx="30" cy="30" r="25" fill="blue" />
              </svg>
              <p>Missing asset via img tag:</p>
              <img src="/totally/nonexistent/missing_image_12345.png" />
              <p>Empty img tag:</p>
              <img src="" />
            </div>
          ''',
          wordCount: 15,
          imageSrcs: [svgFile.path, '/totally/nonexistent/missing_image_12345.png'],
          isLoaded: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernReaderScreen(
                book: book,
                chapters: [chapter],
                initialChapterIndex: 0,
                config: const ReaderConfig(useOriginalBookStyles: true),
                storageService: storage,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Must not crash or throw unhandled exceptions
        expect(tester.takeException(), isNull,
            reason: 'Standalone vector files or missing assets must not crash ModernReaderScreen');

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    });
  });
}
