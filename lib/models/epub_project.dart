import 'dart:convert';

class ProjectChapter {
  final String id;
  final String title;
  final String contentHtml;
  final String contentMarkdown;
  final int order;
  final String? href;

  const ProjectChapter({
    required this.id,
    required this.title,
    required this.contentHtml,
    this.contentMarkdown = '',
    required this.order,
    this.href,
  });

  int get wordCount {
    final clean = contentHtml.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    if (clean.isEmpty) return 0;
    return clean.split(RegExp(r'\s+')).length;
  }

  ProjectChapter copyWith({
    String? id,
    String? title,
    String? contentHtml,
    String? contentMarkdown,
    int? order,
    String? href,
  }) {
    return ProjectChapter(
      id: id ?? this.id,
      title: title ?? this.title,
      contentHtml: contentHtml ?? this.contentHtml,
      contentMarkdown: contentMarkdown ?? this.contentMarkdown,
      order: order ?? this.order,
      href: href ?? this.href,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'contentHtml': contentHtml,
        'contentMarkdown': contentMarkdown,
        'order': order,
        'href': href,
      };

  factory ProjectChapter.fromMap(Map<String, dynamic> map) => ProjectChapter(
        id: map['id'] as String? ?? 'ch_${DateTime.now().millisecondsSinceEpoch}',
        title: map['title'] as String? ?? 'Chapter',
        contentHtml: map['contentHtml'] as String? ?? '',
        contentMarkdown: map['contentMarkdown'] as String? ?? '',
        order: (map['order'] as num?)?.toInt() ?? 0,
        href: map['href'] as String?,
      );
}

class EpubProject {
  final String id;
  final String title;
  final String author;
  final String language;
  final String identifier; // UUID or ISBN
  final String description;
  final String publisher;
  final String rights;
  final String? coverImagePath;
  final String customCss;
  final List<ProjectChapter> chapters;
  final int createdTimestamp;
  final int modifiedTimestamp;

  const EpubProject({
    required this.id,
    required this.title,
    required this.author,
    this.language = 'en',
    required this.identifier,
    this.description = '',
    this.publisher = 'Epilogue Studio',
    this.rights = 'All rights reserved.',
    this.coverImagePath,
    this.customCss = '',
    this.chapters = const [],
    required this.createdTimestamp,
    required this.modifiedTimestamp,
  });

  int get totalWords => chapters.fold(0, (sum, ch) => sum + ch.wordCount);

  EpubProject copyWith({
    String? id,
    String? title,
    String? author,
    String? language,
    String? identifier,
    String? description,
    String? publisher,
    String? rights,
    String? coverImagePath,
    String? customCss,
    List<ProjectChapter>? chapters,
    int? createdTimestamp,
    int? modifiedTimestamp,
  }) {
    return EpubProject(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      language: language ?? this.language,
      identifier: identifier ?? this.identifier,
      description: description ?? this.description,
      publisher: publisher ?? this.publisher,
      rights: rights ?? this.rights,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      customCss: customCss ?? this.customCss,
      chapters: chapters ?? this.chapters,
      createdTimestamp: createdTimestamp ?? this.createdTimestamp,
      modifiedTimestamp: modifiedTimestamp ?? this.modifiedTimestamp,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'language': language,
        'identifier': identifier,
        'description': description,
        'publisher': publisher,
        'rights': rights,
        'coverImagePath': coverImagePath,
        'customCss': customCss,
        'chapters': chapters.map((c) => c.toMap()).toList(),
        'createdTimestamp': createdTimestamp,
        'modifiedTimestamp': modifiedTimestamp,
      };

  factory EpubProject.fromMap(Map<String, dynamic> map) => EpubProject(
        id: map['id'] as String? ?? 'proj_${DateTime.now().millisecondsSinceEpoch}',
        title: map['title'] as String? ?? 'Untitled Book',
        author: map['author'] as String? ?? 'Anonymous',
        language: map['language'] as String? ?? 'en',
        identifier: map['identifier'] as String? ?? 'urn:uuid:${DateTime.now().millisecondsSinceEpoch}',
        description: map['description'] as String? ?? '',
        publisher: map['publisher'] as String? ?? 'Epilogue Studio',
        rights: map['rights'] as String? ?? 'All rights reserved.',
        coverImagePath: map['coverImagePath'] as String?,
        customCss: map['customCss'] as String? ?? '',
        chapters: (map['chapters'] as List<dynamic>?)
                ?.map((c) => ProjectChapter.fromMap(c as Map<String, dynamic>))
                .toList() ??
            [],
        createdTimestamp: (map['createdTimestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        modifiedTimestamp: (map['modifiedTimestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );

  String toJson() => jsonEncode(toMap());
  factory EpubProject.fromJson(String source) =>
      EpubProject.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
