import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../models/epub_project.dart';

class EpubBuilderService {
  static const String defaultCss = '''
@charset "utf-8";

/* EPILOGUE STUDIO - Clean Typography Stylesheet */
html, body {
  margin: 0;
  padding: 0;
  font-family: serif;
  font-size: 1.0em;
  line-height: 1.6;
  text-rendering: optimizeLegibility;
}

body {
  padding: 5% 6%;
  hyphens: auto;
  -webkit-hyphens: auto;
  widows: 2;
  orphans: 2;
}

h1, h2, h3, h4, h5, h6 {
  font-family: sans-serif;
  font-weight: 700;
  line-height: 1.25;
  margin-top: 1.4em;
  margin-bottom: 0.6em;
  page-break-after: avoid;
  break-after: avoid;
}

h1.chapter-title {
  font-size: 1.8em;
  text-align: center;
  margin-top: 1.8em;
  margin-bottom: 1.2em;
}

p {
  margin: 0 0 0.8em 0;
  text-align: justify;
}

p.first, h1 + p, h2 + p, h3 + p {
  text-indent: 0;
}

/* Drop Cap Styling */
span.drop-cap {
  float: left;
  font-size: 3.2em;
  line-height: 0.8;
  padding-top: 4px;
  padding-right: 8px;
  padding-bottom: 2px;
  font-family: serif;
  font-weight: bold;
}

/* Scene Break Dividers */
hr.scene-break {
  border: 0;
  height: 1.5em;
  text-align: center;
  margin: 2em 0;
}

hr.scene-break::before {
  content: "* * *";
  letter-spacing: 0.6em;
  font-size: 1.1em;
  color: #666;
}

/* Blockquotes */
blockquote {
  margin: 1.5em 2em;
  padding-left: 1em;
  border-left: 3px solid #888;
  font-style: italic;
}

/* Star Stream Lore Dialogue Box */
.star-stream-dialogue {
  border: 1.5px solid #06B6D4;
  background-color: rgba(6, 182, 212, 0.05);
  border-radius: 6px;
  padding: 10px 14px;
  margin: 1.2em 0;
  font-family: monospace;
}

/* Images & Figures */
img {
  max-width: 100%;
  height: auto;
  display: block;
  margin: 1.5em auto;
}

figure {
  margin: 1.5em 0;
  text-align: center;
}

figcaption {
  font-size: 0.85em;
  color: #666;
  margin-top: 0.5em;
  font-style: italic;
}
''';

