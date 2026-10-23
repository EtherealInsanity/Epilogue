class Chapter {
  final int index;
  final String title;
  final String plainTextContent;
  final String htmlContent;
  final int wordCount;
  final List<String> imageSrcs;
  final bool isLoaded;

  const Chapter({
    required this.index,
    required this.title,
    required this.plainTextContent,
    required this.htmlContent,
    required this.wordCount,
    this.imageSrcs = const [],
    this.isLoaded = true,
  });

  factory Chapter.fromHtml({
    required int index,
    required String title,
    required String htmlContent,
    required String plainTextContent,
    List<String> imageSrcs = const [],
    bool isLoaded = true,
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
      isLoaded: isLoaded,
    );
  }

  factory Chapter.placeholder({
    required int index,
    required String title,
  }) {
    return Chapter(
      index: index,
      title: title,
      plainTextContent: '',
      htmlContent: '',
      wordCount: 0,
      imageSrcs: const [],
      isLoaded: false,
    );
  }
}
