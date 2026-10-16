import 'dart:convert';

class DailyReadingRecord {
  final String dateKey; // Format: 'YYYY-MM-DD'
  final int totalSeconds;
  final int totalWords;
  final int chaptersCompleted;

  const DailyReadingRecord({
    required this.dateKey,
    required this.totalSeconds,
    required this.totalWords,
    this.chaptersCompleted = 0,
  });

  DailyReadingRecord copyWith({
    String? dateKey,
    int? totalSeconds,
    int? totalWords,
    int? chaptersCompleted,
  }) {
    return DailyReadingRecord(
      dateKey: dateKey ?? this.dateKey,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      totalWords: totalWords ?? this.totalWords,
      chaptersCompleted: chaptersCompleted ?? this.chaptersCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'totalSeconds': totalSeconds,
      'totalWords': totalWords,
      'chaptersCompleted': chaptersCompleted,
    };
  }

  factory DailyReadingRecord.fromMap(Map<String, dynamic> map) {
    return DailyReadingRecord(
      dateKey: map['dateKey'] as String,
      totalSeconds: (map['totalSeconds'] as num?)?.toInt() ?? 0,
      totalWords: (map['totalWords'] as num?)?.toInt() ?? 0,
      chaptersCompleted: (map['chaptersCompleted'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DailyReadingRecord.fromJson(String source) =>
      DailyReadingRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
