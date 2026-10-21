import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/epub_project.dart';
import 'epub_builder_service.dart';
import 'epub_parser_service.dart';

enum StudioTemplate {
  novel,
  lightNovel,
  nonFiction,
}

class StudioProjectService {
  static const String _projectsDirName = 'studio_projects';

  static Future<Directory> _getProjectsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_projectsDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all saved authoring projects.
  static Future<List<EpubProject>> loadProjects() async {
    final dir = await _getProjectsDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));

    final projects = <EpubProject>[];
    for (final f in files) {
      try {
        final content = await f.readAsString();
        projects.add(EpubProject.fromJson(content));
      } catch (_) {}
    }

    projects.sort((a, b) => b.modifiedTimestamp.compareTo(a.modifiedTimestamp));
    return projects;
  }

  /// Saves or updates a project to persistent storage.
  static Future<void> saveProject(EpubProject project) async {
    final dir = await _getProjectsDir();
    final file = File('${dir.path}/${project.id}.json');
    final updated = project.copyWith(
      modifiedTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await file.writeAsString(updated.toJson());
  }

  /// Deletes a project by ID.
  static Future<void> deleteProject(String id) async {
    final dir = await _getProjectsDir();
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Creates a new project from a professional genre template.
  static Future<EpubProject> createFromTemplate({
    required StudioTemplate template,
    String title = 'Untitled Book',
    String author = 'Anonymous',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'proj_$now';
    final uuid = 'urn:uuid:$now';

    switch (template) {
      case StudioTemplate.novel:
        return EpubProject(
          id: id,
          title: title,
          author: author,
          identifier: uuid,
          description: 'A compelling story crafted with Epilogue Studio.',
          chapters: [
            const ProjectChapter(
              id: 'ch_1',
              title: 'Chapter 1: The Beginning',
              contentHtml:
                  '<p><span class="drop-cap">I</span>t was a quiet morning when everything began to unravel. The wind rustled the leaves outside the window, carrying with it the subtle fragrance of coming rain.</p>\n<p>No one could have predicted what would follow next.</p>\n<hr class="scene-break"/>\n<p>Hours passed before the first message arrived.</p>',
              contentMarkdown:
                  '# Chapter 1: The Beginning\n\nIt was a quiet morning when everything began to unravel. The wind rustled the leaves outside the window, carrying with it the subtle fragrance of coming rain.\n\nNo one could have predicted what would follow next.\n\n* * *\n\nHours passed before the first message arrived.',
              order: 0,
            ),
            const ProjectChapter(
              id: 'ch_2',
              title: 'Chapter 2: The Crossing',
              contentHtml:
                  '<p>The road ahead was paved in white stone, disappearing into the mist over the valley.</p>',
              contentMarkdown:
                  '# Chapter 2: The Crossing\n\nThe road ahead was paved in white stone, disappearing into the mist over the valley.',
              order: 1,
            ),
          ],
          createdTimestamp: now,
          modifiedTimestamp: now,
        );

      case StudioTemplate.lightNovel:
        return EpubProject(
          id: id,
          title: title,
          author: author,
          identifier: uuid,
          description: 'A Star Stream fantasy epic crafted with Epilogue Studio.',
          customCss: '''
.stat-box {
  border: 2px solid #0284C7;
  background-color: rgba(2, 132, 199, 0.06);
  padding: 12px;
  border-radius: 8px;
  margin: 1.5em 0;
  font-family: monospace;
}
.constellation-shout {
  color: #0284C7;
  font-weight: bold;
  font-family: monospace;
}''',
          chapters: [
            const ProjectChapter(
              id: 'ch_1',
              title: 'Chapter 1: The Scenario Begins',
              contentHtml:
                  '<div class="star-stream-dialogue">[The main scenario has arrived.]</div>\n<p><span class="drop-cap">T</span>he subway train jerked violently to a halt. The flickering fluorescent lights buzzed overhead before cutting out entirely.</p>\n<div class="stat-box">\n<strong>[Scenario Information]</strong><br/>\nDifficulty: F<br/>\nClear Condition: Eliminate one or more living organisms.<br/>\nTime Limit: 30 minutes.\n</div>\n<p class="constellation-shout">[The constellation \'Secretive Plotter\' is watching your movements.]</p>',
              contentMarkdown:
                  '# Chapter 1: The Scenario Begins\n\n[The main scenario has arrived.]\n\nThe subway train jerked violently to a halt. The flickering fluorescent lights buzzed overhead before cutting out entirely.\n\n[Scenario Information]\nDifficulty: F\nClear Condition: Eliminate one or more living organisms.\nTime Limit: 30 minutes.\n\n[The constellation \'Secretive Plotter\' is watching your movements.]',
              order: 0,
            ),
          ],
          createdTimestamp: now,
          modifiedTimestamp: now,
        );

      case StudioTemplate.nonFiction:
        return EpubProject(
          id: id,
          title: title,
          author: author,
          identifier: uuid,
          description: 'Structured non-fiction work with academic styling.',
          chapters: [
            const ProjectChapter(
              id: 'ch_1',
              title: 'Chapter 1: Foundational Principles',
              contentHtml:
                  '<p>This work examines the structural dynamics and behavioral models governing complex literary systems.</p>\n<h2>1.1 Core Axioms</h2>\n<p>Before investigating dynamic changes, we must define the three primary tenets.</p>\n<blockquote>"Precision of thought precedes elegance of execution." — Architectural Maxim</blockquote>',
              contentMarkdown:
                  '# Chapter 1: Foundational Principles\n\nThis work examines the structural dynamics and behavioral models governing complex literary systems.\n\n## 1.1 Core Axioms\n\nBefore investigating dynamic changes, we must define the three primary tenets.\n\n> "Precision of thought precedes elegance of execution." — Architectural Maxim',
              order: 0,
            ),
          ],
          createdTimestamp: now,
          modifiedTimestamp: now,
        );
    }
  }

  /// Imports an existing EPUB into a newly editable [EpubProject].
  static Future<EpubProject> importFromEpub(String filePath) async {
    final index = await EpubParserService.parseAndCacheBookIndex(filePath);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'proj_$now';

    final chapters = <ProjectChapter>[];
    for (int i = 0; i < index.totalChapters; i++) {
      final ch = await EpubParserService.loadChapterLazy(filePath, i);
      chapters.add(ProjectChapter(
        id: 'ch_${i + 1}',
        title: ch.title,
        contentHtml: ch.htmlContent,
        contentMarkdown: ch.plainTextContent,
        order: i,
        href: index.chapterMetas[i].href,
      ));
    }

    final css = await EpubParserService.extractAllBookCss(filePath);

    return EpubProject(
      id: id,
      title: index.title,
      author: index.author,
      identifier: 'urn:uuid:$now',
      coverImagePath: index.coverPath,
      customCss: css,
      chapters: chapters,
      createdTimestamp: now,
      modifiedTimestamp: now,
    );
  }

  /// Imports plain text or Markdown with automatic chapter splitting.
  static EpubProject importFromTextOrMarkdown(
    String text, {
    String title = 'Imported Story',
    String author = 'Anonymous',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'proj_$now';

    // Split by Markdown heading (# Chapter ...) or standard Chapter patterns
    final chapterSplitRegex = RegExp(r'(?:^|\n)(?=#+\s+Chapter|\bChapter\s+\d+|\bCHAPTER\s+[IVXLCDM0-9]+)', caseSensitive: false);
    final rawParts = text.split(chapterSplitRegex).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

    final chapters = <ProjectChapter>[];
    if (rawParts.isEmpty) {
      chapters.add(ProjectChapter(
        id: 'ch_1',
        title: 'Chapter 1',
        contentHtml: '<p>${text.trim()}</p>',
        contentMarkdown: text.trim(),
        order: 0,
      ));
    } else {
      for (int i = 0; i < rawParts.length; i++) {
        final part = rawParts[i];
        final firstLine = part.split('\n').first.replaceAll(RegExp(r'^#+\s*'), '').trim();
        final chTitle = firstLine.isNotEmpty ? firstLine : 'Chapter ${i + 1}';
        final bodyText = part.split('\n').skip(1).join('\n').trim();

        final paragraphs = (bodyText.isNotEmpty ? bodyText : part).split(RegExp(r'\n\s*\n'));
        final html = paragraphs.map((p) => '<p>${p.trim()}</p>').join('\n');

        chapters.add(ProjectChapter(
          id: 'ch_${i + 1}',
          title: chTitle,
          contentHtml: html,
          contentMarkdown: part,
          order: i,
        ));
      }
    }

    return EpubProject(
      id: id,
      title: title,
      author: author,
      identifier: 'urn:uuid:$now',
      chapters: chapters,
      createdTimestamp: now,
      modifiedTimestamp: now,
    );
  }

  /// Exports project to an EPUB file at targetFilePath.
  static Future<File> exportProject(EpubProject project, String targetFilePath) async {
    return await EpubBuilderService.saveEpubToFile(project, targetFilePath);
  }
}
