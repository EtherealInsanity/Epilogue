import 'dart:convert';

class Bookmark {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final double scrollOffset;
  final String snippet;
  final int timestamp;

  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.scrollOffset,
    required this.snippet,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'scrollOffset': scrollOffset,
      'snippet': snippet,
      'timestamp': timestamp,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      chapterIndex: (map['chapterIndex'] as num?)?.toInt() ?? 0,
      chapterTitle: map['chapterTitle'] as String? ?? '',
      scrollOffset: (map['scrollOffset'] as num?)?.toDouble() ?? 0.0,
      snippet: map['snippet'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Bookmark.fromJson(String source) =>
      Bookmark.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