  /// Builds a byte-exact, W3C EPUB 3.3 and EPUB 2 NCX compliant EPUB archive.
  static Uint8List buildEpub(EpubProject project) {
    final archive = Archive();

    // 1. Uncompressed mimetype at byte offset 30
    final mimetypeBytes = utf8.encode('application/epub+zip');
    final mimetypeFile = ArchiveFile('mimetype', mimetypeBytes.length, mimetypeBytes);
    mimetypeFile.compress = false;
    archive.addFile(mimetypeFile);

    // 2. META-INF/container.xml
    const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
    _addTextFile(archive, 'META-INF/container.xml', containerXml);

    // 3. Stylesheet (OEBPS/styles.css)
    final css = project.customCss.trim().isNotEmpty
        ? '$defaultCss\n\n/* User Custom Styles */\n${project.customCss}'
        : defaultCss;
    _addTextFile(archive, 'OEBPS/styles.css', css);

    // 4. Cover image embedding (if available)
    String? coverItemTag;
    String? coverMetaTag;
    String? coverFilename;
    if (project.coverImagePath != null) {
      final coverFile = File(project.coverImagePath!);
      if (coverFile.existsSync()) {
        final bytes = coverFile.readAsBytesSync();
        if (bytes.isNotEmpty) {
          final ext = coverFile.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
          final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';
          coverFilename = 'cover.$ext';
          final af = ArchiveFile('OEBPS/$coverFilename', bytes.length, bytes);
          archive.addFile(af);

          coverItemTag = '<item id="cover-image" href="$coverFilename" media-type="$mediaType" properties="cover-image"/>';
          coverMetaTag = '<meta name="cover" content="cover-image"/>';
        }
      }
    }

    // 5. Chapter XHTML files
    final chapterItems = <String>[];
    final spineRefs = <String>[];
    final navLiItems = <String>[];
    final ncxNavPoints = <String>[];

    final chapters = project.chapters.isEmpty
        ? [
            const ProjectChapter(
              id: 'ch_1',
              title: 'Chapter 1',
              contentHtml: '<p>Start writing your story here...</p>',
              order: 0,
            )
          ]
        : project.chapters;

    for (int i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final filename = 'chapter_${i + 1}.xhtml';
      final chId = 'ch_${i + 1}';

      chapterItems.add('<item id="$chId" href="$filename" media-type="application/xhtml+xml"/>');
      spineRefs.add('<itemref idref="$chId"/>');
      navLiItems.add('<li><a href="$filename">${_escapeXml(ch.title)}</a></li>');
      ncxNavPoints.add('''    <navPoint id="navPoint-${i + 1}" playOrder="${i + 1}">
      <navLabel><text>${_escapeXml(ch.title)}</text></navLabel>
      <content src="$filename"/>
    </navPoint>''');

      final bodyHtml = _wrapChapterHtml(ch.title, ch.contentHtml);
      final xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="${project.language}">
<head>
  <title>${_escapeXml(ch.title)}</title>
  <link rel="stylesheet" type="text/css" href="styles.css"/>
</head>
<body>
  <section epub:type="bodymatter chapter">
    <h1 class="chapter-title">${_escapeXml(ch.title)}</h1>
$bodyHtml
  </section>
</body>
</html>''';

      _addTextFile(archive, 'OEBPS/$filename', xhtml);
    }

    // 6. Navigation Document (OEBPS/nav.xhtml) - EPUB 3
    const firstChapterHref = 'chapter_1.xhtml';
    final navXhtml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="${project.language}">
<head>
  <title>Table of Contents</title>
  <link rel="stylesheet" type="text/css" href="styles.css"/>
</head>
<body>
  <nav epub:type="toc" id="toc">
    <h1>Table of Contents</h1>
    <ol>
      ${navLiItems.join('\n      ')}
    </ol>
  </nav>
  <nav epub:type="landmarks" hidden="">
    <h2>Landmarks</h2>
    <ol>
      <li><a epub:type="toc" href="#toc">Table of Contents</a></li>
      <li><a epub:type="bodymatter" href="$firstChapterHref">Begin Reading</a></li>
    </ol>
  </nav>
</body>
</html>''';
    _addTextFile(archive, 'OEBPS/nav.xhtml', navXhtml);

    // 7. NCX (OEBPS/toc.ncx) - EPUB 2 backward compatibility
    final ncxXml = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="${_escapeXml(project.identifier)}"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>${_escapeXml(project.title)}</text></docTitle>
  <docAuthor><text>${_escapeXml(project.author)}</text></docAuthor>
  <navMap>
${ncxNavPoints.join('\n')}
  </navMap>
</ncx>''';
    _addTextFile(archive, 'OEBPS/toc.ncx', ncxXml);

    // 8. Package Document (OEBPS/content.opf)
    final modifiedIso = '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';
    final opfXml = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>${_escapeXml(project.title)}</dc:title>
    <dc:creator>${_escapeXml(project.author)}</dc:creator>
    <dc:identifier id="pub-id">${_escapeXml(project.identifier)}</dc:identifier>
    <dc:language>${_escapeXml(project.language)}</dc:language>
    <dc:publisher>${_escapeXml(project.publisher)}</dc:publisher>
    <dc:rights>${_escapeXml(project.rights)}</dc:rights>
    <dc:description>${_escapeXml(project.description)}</dc:description>
    <meta property="dcterms:modified">$modifiedIso</meta>
    ${coverMetaTag ?? ''}
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="css" href="styles.css" media-type="text/css"/>
    ${coverItemTag ?? ''}
    ${chapterItems.join('\n    ')}
  </manifest>
  <spine toc="ncx">
    ${spineRefs.join('\n    ')}
  </spine>
</package>''';
    _addTextFile(archive, 'OEBPS/content.opf', opfXml);

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? []);
  }

  /// Writes the generated EPUB directly to an output file path.
  static Future<File> saveEpubToFile(EpubProject project, String targetFilePath) async {
    final bytes = buildEpub(project);
    final targetFile = File(targetFilePath);
    if (!targetFile.parent.existsSync()) {
      targetFile.parent.createSync(recursive: true);
    }
    await targetFile.writeAsBytes(bytes);
    return targetFile;
  }

  static void _addTextFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    final af = ArchiveFile(path, bytes.length, bytes);
    archive.addFile(af);
  }

  static String _wrapChapterHtml(String title, String rawHtml) {
    final trimmed = rawHtml.trim();
    if (trimmed.isEmpty) {
      return '    <p>[Empty Chapter]</p>';
    }

    // If user provided raw text without tags, wrap into paragraphs
    if (!trimmed.contains('<p') && !trimmed.contains('<div') && !trimmed.contains('<h')) {
      final paragraphs = trimmed.split(RegExp(r'\n\s*\n'));
      return paragraphs.map((p) => '    <p>${_escapeXml(p.trim())}</p>').join('\n');
    }

    return '    $trimmed';
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
