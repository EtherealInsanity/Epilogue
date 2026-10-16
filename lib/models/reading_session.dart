import 'dart:convert';

class ReadingSession {
  final String id;
  final String bookId;
  final String bookTitle;
  final int startTimeMillis;
  final int endTimeMillis;
  final int durationSeconds;
  final int wordsRead;
  final int calculatedWpm;

  const ReadingSession({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.startTimeMillis,
    required this.endTimeMillis,
    required this.durationSeconds,
    required this.wordsRead,
    required this.calculatedWpm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'startTimeMillis': startTimeMillis,
      'endTimeMillis': endTimeMillis,
      'durationSeconds': durationSeconds,
      'wordsRead': wordsRead,
      'calculatedWpm': calculatedWpm,
    };
  }

  factory ReadingSession.fromMap(Map<String, dynamic> map) {
    return ReadingSession(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      bookTitle: map['bookTitle'] as String? ?? 'Unknown Novel',
      startTimeMillis: (map['startTimeMillis'] as num?)?.toInt() ?? 0,
      endTimeMillis: (map['endTimeMillis'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      wordsRead: (map['wordsRead'] as num?)?.toInt() ?? 0,
      calculatedWpm: (map['calculatedWpm'] as num?)?.toInt() ?? 220,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ReadingSession.fromJson(String source) =>
      ReadingSession.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
