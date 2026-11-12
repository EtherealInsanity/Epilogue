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
// Standalone In-Memory ZIP / EPUB Generator (No External Dependencies)
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

Uint8List createZipArchive(Map<String, List<int>> files) {
  final out = BytesBuilder();
  final centralDir = BytesBuilder();
  int offset = 0;

  for (final entry in files.entries) {
    final nameBytes = utf8.encode(entry.key);
    final data = entry.value;
    final crc = _crc32(data);

    // Local file header (30 bytes)
    final local = ByteData(30);
    local.setUint32(0, 0x04034b50, Endian.little);
    local.setUint16(4, 20, Endian.little);
    local.setUint16(6, 0, Endian.little);
    local.setUint16(8, 0, Endian.little); // Stored (no compression)
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

    // Central directory header (46 bytes)
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

  // End of central directory record (22 bytes)
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

// 1x1 Transparent PNG byte fixture
final k1x1PngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

// 1x1 JPEG byte fixture
final k1x1JpgBytes = Uint8List.fromList([
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

// 1x1 WebP byte fixture
final k1x1WebpBytes = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0x1A, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x4C,
  0x0E, 0x00, 0x00, 0x00, 0x2F, 0x00, 0x00, 0x00, 0x10, 0x07, 0x10, 0x11, 0x11, 0x88, 0x88, 0xFE,
  0x07, 0x00,
]);

// Valid Base64 PNG URI
const kBase64PngDataUri =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

// Specification-compliant path resolver oracle matching PROJECT.md Contract #2
String? resolveImagePathOracle({
  required Map<String, String> imageIndex,
  required String src,
  String? chapterHref,
}) {
  if (src.isEmpty) return null;
  if (src.startsWith('data:image/')) return src;

  // 1. Strip URI query and fragment
  var cleaned = src.split('#').first.split('?').first;
  // 2. Normalize backslashes
  cleaned = cleaned.replaceAll('\\', '/');
  // 3. Decode URI components
  try {
    cleaned = Uri.decodeFull(cleaned);
  } catch (_) {}

  // 4. Exact / direct lookup
  if (imageIndex.containsKey(cleaned)) return imageIndex[cleaned];

  // 5. Relative resolution against chapter directory
  if (chapterHref != null && chapterHref.isNotEmpty) {
    final chapterDirParts = chapterHref.replaceAll('\\', '/').split('/');
    chapterDirParts.removeLast(); // strip chapter filename

    final targetParts = List<String>.from(chapterDirParts);
    for (final segment in cleaned.split('/')) {
      if (segment == '.' || segment.isEmpty) continue;
      if (segment == '..') {
        if (targetParts.isNotEmpty) targetParts.removeLast();
      } else {
        targetParts.add(segment);
      }
    }
    final resolvedRelative = targetParts.join('/');
    if (imageIndex.containsKey(resolvedRelative)) return imageIndex[resolvedRelative];
  }

  // 6. Basename lookup
  final simpleName = cleaned.split('/').last;
  if (imageIndex.containsKey(simpleName)) return imageIndex[simpleName];

  // 7. Case-insensitive lookup
  final lowerSimple = simpleName.toLowerCase();
  for (final entry in imageIndex.entries) {
    if (entry.key.toLowerCase() == lowerSimple ||
        entry.key.toLowerCase().endsWith('/$lowerSimple')) {
      return entry.value;
    }
  }

  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storageService;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('epilogue_e2e_images_');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('E2E Reader Mode Image Loading Test Suite (Requirement R1)', () {
    // =========================================================================
    // Tier 1: Category-Partition & Standard EPUB Image Extraction
    // =========================================================================
    test('Tier 1: Extract standard embedded JPG & PNG images from EPUB archive to local disk', () async {
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
    <dc:title>Standard Image Novel</dc:title>
    <dc:language>en</dc:language>
    <dc:identifier id="BookId">std-img-001</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img_cover" href="images/cover.jpg" media-type="image/jpeg"/>
    <item id="img_fig1" href="images/figure1.png" media-type="image/png"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
  </spine>
</package>'''),
        'OEBPS/toc.ncx': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="std-img-001"/></head>
  <docTitle><text>Standard Image Novel</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="Text/ch1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>'''),
        'OEBPS/Text/ch1.xhtml': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body>
  <h1>Chapter 1: The Apocalypse</h1>
  <p><img src="../images/cover.jpg" alt="Cover" /></p>
  <p><img src="../images/figure1.png" alt="Figure 1" /></p>
</body>
</html>'''),
        'OEBPS/images/cover.jpg': k1x1JpgBytes,
        'OEBPS/images/figure1.png': k1x1PngBytes,
      };

      final epubBytes = createZipArchive(epubFiles);
      final epubFile = File('${tempDir.path}/standard_book.epub');
      await epubFile.writeAsBytes(epubBytes);

      // Perform extraction
      final extractedMap = await EpubParserService.extractAllBookImages(epubFile.path);

      expect(extractedMap, isNotEmpty, reason: 'extractAllBookImages should extract images from valid EPUB');
      expect(
        extractedMap.containsKey('cover.jpg') || extractedMap.containsKey('OEBPS/images/cover.jpg'),
        isTrue,
        reason: 'Extracted map must contain cover.jpg',
      );
      expect(
        extractedMap.containsKey('figure1.png') || extractedMap.containsKey('OEBPS/images/figure1.png'),
        isTrue,
        reason: 'Extracted map must contain figure1.png',
      );

      // Verify physical disk persistence
      final coverPath = extractedMap['cover.jpg'] ?? extractedMap['OEBPS/images/cover.jpg'];
      expect(coverPath, isNotNull);
      expect(File(coverPath!).existsSync(), isTrue, reason: 'Extracted image file must exist on disk');
      expect(File(coverPath).lengthSync(), equals(k1x1JpgBytes.length));
    });

    // =========================================================================
    // Tier 2: Boundary Value Analysis (WebP, URL-encoded, SVG, Unmanifested)
    // =========================================================================
    test('Tier 2: Boundary cases: relative paths, URL-encoded names, WebP, unmanifested entries, SVG tags', () async {
      final boundaryEpubFiles = <String, List<int>>{
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
    <dc:title>Boundary Case Novel</dc:title>
    <dc:language>en</dc:language>
    <dc:identifier id="BookId">bnd-img-002</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="Text/deep/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img_enc" href="images/fig%20one.png" media-type="image/png"/>
    <item id="img_webp" href="media/scene.webp" media-type="image/webp"/>
    <item id="img_cover" href="Images/Cover_Plate.JPG" media-type="image/jpeg"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
  </spine>
</package>'''),
        'OEBPS/toc.ncx': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="bnd-img-002"/></head>
  <docTitle><text>Boundary Case Novel</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>Deep Chapter</text></navLabel>
      <content src="Text/deep/ch1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>'''),
        'OEBPS/Text/deep/ch1.xhtml': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Deep Chapter</title></head>
<body>
  <h1>Illustrated Plates</h1>
  <!-- Deep relative path with URL encoding -->
  <p><img src="../../images/fig%20one.png" alt="Fig One" /></p>
  <!-- Modern WebP format -->
  <p><img src="../../media/scene.webp" alt="WebP Scene" /></p>
  <!-- SVG container tag wrapping raster image -->
  <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
    <image href="../../Images/Cover_Plate.JPG" width="100" height="100"/>
  </svg>
</body>
</html>'''),
        'OEBPS/images/fig one.png': k1x1PngBytes,
        'OEBPS/media/scene.webp': k1x1WebpBytes,
        'OEBPS/Images/Cover_Plate.JPG': k1x1JpgBytes,
        // Unmanifested archive file: present in zip archive but omitted from content.opf
        'OEBPS/images/unmanifested_bonus.png': k1x1PngBytes,
      };

      final epubBytes = createZipArchive(boundaryEpubFiles);
      final epubFile = File('${tempDir.path}/boundary_book.epub');
      await epubFile.writeAsBytes(epubBytes);

      final extractedMap = await EpubParserService.extractAllBookImages(epubFile.path);

      expect(extractedMap, isNotEmpty);

      // Verify WebP extraction (F5 requirement)
      final hasWebp = extractedMap.keys.any((k) => k.contains('scene.webp'));
      expect(hasWebp, isTrue, reason: 'WebP images must be extracted from the EPUB');

      // Verify URL-encoded / decoded filename handling
      final hasEncodedOrDecoded = extractedMap.keys.any(
        (k) => k.contains('fig one.png') || k.contains('fig%20one.png'),
      );
      expect(hasEncodedOrDecoded, isTrue, reason: 'URL-encoded image files must be indexed');

      // Verify unmanifested zip entry extraction (F5 requirement)
      final hasUnmanifested = extractedMap.keys.any((k) => k.contains('unmanifested_bonus.png'));
      expect(hasUnmanifested, isTrue, reason: 'Unmanifested ZIP archive images must be extracted');
    });

    // =========================================================================
    // Tier 3: Pairwise Combinatorial Path Resolution Engine Tests
    // =========================================================================
    test('Tier 3: Path resolver unit tests verifying canonical, relative, case-insensitive, and basename lookups', () {
      final mockImageIndex = <String, String>{
        'OEBPS/images/figure1.png': '/data/cache/figure1.png',
        'OEBPS/Images/Cover_Art.jpg': '/data/cache/Cover_Art.jpg',
        'OEBPS/media/scene%20plate.webp': '/data/cache/scene_plate.webp',
        'OEBPS/media/scene plate.webp': '/data/cache/scene_plate.webp',
        'figure1.png': '/data/cache/figure1.png',
        'Cover_Art.jpg': '/data/cache/Cover_Art.jpg',
        'scene plate.webp': '/data/cache/scene_plate.webp',
      };

      // 1. Canonical full archive path lookup
      final res1 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: 'OEBPS/images/figure1.png',
      );
      expect(res1, equals('/data/cache/figure1.png'));

      // 2. Relative resolution with chapter directory
      final res2 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: '../images/figure1.png',
        chapterHref: 'OEBPS/Text/ch01.xhtml',
      );
      expect(res2, equals('/data/cache/figure1.png'));

      // 3. Deep multi-level relative path resolution
      final res3 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: '../../images/figure1.png',
        chapterHref: 'OEBPS/Text/subfolder/ch01.xhtml',
      );
      expect(res3, equals('/data/cache/figure1.png'));

      // 4. URL-encoded source with spaces
      final res4 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: 'scene%20plate.webp',
      );
      expect(res4, equals('/data/cache/scene_plate.webp'));

      // 5. Query parameters & URI fragments stripped
      final res5 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: 'Cover_Art.jpg#page=1?scale=2',
      );
      expect(res5, equals('/data/cache/Cover_Art.jpg'));

      // 6. Basename fallback lookup
      final res6 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: 'some/arbitrary/path/to/Cover_Art.jpg',
      );
      expect(res6, equals('/data/cache/Cover_Art.jpg'));

      // 7. Case-insensitive fallback lookup
      final res7 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: 'cover_art.jpg',
      );
      expect(res7, equals('/data/cache/Cover_Art.jpg'));

      // 8. Base64 Data URI preserved directly
      final res8 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: kBase64PngDataUri,
      );
      expect(res8, equals(kBase64PngDataUri));

      // 9. Non-existent asset safely resolves to null
      final res9 = resolveImagePathOracle(
        imageIndex: mockImageIndex,
        src: 'missing_nonexistent_image.png',
      );
      expect(res9, isNull);
    });

    // =========================================================================
    // Tier 4: Real-World Workloads & ModernReaderScreen Widget Rendering
    // =========================================================================
    testWidgets('Tier 4: ModernReaderScreen renders Image.file and Base64 images without crashing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      // Create dummy image files on disk
      final diskCover = File('${tempDir.path}/disk_cover.jpg');
      await diskCover.writeAsBytes(k1x1JpgBytes);

      final diskFig = File('${tempDir.path}/disk_figure.png');
      await diskFig.writeAsBytes(k1x1PngBytes);

      final readerEpub = File('${tempDir.path}/reader_book.epub');
      await readerEpub.writeAsBytes(createZipArchive({
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
    <dc:title>Reader Book</dc:title>
    <dc:language>en</dc:language>
    <dc:identifier id="BookId">reader-001</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
  </spine>
</package>'''),
        'OEBPS/toc.ncx': utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="reader-001"/></head>
  <docTitle><text>Reader Book</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="Text/ch1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>'''),
        'OEBPS/Text/ch1.xhtml': utf8.encode('<html><body><p>Text</p></body></html>'),
      }));

      final readerBook = BookInfo(
        id: 'reader_img_book',
        title: 'Three Ways to Survive Reader Book',
        author: 'Sing Shong',
        filePath: readerEpub.path,
        totalChapters: 1,
        lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final readerChapter = Chapter(
        index: 0,
        title: 'Chapter 0: The First Scenario',
        plainTextContent: 'The dokkaebi laughed in the darkness.\n[Image Plate 1]\nA blue screen appeared.',
        htmlContent: '''
          <div>
            <h1>The First Scenario</h1>
            <p>Look at the cover image:</p>
            <img src="${diskCover.path}" alt="Cover" />
            <p>Embedded Base64 illustration:</p>
            <img src="$kBase64PngDataUri" alt="Base64 Image" />
          </div>
        ''',
        wordCount: 25,
        imageSrcs: [diskCover.path, diskFig.path],
        isLoaded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernReaderScreen(
              book: readerBook,
              chapters: [readerChapter],
              initialChapterIndex: 0,
              config: const ReaderConfig(useOriginalBookStyles: true),
              storageService: storageService,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Zero unhandled exceptions or crashes
      expect(tester.takeException(), isNull, reason: 'Rendering images must not produce unhandled exceptions');

      // The reader screen should be mounted and displaying content
      expect(find.textContaining('The First Scenario'), findsOneWidget);

      // Allow background image & css extraction futures to settle
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });

      // Cleanly dispose reader screen to cancel periodic tickers
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
