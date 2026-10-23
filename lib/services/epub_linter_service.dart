import 'dart:io';
import '../models/epub_project.dart';
import '../models/linter_issue.dart';

class EpubLinterService {
  /// Runs complete pre-flight validation on an [EpubProject].
  static List<LinterIssue> validateProject(EpubProject project) {
    final issues = <LinterIssue>[];

    // 1. Metadata Checks
    if (project.title.trim().isEmpty || project.title == 'Untitled Book') {
      issues.add(const LinterIssue(
        ruleId: 'META_TITLE',
        message: 'Book title is missing or set to default placeholder.',
        severity: LinterSeverity.warning,
        canAutoFix: false,
      ));
    }

    if (project.author.trim().isEmpty || project.author == 'Anonymous') {
      issues.add(const LinterIssue(
        ruleId: 'META_AUTHOR',
        message: 'Author name is missing or set to Anonymous.',
        severity: LinterSeverity.info,
        canAutoFix: false,
      ));
    }

    if (project.identifier.trim().isEmpty) {
      issues.add(const LinterIssue(
        ruleId: 'META_IDENTIFIER',
        message: 'Unique publication identifier (UUID or ISBN) is missing.',
        severity: LinterSeverity.error,
        canAutoFix: true,
      ));
    }

    if (project.coverImagePath == null || !File(project.coverImagePath!).existsSync()) {
      issues.add(const LinterIssue(
        ruleId: 'META_COVER',
        message: 'Cover image is not set. Retail e-readers will render a generic default cover.',
        severity: LinterSeverity.info,
        canAutoFix: false,
      ));
    }

    // 2. Chapters Structure Checks
    if (project.chapters.isEmpty) {
      issues.add(const LinterIssue(
        ruleId: 'SPINE_EMPTY',
        message: 'The book project has no chapters. At least one chapter is required.',
        severity: LinterSeverity.error,
        canAutoFix: true,
      ));
      return issues;
    }

    for (int i = 0; i < project.chapters.length; i++) {
      final ch = project.chapters[i];
      final html = ch.contentHtml.trim();

      if (ch.title.trim().isEmpty) {
        issues.add(LinterIssue(
          ruleId: 'CHAPTER_TITLE',
          message: 'Chapter ${i + 1} has an empty title.',
          severity: LinterSeverity.warning,
          chapterIndex: i,
          canAutoFix: true,
        ));
      }

      if (html.isEmpty && ch.contentMarkdown.trim().isEmpty) {
        issues.add(LinterIssue(
          ruleId: 'CHAPTER_EMPTY',
          message: '"${ch.title}" contains no text content.',
          severity: LinterSeverity.warning,
          chapterIndex: i,
          canAutoFix: false,
        ));
      }

      // Check unclosed basic tags in HTML
      final unclosedTags = _findUnclosedTags(html);
      if (unclosedTags.isNotEmpty) {
        issues.add(LinterIssue(
          ruleId: 'XHTML_UNCLOSED_TAG',
          message: '"${ch.title}" has unclosed XHTML tags: <${unclosedTags.join('>, <')}>.',
          severity: LinterSeverity.warning,
          chapterIndex: i,
          canAutoFix: true,
        ));
      }

      // Check unescaped ampersands
      if (RegExp(r'&(?!(amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)').hasMatch(html)) {
        issues.add(LinterIssue(
          ruleId: 'XHTML_UNESCAPED_AMP',
          message: '"${ch.title}" contains unescaped "&" characters (must be &amp;).',
          severity: LinterSeverity.warning,
          chapterIndex: i,
          canAutoFix: true,
        ));
      }
    }

    return issues;
  }

  /// Automatically fixes auto-fixable issues across the project.
  static EpubProject autoFixProject(EpubProject project) {
    var fixed = project;

    // 1. Fix missing identifier
    if (fixed.identifier.trim().isEmpty) {
      fixed = fixed.copyWith(
        identifier: 'urn:uuid:${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    // 2. Fix empty spine
    if (fixed.chapters.isEmpty) {
      fixed = fixed.copyWith(
        chapters: [
          const ProjectChapter(
            id: 'ch_1',
            title: 'Chapter 1',
            contentHtml: '<p>Start writing your chapter here...</p>',
            order: 0,
          ),
        ],
      );
    }

    // 3. Fix chapters
    final repairedChapters = <ProjectChapter>[];
    for (int i = 0; i < fixed.chapters.length; i++) {
      var ch = fixed.chapters[i];
      var html = ch.contentHtml;

      // Fix empty title
      if (ch.title.trim().isEmpty) {
        ch = ch.copyWith(title: 'Chapter ${i + 1}');
      }

      // Fix unescaped ampersands
      html = html.replaceAllMapped(
        RegExp(r'&(?!(amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)'),
        (_) => '&amp;',
      );

      // Auto-close open tags
      html = _repairUnclosedTags(html);

      repairedChapters.add(ch.copyWith(contentHtml: html));
    }

    return fixed.copyWith(
      chapters: repairedChapters,
      modifiedTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static List<String> _findUnclosedTags(String html) {
    final tags = ['p', 'div', 'span', 'b', 'i', 'em', 'strong', 'h1', 'h2', 'h3', 'h4', 'blockquote', 'li', 'ul', 'ol'];
    final unclosed = <String>[];

    for (final tag in tags) {
      final openCount = RegExp('<$tag(?:\\s+[^>]*)?>', caseSensitive: false).allMatches(html).length;
      final closeCount = RegExp('</$tag>', caseSensitive: false).allMatches(html).length;
      if (openCount > closeCount) {
        unclosed.add(tag);
      }
    }

    return unclosed;
  }

  static String _repairUnclosedTags(String html) {
    var out = html;

    // Standardize void elements for XHTML
    out = out.replaceAll(RegExp(r'<br(?!\s*/)>', caseSensitive: false), '<br />');
    out = out.replaceAll(RegExp(r'<hr(?!\s*/)>', caseSensitive: false), '<hr />');

    const voidElements = {'br', 'hr', 'img', 'meta', 'link', 'input'};
    final tagRegex = RegExp(r'<(/)?([a-zA-Z0-9]+)(?:\s+[^>]*)?(/)?>');
    final stack = <String>[];

    for (final match in tagRegex.allMatches(out)) {
      final isClosing = match.group(1) == '/';
      final tagName = match.group(2)!.toLowerCase();
      final isSelfClosing = match.group(3) == '/';

      if (voidElements.contains(tagName) || isSelfClosing) continue;

      if (isClosing) {
        if (stack.contains(tagName)) {
          while (stack.isNotEmpty) {
            final popped = stack.removeLast();
            if (popped == tagName) break;
          }
        }
      } else {
        stack.add(tagName);
      }
    }

    final closingBuffer = StringBuffer();
    while (stack.isNotEmpty) {
      closingBuffer.write('</${stack.removeLast()}>');
    }

    return out + closingBuffer.toString();
  }
}
