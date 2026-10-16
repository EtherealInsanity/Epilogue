import 'dart:convert';

enum CanonGrade {
  general,
  narrative,
  myth,
  transcendent,
}

extension CanonGradeExtension on CanonGrade {
  String get label {
    switch (this) {
      case CanonGrade.general:
        return 'General Grade';
      case CanonGrade.narrative:
        return 'Narrative Grade';
      case CanonGrade.myth:
        return 'Myth Grade';
      case CanonGrade.transcendent:
        return 'Transcendent ■■';
    }
  }

  String get shortLabel {
    switch (this) {
      case CanonGrade.general:
        return 'General';
      case CanonGrade.narrative:
        return 'Narrative';
      case CanonGrade.myth:
        return 'Myth';
      case CanonGrade.transcendent:
        return '■■ Transcendent';
    }
  }
}

enum CanonItemType {
  modifier,
  fable,
  attribute,
}

class OrvCanonItem {
  final String id;
  final String name;
  final CanonItemType type;
  final CanonGrade grade;
  final int coinCost;
  final bool isPurchasable;
  final String? unlockScenarioId;
  final String? description;

  const OrvCanonItem({
    required this.id,
    required this.name,
    required this.type,
    required this.grade,
    required this.coinCost,
    this.isPurchasable = true,
    this.unlockScenarioId,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'grade': grade.name,
      'coinCost': coinCost,
      'isPurchasable': isPurchasable,
      'unlockScenarioId': unlockScenarioId,
      'description': description,
    };
  }

  factory OrvCanonItem.fromMap(Map<String, dynamic> map) {
    return OrvCanonItem(
      id: map['id'] as String,
      name: map['name'] as String,
      type: CanonItemType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CanonItemType.modifier,
      ),
      grade: CanonGrade.values.firstWhere(
        (e) => e.name == map['grade'],
        orElse: () => CanonGrade.general,
      ),
      coinCost: (map['coinCost'] as num?)?.toInt() ?? 1000,
      isPurchasable: map['isPurchasable'] as bool? ?? true,
      unlockScenarioId: map['unlockScenarioId'] as String?,
      description: map['description'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory OrvCanonItem.fromJson(String source) =>
      OrvCanonItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
