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

    test('wrapToColumns wraps text to specified width without breaking words', () {
      const text = 'The Crimson Moon shone brightly over the silent city of Backlund.';
      final wrapped = EpubParserService.wrapToColumns(text, 25);
      final lines = wrapped.split('\n');

      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(25));
      }
      expect(lines.length, greaterThan(1));
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
  });
}
