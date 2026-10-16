import 'dart:convert';

class BookHighlight {
  final String id;
  final String bookId;
  final String bookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final String selectedText;
  final String note;
  final String colorHex; // '#06B6D4' (Cyan), '#F59E0B' (Gold), '#EF4444' (Crimson), '#10B981' (Emerald), '#8B5CF6' (Violet)
  final int timestamp;

  const BookHighlight({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.selectedText,
    this.note = '',
    this.colorHex = '#06B6D4',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'selectedText': selectedText,
      'note': note,
      'colorHex': colorHex,
      'timestamp': timestamp,
    };
  }

  factory BookHighlight.fromMap(Map<String, dynamic> map) {
    return BookHighlight(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      bookTitle: map['bookTitle'] as String? ?? 'Unknown Novel',
      chapterIndex: (map['chapterIndex'] as num?)?.toInt() ?? 0,
      chapterTitle: map['chapterTitle'] as String? ?? 'Chapter',
      selectedText: map['selectedText'] as String? ?? '',
      note: map['note'] as String? ?? '',
      colorHex: map['colorHex'] as String? ?? '#06B6D4',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BookHighlight.fromJson(String source) =>
      BookHighlight.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
