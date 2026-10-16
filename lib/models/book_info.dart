import 'dart:convert';

class BookInfo {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final int fileSizeBytes;
  final int totalChapters;
  final int lastReadChapterIndex;
  final double lastReadProgressPercent; // 0.0 to 100.0
  final int? lastReadTimestamp;
  final int? addedTimestamp;
  final int totalSecondsSpentReading;
  final int totalWordsRead;
  final String? coverImagePath;

  const BookInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.fileSizeBytes = 0,
    this.totalChapters = 0,
    this.lastReadChapterIndex = 0,
    this.lastReadProgressPercent = 0.0,
    this.lastReadTimestamp,
    this.addedTimestamp,
    this.totalSecondsSpentReading = 0,
    this.totalWordsRead = 0,
    this.coverImagePath,
  });

  BookInfo copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    int? fileSizeBytes,
    int? totalChapters,
    int? lastReadChapterIndex,
    double? lastReadProgressPercent,
    int? lastReadTimestamp,
    int? addedTimestamp,
    int? totalSecondsSpentReading,
    int? totalWordsRead,
    String? coverImagePath,
  }) {
    return BookInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      totalChapters: totalChapters ?? this.totalChapters,
      lastReadChapterIndex: lastReadChapterIndex ?? this.lastReadChapterIndex,
      lastReadProgressPercent:
          lastReadProgressPercent ?? this.lastReadProgressPercent,
      lastReadTimestamp: lastReadTimestamp ?? this.lastReadTimestamp,
      addedTimestamp: addedTimestamp ?? this.addedTimestamp,
      totalSecondsSpentReading:
          totalSecondsSpentReading ?? this.totalSecondsSpentReading,
      totalWordsRead: totalWordsRead ?? this.totalWordsRead,
      coverImagePath: coverImagePath ?? this.coverImagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'totalChapters': totalChapters,
      'lastReadChapterIndex': lastReadChapterIndex,
      'lastReadProgressPercent': lastReadProgressPercent,
      'lastReadTimestamp': lastReadTimestamp,
      'addedTimestamp': addedTimestamp,
      'totalSecondsSpentReading': totalSecondsSpentReading,
      'totalWordsRead': totalWordsRead,
      'coverImagePath': coverImagePath,
    };
  }

  factory BookInfo.fromMap(Map<String, dynamic> map) {
    return BookInfo(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled',
      author: map['author'] as String? ?? 'Unknown Author',
      filePath: map['filePath'] as String,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      totalChapters: (map['totalChapters'] as num?)?.toInt() ?? 0,
      lastReadChapterIndex:
          (map['lastReadChapterIndex'] as num?)?.toInt() ?? 0,
      lastReadProgressPercent:
          (map['lastReadProgressPercent'] as num?)?.toDouble() ?? 0.0,
      lastReadTimestamp: (map['lastReadTimestamp'] as num?)?.toInt(),
      addedTimestamp: (map['addedTimestamp'] as num?)?.toInt(),
      totalSecondsSpentReading:
          (map['totalSecondsSpentReading'] as num?)?.toInt() ?? 0,
      totalWordsRead: (map['totalWordsRead'] as num?)?.toInt() ?? 0,
      coverImagePath: map['coverImagePath'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BookInfo.fromJson(String source) =>
      BookInfo.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
