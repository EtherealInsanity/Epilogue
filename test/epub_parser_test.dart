import 'package:flutter_test/flutter_test.dart';
import 'package:epilogue/models/chapter.dart';
import 'package:epilogue/services/epub_parser_service.dart';

void main() {
  group('EpubParserService HTML & Formatting Tests', () {
    test('htmlToPlainText strips tags and preserves newlines', () {
      const html = '''
        <html>
          <body>
            <h1>Chapter 1: The Beginning</h1>
            <p>The night was cold and damp.<br/>A fog rose from the river.</p>
            <div>Klein looked at the revolver on the desk.</div>
          </body>
        </html>
      ''';

      final plain = EpubParserService.htmlToPlainText(html);
      expect(plain, contains('Chapter 1: The Beginning'));
      expect(plain, contains('The night was cold and damp.'));
      expect(plain, contains('A fog rose from the river.'));
      expect(plain, contains('Klein looked at the revolver on the desk.'));
      expect(plain, isNot(contains('<p>')));
      expect(plain, isNot(contains('</h1>')));
    });

    test('decodeHtmlEntities decodes common and numbered entities', () {
      const input = 'Tom &amp; Jerry &quot;said&quot; &#39;hello&#39; &mdash; 5 &gt; 3 &lt; 8 &hellip;';
      final output = EpubParserService.decodeHtmlEntities(input);
      expect(output, equals("Tom & Jerry \"said\" 'hello' — 5 > 3 < 8 …"));
    });

    test('grepChapter finds keywords correctly with line numbers', () {
      const content = '''
Chapter 452
Klein adjusted his clown mask.
Amon smiled mysteriously in the shadows.
The crystal monocle caught the dim candlelight.
Amon tapped the table twice.
''';

      final chapter = Chapter.fromHtml(
        index: 0,
        title: 'Chapter 452',
        htmlContent: '<p>$content</p>',
        plainTextContent: content,
      );

      final matches = EpubParserService.grepChapter(
        chapter: chapter,
        query: 'Amon',
      );

      expect(matches.length, equals(2));
      expect(matches[0].lineNumber, equals(3));
      expect(matches[0].lineText, contains('Amon smiled'));
      expect(matches[1].lineNumber, equals(5));
      expect(matches[1].lineText, contains('Amon tapped'));
    });

    test('htmlToPlainText preserves inline [EPILOGUE_IMG:...] tokens for img and svg image tags', () {
      const html = '''
        <div>
          <h1>Illustrated Scene</h1>
          <p>Before image.</p>
          <img src="../images/scene1.png" alt="Scene 1" />
          <svg><image xlink:href="cover.jpg"/></svg>
          <p>After image.</p>
        </div>
      ''';

      final plain = EpubParserService.htmlToPlainText(html);
      expect(plain, contains('[EPILOGUE_IMG:../images/scene1.png]'));
      expect(plain, contains('[EPILOGUE_IMG:cover.jpg]'));
      expect(plain, isNot(contains('<img')));
      expect(plain, isNot(contains('<svg')));
      expect(plain, isNot(contains('<image')));
    });

    test('Chapter model retains contentFileName and propagates to instance', () {
      final ch = Chapter.fromHtml(
        index: 1,
        title: 'Chapter 1',
        htmlContent: '<p>Content</p>',
        plainTextContent: 'Content',
        contentFileName: 'OEBPS/Text/ch01.xhtml',
      );
      expect(ch.contentFileName, equals('OEBPS/Text/ch01.xhtml'));

      final placeholder = Chapter.placeholder(
        index: 2,
        title: 'Chapter 2',
        contentFileName: 'OEBPS/Text/ch02.xhtml',
      );
      expect(placeholder.contentFileName, equals('OEBPS/Text/ch02.xhtml'));
    });

    test('EpubParserService.resolveImagePath resolves across direct, relative, decoded, and case-insensitive lookups', () {
      final index = <String, String>{
        'OEBPS/images/figure1.png': '/cache/figure1.png',
        'OEBPS/Images/Cover_Art.jpg': '/cache/Cover_Art.jpg',
        'OEBPS/media/scene plate.webp': '/cache/scene_plate.webp',
        'figure1.png': '/cache/figure1.png',
        'Cover_Art.jpg': '/cache/Cover_Art.jpg',
      };

      // 1. Direct canonical lookup
      expect(
        EpubParserService.resolveImagePath(imageIndex: index, src: 'OEBPS/images/figure1.png'),
        equals('/cache/figure1.png'),
      );

      // 2. Relative resolution with chapter directory
      expect(
        EpubParserService.resolveImagePath(
          imageIndex: index,
          src: '../images/figure1.png',
          chapterHref: 'OEBPS/Text/ch01.xhtml',
        ),
        equals('/cache/figure1.png'),
      );

      // 3. Multi-level relative resolution
      expect(
        EpubParserService.resolveImagePath(
          imageIndex: index,
          src: '../../images/figure1.png',
          chapterHref: 'OEBPS/Text/deep/ch01.xhtml',
        ),
        equals('/cache/figure1.png'),
      );

      // 4. URL-encoded resolution
      expect(
        EpubParserService.resolveImagePath(
          imageIndex: index,
          src: 'scene%20plate.webp',
          chapterHref: 'OEBPS/Text/ch01.xhtml',
        ),
        equals('/cache/scene_plate.webp'),
      );

      // 5. Query and fragment stripped
      expect(
        EpubParserService.resolveImagePath(
          imageIndex: index,
          src: 'Cover_Art.jpg#anchor?w=100',
        ),
        equals('/cache/Cover_Art.jpg'),
      );

      // 6. Basename fallback
      expect(
        EpubParserService.resolveImagePath(
          imageIndex: index,
          src: 'arbitrary/path/figure1.png',
        ),
        equals('/cache/figure1.png'),
      );

      // 7. Case-insensitive lookup
      expect(
        EpubParserService.resolveImagePath(
          imageIndex: index,
          src: 'cover_art.jpg',
        ),
        equals('/cache/Cover_Art.jpg'),
      );

      // 8. Base64 data URI passed directly
      const b64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      expect(
        EpubParserService.resolveImagePath(imageIndex: index, src: b64),
        equals(b64),
      );

      // 9. Nonexistent returns null
      expect(
        EpubParserService.resolveImagePath(imageIndex: index, src: 'missing.png'),
        isNull,
      );
    });
  });
}
