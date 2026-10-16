import 'dart:convert';

/// Represents user progression in the Star Stream / ORV system.
class OrvState {
  final String incarnationName;
  final int coins;
  final String constellationModifier;
  final List<String> unlockedModifiers;
  final List<String> completedScenarioIds;
  final List<String> acquiredFables;
  final String equippedFable;
  final String equippedAttribute;
  final List<String> unlockedAttributes;
  final String? customAvatarPath;
  final String presetAvatarId; // 'dokja', 'joonghyuk', 'sooyoung', 'bihyung'

  // Manual migration offsets (from previous apps)
  final int manualPastSeconds;
  final int manualPastWords;
  final int manualPastVolumes;
  final int manualPastPages;

  const OrvState({
    this.incarnationName = 'Unnamed Incarnation',
    this.coins = 0,
    this.constellationModifier = '',
    this.unlockedModifiers = const [],
    this.completedScenarioIds = const [],
    this.acquiredFables = const [],
    this.equippedFable = '',
    this.equippedAttribute = '',
    this.unlockedAttributes = const [],
    this.customAvatarPath,
    this.presetAvatarId = 'dokja',
    this.manualPastSeconds = 0,
    this.manualPastWords = 0,
    this.manualPastVolumes = 0,
    this.manualPastPages = 0,
  });

  OrvState copyWith({
    String? incarnationName,
    int? coins,
    String? constellationModifier,
    List<String>? unlockedModifiers,
    List<String>? completedScenarioIds,
    List<String>? acquiredFables,
    String? equippedFable,
    String? equippedAttribute,
    List<String>? unlockedAttributes,
    String? customAvatarPath,
    String? presetAvatarId,
    int? manualPastSeconds,
    int? manualPastWords,
    int? manualPastVolumes,
    int? manualPastPages,
  }) {
    return OrvState(
      incarnationName: incarnationName ?? this.incarnationName,
      coins: coins ?? this.coins,
      constellationModifier: constellationModifier ?? this.constellationModifier,
      unlockedModifiers: unlockedModifiers ?? this.unlockedModifiers,
      completedScenarioIds: completedScenarioIds ?? this.completedScenarioIds,
      acquiredFables: acquiredFables ?? this.acquiredFables,
      equippedFable: equippedFable ?? this.equippedFable,
      equippedAttribute: equippedAttribute ?? this.equippedAttribute,
      unlockedAttributes: unlockedAttributes ?? this.unlockedAttributes,
      customAvatarPath: customAvatarPath ?? this.customAvatarPath,
      presetAvatarId: presetAvatarId ?? this.presetAvatarId,
      manualPastSeconds: manualPastSeconds ?? this.manualPastSeconds,
      manualPastWords: manualPastWords ?? this.manualPastWords,
      manualPastVolumes: manualPastVolumes ?? this.manualPastVolumes,
      manualPastPages: manualPastPages ?? this.manualPastPages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incarnationName': incarnationName,
      'coins': coins,
      'constellationModifier': constellationModifier,
      'unlockedModifiers': unlockedModifiers,
      'completedScenarioIds': completedScenarioIds,
      'acquiredFables': acquiredFables,
      'equippedFable': equippedFable,
      'equippedAttribute': equippedAttribute,
      'unlockedAttributes': unlockedAttributes,
      'customAvatarPath': customAvatarPath,
      'presetAvatarId': presetAvatarId,
      'manualPastSeconds': manualPastSeconds,
      'manualPastWords': manualPastWords,
      'manualPastVolumes': manualPastVolumes,
      'manualPastPages': manualPastPages,
    };
  }

  factory OrvState.fromMap(Map<String, dynamic> map) {
    return OrvState(
      incarnationName: map['incarnationName'] as String? ?? 'Unnamed Incarnation',
      coins: map['coins'] as int? ?? 0,
      constellationModifier: map['constellationModifier'] as String? ?? '',
      unlockedModifiers: List<String>.from(map['unlockedModifiers'] ?? []),
      completedScenarioIds: List<String>.from(map['completedScenarioIds'] ?? []),
      acquiredFables: List<String>.from(map['acquiredFables'] ?? []),
      equippedFable: map['equippedFable'] as String? ?? '',
      equippedAttribute: map['equippedAttribute'] as String? ?? '',
      unlockedAttributes: List<String>.from(map['unlockedAttributes'] ?? []),
      customAvatarPath: map['customAvatarPath'] as String?,
      presetAvatarId: map['presetAvatarId'] as String? ?? 'dokja',
      manualPastSeconds: map['manualPastSeconds'] as int? ?? 0,
      manualPastWords: map['manualPastWords'] as int? ?? 0,
      manualPastVolumes: map['manualPastVolumes'] as int? ?? 0,
      manualPastPages: map['manualPastPages'] as int? ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory OrvState.fromJson(String source) =>
      OrvState.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
