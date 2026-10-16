class Chapter {
  final int index;
  final String title;
  final String plainTextContent;
  final String htmlContent;
  final int wordCount;
  final List<String> imageSrcs;

  const Chapter({
    required this.index,
    required this.title,
    required this.plainTextContent,
    required this.htmlContent,
    required this.wordCount,
    this.imageSrcs = const [],
  });

  factory Chapter.fromHtml({
    required int index,
    required String title,
    required String htmlContent,
    required String plainTextContent,
    List<String> imageSrcs = const [],
  }) {
    final words = plainTextContent.trim().isEmpty
        ? 0
        : plainTextContent.trim().split(RegExp(r'\s+')).length;
    return Chapter(
      index: index,
      title: title,
      plainTextContent: plainTextContent,
      htmlContent: htmlContent,
      wordCount: words,
      imageSrcs: imageSrcs,
    );
  }
}
