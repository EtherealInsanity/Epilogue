import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:epilogue/models/epub_project.dart';
import 'package:epilogue/services/epub_builder_service.dart';
import 'package:epilogue/services/epub_linter_service.dart';
import 'package:epilogue/services/studio_project_service.dart';
import 'package:archive/archive.dart';

void main() {
  group('EpubProject Model & Templates', () {
    test('EpubProject serializes and deserializes accurately', () {
      const chapter = ProjectChapter(
        id: 'ch_001',
        title: 'Chapter 1: The Incarnation',
        contentHtml: '<p>The train rattled as Dokja looked out the window.</p>',
        contentMarkdown: 'The train rattled as Dokja looked out the window.',
        order: 0,
      );

      const project = EpubProject(
        id: 'proj_123',
        title: 'Omniscient Reader Test',
        author: 'Sing Shong',
        description: 'An apocalyptic narrative.',
        language: 'en',
        identifier: 'urn:uuid:test-12345',
        publisher: 'Epilogue Press',
        createdTimestamp: 1000,
        modifiedTimestamp: 2000,
        chapters: [chapter],
        customCss: 'body { font-family: serif; }',
      );

      final map = project.toMap();
      final restored = EpubProject.fromMap(map);

      expect(restored.id, project.id);
      expect(restored.title, project.title);
      expect(restored.author, project.author);
      expect(restored.identifier, project.identifier);
      expect(restored.chapters.length, 1);
      expect(restored.chapters.first.title, 'Chapter 1: The Incarnation');
      expect(restored.chapters.first.wordCount, 9);
    });

    test('StudioProjectService templates generate expected structures', () async {
      final novel = await StudioProjectService.createFromTemplate(
        template: StudioTemplate.novel,
        title: 'My Novel',
      );
      expect(novel.title, 'My Novel');
      expect(novel.chapters.first.contentHtml.contains('drop-cap'), true);

      final ln = await StudioProjectService.createFromTemplate(
        template: StudioTemplate.lightNovel,
        title: 'My Light Novel',
      );
      expect(ln.customCss.contains('stat-box'), true);
      expect(ln.customCss.contains('constellation'), true);

      final nonFic = await StudioProjectService.createFromTemplate(
        template: StudioTemplate.nonFiction,
        title: 'My Research',
      );
      expect(nonFic.chapters.first.contentHtml.contains('blockquote'), true);
    });
  });

  group('EpubLinterService & Auto-Fix', () {
    test('Linter flags missing metadata, unclosed tags, and unescaped ampersands', () {
      const badChapter = ProjectChapter(
        id: 'ch_bad',
        title: 'Unclosed & Raw',
        contentHtml: '<p>Ben & Jerry without amp, and unclosed <b>bold text',
        order: 0,
      );

      const project = EpubProject(
        id: 'proj_bad',
        title: '',
        author: '',
        identifier: '',
        createdTimestamp: 1000,
        modifiedTimestamp: 1000,
        chapters: [badChapter],
      );

      final issues = EpubLinterService.validateProject(project);
      expect(issues.any((i) => i.ruleId == 'META_TITLE'), true);
      expect(issues.any((i) => i.ruleId == 'META_AUTHOR'), true);
      expect(issues.any((i) => i.ruleId == 'META_IDENTIFIER'), true);
      expect(issues.any((i) => i.ruleId == 'XHTML_UNESCAPED_AMP'), true);
      expect(issues.any((i) => i.ruleId == 'XHTML_UNCLOSED_TAG'), true);
    });

    test('Auto-fix repairs missing UUID, unescaped ampersands and tag syntax', () {
      const badChapter = ProjectChapter(
        id: 'ch_bad',
        title: 'Repair Test',
        contentHtml: '<p>Ben & Jerry &lt;ok&gt; <br> unclosed <div>test',
        order: 0,
      );

      const project = EpubProject(
        id: 'proj_bad',
        title: 'Valid Title',
        author: 'Valid Author',
        identifier: '',
        createdTimestamp: 1000,
        modifiedTimestamp: 1000,
        chapters: [badChapter],
      );

      final fixed = EpubLinterService.autoFixProject(project);
      expect(fixed.identifier.startsWith('urn:uuid:'), true);
      expect(fixed.chapters.first.contentHtml.contains('&amp;'), true);
      expect(fixed.chapters.first.contentHtml.contains('<br />'), true);
      expect(fixed.chapters.first.contentHtml.contains('</div>'), true);
    });
  });

  group('EpubBuilderService - Packaging & Standard Compliance', () {
    test('buildEpub creates compliant EPUB with uncompressed mimetype and valid structure', () async {
      final project = await StudioProjectService.createFromTemplate(
        template: StudioTemplate.novel,
        title: 'W3C Compliance Test',
      );
      final bytes = EpubBuilderService.buildEpub(project);

      expect(bytes.isNotEmpty, true);

      // Verify byte offset for mimetype in zip:
      // Offset 0-3: 0x50 0x4B 0x03 0x04 (PK\x03\x04)
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
      expect(bytes[2], 0x03);
      expect(bytes[3], 0x04);

      // Filename length is 8 ('mimetype')
      // Compression method at offset 8-9 should be 0 (uncompressed / STORE)
      expect(bytes[8], 0);
      expect(bytes[9], 0);

      // Filename starts at offset 30: 'mimetype'
      final fileName = ascii.decode(bytes.sublist(30, 38));
      expect(fileName, 'mimetype');

      // Uncompressed mimetype payload starts at offset 38: 'application/epub+zip'
      final mimePayload = ascii.decode(bytes.sublist(38, 58));
      expect(mimePayload, 'application/epub+zip');

      // Unpack archive to inspect required EPUB files
      final archive = ZipDecoder().decodeBytes(bytes);
      final fileNames = archive.files.map((f) => f.name).toSet();

      expect(fileNames.contains('mimetype'), true);
      expect(fileNames.contains('META-INF/container.xml'), true);
      expect(fileNames.contains('OEBPS/content.opf'), true);
      expect(fileNames.contains('OEBPS/toc.ncx'), true);
      expect(fileNames.contains('OEBPS/nav.xhtml'), true);
      expect(fileNames.contains('OEBPS/styles.css'), true);

      // Inspect container.xml
      final containerFile = archive.findFile('META-INF/container.xml')!;
      final containerXml = utf8.decode(containerFile.content as List<int>);
      expect(containerXml.contains('full-path="OEBPS/content.opf"'), true);

      // Inspect content.opf
      final opfFile = archive.findFile('OEBPS/content.opf')!;
      final opfXml = utf8.decode(opfFile.content as List<int>);
      expect(opfXml.contains('<dc:title>W3C Compliance Test</dc:title>'), true);
      expect(opfXml.contains('id="ncx"'), true);
      expect(opfXml.contains('properties="nav"'), true);

      // Inspect nav.xhtml
      final navFile = archive.findFile('OEBPS/nav.xhtml')!;
      final navXhtml = utf8.decode(navFile.content as List<int>);
      expect(navXhtml.contains('epub:type="toc"'), true);
    });
  });
}
