import 'dart:convert';

class BookShelf {
  final String id;
  final String name;
  final List<String> bookIds;
  final bool isSystem;

  const BookShelf({
    required this.id,
    required this.name,
    this.bookIds = const [],
    this.isSystem = false,
  });

  BookShelf copyWith({
    String? id,
    String? name,
    List<String>? bookIds,
    bool? isSystem,
  }) {
    return BookShelf(
      id: id ?? this.id,
      name: name ?? this.name,
      bookIds: bookIds ?? this.bookIds,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bookIds': bookIds,
      'isSystem': isSystem,
    };
  }

  factory BookShelf.fromMap(Map<String, dynamic> map) {
    return BookShelf(
      id: map['id'] as String,
      name: map['name'] as String,
      bookIds: List<String>.from(map['bookIds'] ?? []),
      isSystem: map['isSystem'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BookShelf.fromJson(String source) =>
      BookShelf.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static List<BookShelf> defaultShelves() {
    return [
      const BookShelf(id: 'all', name: 'All', isSystem: true),
      const BookShelf(id: 'reading', name: 'Currently Reading', isSystem: true),
      const BookShelf(id: 'plan_to_read', name: 'Plan to Read', isSystem: true),
      const BookShelf(id: 'completed', name: 'Completed', isSystem: true),
      const BookShelf(id: 'favorites', name: 'Favorites', isSystem: true),
    ];
  }
}
