import 'dart:math';
import '../models/orv_canon_item.dart';
import '../models/scenario.dart';
import 'storage_service.dart';

class ConstellationEvent {
  final String modifier;
  final String message;
  final int coinsSponsored;

  const ConstellationEvent({
    required this.modifier,
    required this.message,
    this.coinsSponsored = 0,
  });
}

class OrvService {
  final StorageService storageService;

  OrvService(this.storageService);

  // ==========================================
  // 4-TIER CANON HIERARCHY FOR MODIFIERS
  // ==========================================

  static const List<OrvCanonItem> allModifiersWithTiers = [
    // --- TRANSCENDENT ■■ (Strictly Unbuyable, Scenario Locked) ---
    OrvCanonItem(
      id: 'Demon King of Salvation',
      name: 'Demon King of Salvation',
      type: CanonItemType.modifier,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_10',
      description: 'The constellation of salvation who sacrifices himself for the single story.',
    ),
    OrvCanonItem(
      id: 'The Oldest Dream',
      name: 'The Oldest Dream',
      type: CanonItemType.modifier,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_23',
      description: 'The ancient god who dreams the worldlines into existence through reading.',
    ),
    OrvCanonItem(
      id: 'Secretive Plotter',
      name: 'Secretive Plotter',
      type: CanonItemType.modifier,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'hidden_secretive_plotter',
      description: 'The lonely regressor of 1,863 rounds who reached the outside of the world.',
    ),
    OrvCanonItem(
      id: 'Architect of the False Last Act',
      name: 'Architect of the False Last Act',
      type: CanonItemType.modifier,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'hidden_false_act',
      description: 'The author who rewrote the world to keep that one reader alive.',
    ),
    OrvCanonItem(
      id: 'Breaker of the Fourth Wall',
      name: 'Breaker of the Fourth Wall',
      type: CanonItemType.modifier,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_18',
      description: 'The incarnation who shattered the boundary between reader and story.',
    ),
    OrvCanonItem(
      id: 'Eternal Epilogue',
      name: 'Eternal Epilogue',
      type: CanonItemType.modifier,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_25',
      description: 'The final conclusion written for the eternity of the Star Stream.',
    ),

    // --- MYTH GRADE (1,000,000 - 5,000,000 Coins) ---
    OrvCanonItem(
      id: 'Abyssal Black Flame Dragon',
      name: 'Abyssal Black Flame Dragon',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 2500000,
      description: 'Leader of Black Cloud, sovereign of chuunibyou flame and catastrophic darkness.',
    ),
    OrvCanonItem(
      id: 'Demon-like Judge of Fire',
      name: 'Demon-like Judge of Fire',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 2000000,
      description: 'Archangel Uriel, righteous observer and protector of true companionship.',
    ),
    OrvCanonItem(
      id: 'Prisoner of the Golden Headband',
      name: 'Prisoner of the Golden Headband',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 3500000,
      description: 'The Great Sage Equal to Heaven, Sun Wukong.',
    ),
    OrvCanonItem(
      id: 'Queen of the Darkest Spring',
      name: 'Queen of the Darkest Spring',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 1800000,
      description: 'Persephone, sovereign of the Underworld and beloved patron of Kim Dokja.',
    ),
    OrvCanonItem(
      id: 'Father of the Rich Night',
      name: 'Father of the Rich Night',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 1900000,
      description: 'Hades, Lord of the Underworld.',
    ),
    OrvCanonItem(
      id: 'Supreme God of Light',
      name: 'Supreme God of Light',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 3000000,
      description: 'Surya, master of solar chariot and celestial radiance.',
    ),
    OrvCanonItem(
      id: 'God-King of Thunderbolt',
      name: 'God-King of Thunderbolt',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 3200000,
      description: 'Indra, sovereign of the heavenly realm of Vedas.',
    ),
    OrvCanonItem(
      id: 'First-person Omniscient Reader',
      name: 'First-person Omniscient Reader',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 1500000,
      description: 'The one who views the universe through the eyes of the protagonist.',
    ),
    OrvCanonItem(
      id: 'Dragon of the Apocalypse',
      name: 'Dragon of the Apocalypse',
      type: CanonItemType.modifier,
      grade: CanonGrade.myth,
      coinCost: 4500000,
      description: 'The apocalypse calamity of the Book of Revelation.',
    ),

    // --- NARRATIVE GRADE (150,000 - 500,000 Coins) ---
    OrvCanonItem(
      id: 'Maritime War God',
      name: 'Maritime War God',
      type: CanonItemType.modifier,
      grade: CanonGrade.narrative,
      coinCost: 350000,
      description: 'Duke of Loyalty and Warfare, Yi Sun-sin.',
    ),
    OrvCanonItem(
      id: 'Bald General of Justice',
      name: 'Bald General of Justice',
      type: CanonItemType.modifier,
      grade: CanonGrade.narrative,
      coinCost: 200000,
      description: 'Samyeongdang, patriotic Buddhist monk commander.',
    ),
    OrvCanonItem(
      id: 'Master of Steel',
      name: 'Master of Steel',
      type: CanonItemType.modifier,
      grade: CanonGrade.narrative,
      coinCost: 300000,
      description: 'Sovereign of metallurgical alchemy and invincible armor.',
    ),
    OrvCanonItem(
      id: 'Goddess of Love and Cats',
      name: 'Goddess of Love and Cats',
      type: CanonItemType.modifier,
      grade: CanonGrade.narrative,
      coinCost: 250000,
      description: 'Bastet of the Egyptian Nebula.',
    ),
    OrvCanonItem(
      id: 'God of Wine and Ecstasy',
      name: 'God of Wine and Ecstasy',
      type: CanonItemType.modifier,
      grade: CanonGrade.narrative,
      coinCost: 280000,
      description: 'Dionysus of Olympus, connoisseur of the Gourmet Association.',
    ),
    OrvCanonItem(
      id: 'Slumbering Lady of Fine Brocade',
      name: 'Slumbering Lady of Fine Brocade',
      type: CanonItemType.modifier,
      grade: CanonGrade.narrative,
      coinCost: 220000,
      description: 'Goddess of the Korean Peninsula constellations.',
    ),
    OrvCanonItem(
      id: 'Morning Star Goddess',
      name: 'Morning Star Goddess',
      type: CanonItemType.modifier,
      grade: CanonGrade.narrative,
      coinCost: 400000,
      description: 'The star of dawn rising over Eden.',
    ),
    OrvCanonItem(
      id: 'Master of Abydos',
      name: 'Master of Abydos',
      type: CanonItemType.modifier,
      grade: CanonGrade.narrative,
      coinCost: 320000,
      description: 'Ancient Egyptian ruler of the sacred necropolis.',
    ),

    // --- GENERAL GRADE (10,000 - 50,000 Coins) ---
    OrvCanonItem(
      id: 'King of Archers',
      name: 'King of Archers',
      type: CanonItemType.modifier,
      grade: CanonGrade.general,
      coinCost: 25000,
      description: 'Sharpshooter of ancient Korean historical myths.',
    ),
    OrvCanonItem(
      id: 'King of Beauty',
      name: 'King of Beauty',
      type: CanonItemType.modifier,
      grade: CanonGrade.general,
      coinCost: 30000,
      description: 'Historical figure renowned across eras for peerless charm.',
    ),
    OrvCanonItem(
      id: 'Master of Defense',
      name: 'Master of Defense',
      type: CanonItemType.modifier,
      grade: CanonGrade.general,
      coinCost: 15000,
      description: 'Shield-bearer of frontline fortification.',
    ),
    OrvCanonItem(
      id: 'Black Sword Assassin',
      name: 'Black Sword Assassin',
      type: CanonItemType.modifier,
      grade: CanonGrade.general,
      coinCost: 20000,
      description: 'Silent blade operating from the darkness of Seoul.',
    ),
    OrvCanonItem(
      id: 'Founder of Hangul',
      name: 'Founder of Hangul',
      type: CanonItemType.modifier,
      grade: CanonGrade.general,
      coinCost: 50000,
      description: 'King Sejong the Great, creator of written language.',
    ),
    OrvCanonItem(
      id: 'Guam Divine Doctor',
      name: 'Guam Divine Doctor',
      type: CanonItemType.modifier,
      grade: CanonGrade.general,
      coinCost: 40000,
      description: 'Heo Jun, author of Dongui Bogam.',
    ),
    OrvCanonItem(
      id: 'Goryeo\'s First Sword',
      name: 'Goryeo\'s First Sword',
      type: CanonItemType.modifier,
      grade: CanonGrade.general,
      coinCost: 45000,
      description: 'Cheok Jun-gyeong, invincible battlefield warrior.',
    ),
    OrvCanonItem(
      id: 'Mass Production Maker',
      name: 'Mass Production Maker',
      type: CanonItemType.modifier,
      grade: CanonGrade.general,
      coinCost: 35000,
      description: 'Manufacturer of the Ferrarigini and consumer Star Stream relics.',
    ),
  ];

  static List<String> get allCanonModifiers =>
      allModifiersWithTiers.map((m) => m.name).toList();

  // ==========================================
  // 4-TIER CANON HIERARCHY FOR FABLES
  // ==========================================

  static const List<OrvCanonItem> allFablesWithTiers = [
    // --- TRANSCENDENT ■■ FABLES ---
    OrvCanonItem(
      id: 'One Who Began the Journey',
      name: 'One Who Began the Journey',
      type: CanonItemType.fable,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_01',
      description: 'The foundation story of opening the first page in the ruined world.',
    ),
    OrvCanonItem(
      id: 'The Oldest Dream',
      name: 'The Oldest Dream',
      type: CanonItemType.fable,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_23',
      description: 'A story of a child reading alone on a subway for eternity.',
    ),
    OrvCanonItem(
      id: 'Eternity and the Epilogue',
      name: 'Eternity and the Epilogue',
      type: CanonItemType.fable,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_25',
      description: 'The culmination of all stories that reached beyond the final wall.',
    ),
    OrvCanonItem(
      id: 'Life and Death Companions',
      name: 'Life and Death Companions',
      type: CanonItemType.fable,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'hidden_orv_canon_complete',
      description: 'The unbreakable bond between reader, protagonist, and writer.',
    ),

    // --- MYTH GRADE FABLES (1,000,000 - 5,000,000 Coins) ---
    OrvCanonItem(
      id: 'Torch That Swallowed the Myth',
      name: 'Torch That Swallowed the Myth',
      type: CanonItemType.fable,
      grade: CanonGrade.myth,
      coinCost: 2000000,
      description: 'The sacred fire ignited during the Fall of Olympus.',
    ),
    OrvCanonItem(
      id: 'Liberator of Giants',
      name: 'Liberator of Giants',
      type: CanonItemType.fable,
      grade: CanonGrade.myth,
      coinCost: 1800000,
      description: 'The fable acquired upon shattering the chains of the Titans in Gigantomachia.',
    ),
    OrvCanonItem(
      id: 'Season of Light and Darkness',
      name: 'Season of Light and Darkness',
      type: CanonItemType.fable,
      grade: CanonGrade.myth,
      coinCost: 2500000,
      description: 'The apocalyptic fable born during the Great War of Saints and Demons.',
    ),
    OrvCanonItem(
      id: 'One Who Slew the Absolute',
      name: 'One Who Slew the Absolute',
      type: CanonItemType.fable,
      grade: CanonGrade.myth,
      coinCost: 3500000,
      description: 'Proof of defying and crushing the Absolute Throne.',
    ),

    // --- NARRATIVE GRADE FABLES (150,000 - 500,000 Coins) ---
    OrvCanonItem(
      id: 'King of a Kingless World',
      name: 'King of a Kingless World',
      type: CanonItemType.fable,
      grade: CanonGrade.narrative,
      coinCost: 300000,
      description: 'The monarch who stood tall by refusing to sit upon the absolute throne.',
    ),
    OrvCanonItem(
      id: 'Spring of the Demon Realm',
      name: 'Spring of the Demon Realm',
      type: CanonItemType.fable,
      grade: CanonGrade.narrative,
      coinCost: 400000,
      description: 'The bloom of revolution in the 73rd Industrial Complex.',
    ),
    OrvCanonItem(
      id: 'Bug Slaughterer',
      name: 'Bug Slaughterer',
      type: CanonItemType.fable,
      grade: CanonGrade.narrative,
      coinCost: 150000,
      description: 'The legend born in Subway Car 3807 when lives were measured in insects.',
    ),
    OrvCanonItem(
      id: 'Witness of the 999th Turn',
      name: 'Witness of the 999th Turn',
      type: CanonItemType.fable,
      grade: CanonGrade.narrative,
      coinCost: 500000,
      description: 'Remembrance of the worldline that reached the end before regression.',
    ),

    // --- GENERAL GRADE FABLES (10,000 - 50,000 Coins) ---
    OrvCanonItem(
      id: 'Witness of the First Encounter',
      name: 'Witness of the First Encounter',
      type: CanonItemType.fable,
      grade: CanonGrade.general,
      coinCost: 20000,
      description: 'Meeting the protagonist on the Dongho Bridge.',
    ),
    OrvCanonItem(
      id: 'Survivor of the Han River',
      name: 'Survivor of the Han River',
      type: CanonItemType.fable,
      grade: CanonGrade.general,
      coinCost: 15000,
      description: 'Surviving the aquatic ichthyosaur calamity.',
    ),
    OrvCanonItem(
      id: 'Next City',
      name: 'Next City',
      type: CanonItemType.fable,
      grade: CanonGrade.general,
      coinCost: 30000,
      description: 'Marching through the ruins of Seoul into the greater scenario.',
    ),
  ];

  static List<String> get allCanonFables =>
      allFablesWithTiers.map((f) => f.name).toList();

  // ==========================================
  // 4-TIER CANON HIERARCHY FOR ATTRIBUTES
  // ==========================================

  static const List<OrvCanonItem> allAttributesWithTiers = [
    // --- TRANSCENDENT ■■ ATTRIBUTES ---
    OrvCanonItem(
      id: 'Omniscient Reader',
      name: 'Omniscient Reader',
      type: CanonItemType.attribute,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_23',
      description: 'Exclusive skill: Understand all characters, plots, and emotional streams.',
    ),
    OrvCanonItem(
      id: 'Architect of the Final Epilogue',
      name: 'Architect of the Final Epilogue',
      type: CanonItemType.attribute,
      grade: CanonGrade.transcendent,
      coinCost: 0,
      isPurchasable: false,
      unlockScenarioId: 'main_25',
      description: 'The ability to weave multiple worldlines into a single cohesive ending.',
    ),

    // --- MYTH GRADE ATTRIBUTES (1,000,000 - 5,000,000 Coins) ---
    OrvCanonItem(
      id: 'Eight Lives',
      name: 'Eight Lives',
      type: CanonItemType.attribute,
      grade: CanonGrade.myth,
      coinCost: 2000000,
      description: 'Yamata no Orochi\'s relic blessing: resurrect eight times across death.',
    ),
    OrvCanonItem(
      id: 'Immortal Body',
      name: 'Immortal Body',
      type: CanonItemType.attribute,
      grade: CanonGrade.myth,
      coinCost: 2500000,
      description: 'Cells that regenerate infinitely through story consumption.',
    ),
    OrvCanonItem(
      id: 'Breaking the Sky Sword Saint',
      name: 'Breaking the Sky Sword Saint',
      type: CanonItemType.attribute,
      grade: CanonGrade.myth,
      coinCost: 3000000,
      description: 'Namgung Minyoung\'s supreme martial path.',
    ),

    // --- NARRATIVE GRADE ATTRIBUTES (150,000 - 500,000 Coins) ---
    OrvCanonItem(
      id: 'King of a Kingless World',
      name: 'King of a Kingless World',
      type: CanonItemType.attribute,
      grade: CanonGrade.narrative,
      coinCost: 300000,
      description: 'Absolute immunity to throne subjugation and mental domination.',
    ),
    OrvCanonItem(
      id: 'Judge of Destruction',
      name: 'Judge of Destruction',
      type: CanonItemType.attribute,
      grade: CanonGrade.narrative,
      coinCost: 350000,
      description: 'Jung Heewon\'s attribute: Ignites the Flames of Retribution against evil.',
    ),
    OrvCanonItem(
      id: 'Sound of the Wind',
      name: 'Sound of the Wind',
      type: CanonItemType.attribute,
      grade: CanonGrade.narrative,
      coinCost: 250000,
      description: 'Lee Jihye\'s fleet navigation and wind manipulation.',
    ),
    OrvCanonItem(
      id: 'Plagiarist',
      name: 'Plagiarist',
      type: CanonItemType.attribute,
      grade: CanonGrade.narrative,
      coinCost: 400000,
      description: 'Han Sooyoung\'s 1st Avatar generation and manuscript memory replication.',
    ),

    // --- GENERAL GRADE ATTRIBUTES (10,000 - 50,000 Coins) ---
    OrvCanonItem(
      id: 'Pro Gamer',
      name: 'Pro Gamer',
      type: CanonItemType.attribute,
      grade: CanonGrade.general,
      coinCost: 25000,
      description: 'Lee Gil-young and Yoo Sangah\'s hyper-cognitive reflex bonus.',
    ),
    OrvCanonItem(
      id: 'Insect Collector',
      name: 'Insect Collector',
      type: CanonItemType.attribute,
      grade: CanonGrade.general,
      coinCost: 15000,
      description: 'Telepathic command over arthropods and minor underground beasts.',
    ),
    OrvCanonItem(
      id: 'Lover of Books',
      name: 'Lover of Books',
      type: CanonItemType.attribute,
      grade: CanonGrade.general,
      coinCost: 30000,
      description: 'Passive 20% reading comprehension and word retention boost.',
    ),
  ];

  static List<String> get allCanonAttributes =>
      allAttributesWithTiers.map((a) => a.name).toList();

  // ==========================================
  // SCENARIO EVALUATION & CLAIMING
  // ==========================================

  List<Scenario> evaluateScenarios() {
    final state = storageService.loadOrvState();
    final totalWords = storageService.getTotalLibraryWordsRead() + state.manualPastWords;
    final totalSeconds = storageService.getTotalLibraryReadingSeconds() + state.manualPastSeconds;
    final books = storageService.loadBooks();
    final completedBooks = books.where((b) =>
        b.totalChapters > 0 &&
        b.lastReadChapterIndex >= b.totalChapters - 1 &&
        b.lastReadProgressPercent > 95.0).length + state.manualPastVolumes;
    final totalChaptersRead = books.fold(0, (sum, b) => sum + b.lastReadChapterIndex);
    final currentStreak = storageService.getCurrentStreakDays();

    final allScenarios = Scenario.defaultScenarios();
    final List<Scenario> claimable = [];

    for (final s in allScenarios) {
      if (state.completedScenarioIds.contains(s.id)) continue;

      // Check prerequisite scenario requirement
      if (s.requiredPrerequisiteScenarioId != null &&
          !state.completedScenarioIds.contains(s.requiredPrerequisiteScenarioId)) {
        continue;
      }

      bool isFulfilled = false;
      if (s.unit == 'chapters' && totalChaptersRead >= s.targetValue) {
        isFulfilled = true;
      } else if (s.unit == 'words' && totalWords >= s.targetValue) {
        isFulfilled = true;
      } else if (s.unit == 'seconds' && totalSeconds >= s.targetValue) {
        isFulfilled = true;
      } else if (s.unit == 'completed books' && completedBooks >= s.targetValue) {
        isFulfilled = true;
      } else if (s.unit == 'streak_days' && currentStreak >= s.targetValue) {
        isFulfilled = true;
      }

      if (isFulfilled) {
        claimable.add(s);
      }
    }
    return claimable;
  }

  Future<void> claimScenario(Scenario scenario) async {
    final state = storageService.loadOrvState();
    if (state.completedScenarioIds.contains(scenario.id)) return;

    final updatedCompleted = List<String>.from(state.completedScenarioIds)..add(scenario.id);
    final updatedFables = List<String>.from(state.acquiredFables);
    if (scenario.fableReward != null && !updatedFables.contains(scenario.fableReward)) {
      updatedFables.add(scenario.fableReward!);
    }

    final updatedUnlocked = List<String>.from(state.unlockedModifiers);
    if (scenario.fableReward != null) {
      if (allCanonModifiers.contains(scenario.fableReward) && !updatedUnlocked.contains(scenario.fableReward)) {
        updatedUnlocked.add(scenario.fableReward!);
      }
    }

    final updated = state.copyWith(
      coins: state.coins + scenario.coinReward,
      completedScenarioIds: updatedCompleted,
      acquiredFables: updatedFables,
      unlockedModifiers: updatedUnlocked,
    );
    await storageService.saveOrvState(updated);
  }

  // ==========================================
  // UNLOCKING & EQUIPPING WITH 4-TIER LOGIC
  // ==========================================

  Future<bool> equipModifier(String modifier) async {
    final state = storageService.loadOrvState();
    if (!state.unlockedModifiers.contains(modifier)) return false;
    final updated = state.copyWith(constellationModifier: modifier);
    await storageService.saveOrvState(updated);
    return true;
  }

  Future<void> setIncarnationName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final state = storageService.loadOrvState();
    final updated = state.copyWith(incarnationName: clean);
    await storageService.saveOrvState(updated);
  }

  Future<bool> unlockModifierWithCoins(String modifier) async {
    final item = allModifiersWithTiers.firstWhere(
      (m) => m.name == modifier,
      orElse: () => OrvCanonItem(
        id: modifier,
        name: modifier,
        type: CanonItemType.modifier,
        grade: CanonGrade.general,
        coinCost: 50000,
      ),
    );

    // Transcendent items cannot be purchased with coins!
    if (!item.isPurchasable || item.grade == CanonGrade.transcendent) {
      return false;
    }

    final state = storageService.loadOrvState();
    if (state.coins < item.coinCost || state.unlockedModifiers.contains(modifier)) return false;

    final updatedUnlocked = List<String>.from(state.unlockedModifiers)..add(modifier);
    final updated = state.copyWith(
      coins: state.coins - item.coinCost,
      unlockedModifiers: updatedUnlocked,
    );
    await storageService.saveOrvState(updated);
    return true;
  }

  Future<bool> equipFable(String fable) async {
    final state = storageService.loadOrvState();
    if (!state.acquiredFables.contains(fable)) return false;
    final updated = state.copyWith(equippedFable: fable);
    await storageService.saveOrvState(updated);
    return true;
  }

  Future<bool> unlockFableWithCoins(String fable) async {
    final item = allFablesWithTiers.firstWhere(
      (f) => f.name == fable,
      orElse: () => OrvCanonItem(
        id: fable,
        name: fable,
        type: CanonItemType.fable,
        grade: CanonGrade.general,
        coinCost: 50000,
      ),
    );

    if (!item.isPurchasable || item.grade == CanonGrade.transcendent) {
      return false;
    }

    final state = storageService.loadOrvState();
    if (state.coins < item.coinCost || state.acquiredFables.contains(fable)) return false;

    final updatedFables = List<String>.from(state.acquiredFables)..add(fable);
    final updated = state.copyWith(
      coins: state.coins - item.coinCost,
      acquiredFables: updatedFables,
    );
    await storageService.saveOrvState(updated);
    return true;
  }

  Future<bool> equipAttribute(String attribute) async {
    final state = storageService.loadOrvState();
    if (!state.unlockedAttributes.contains(attribute)) return false;
    final updated = state.copyWith(equippedAttribute: attribute);
    await storageService.saveOrvState(updated);
    return true;
  }

  Future<bool> unlockAttributeWithCoins(String attribute) async {
    final item = allAttributesWithTiers.firstWhere(
      (a) => a.name == attribute,
      orElse: () => OrvCanonItem(
        id: attribute,
        name: attribute,
        type: CanonItemType.attribute,
        grade: CanonGrade.general,
        coinCost: 50000,
      ),
    );

    if (!item.isPurchasable || item.grade == CanonGrade.transcendent) {
      return false;
    }

    final state = storageService.loadOrvState();
    if (state.coins < item.coinCost || state.unlockedAttributes.contains(attribute)) return false;

    final updatedAttributes = List<String>.from(state.unlockedAttributes)..add(attribute);
    final updated = state.copyWith(
      coins: state.coins - item.coinCost,
      unlockedAttributes: updatedAttributes,
    );
    await storageService.saveOrvState(updated);
    return true;
  }

  // ==========================================
  // IN-READER CONSTELLATION REACTION GENERATOR
  // ==========================================

  static final List<ConstellationEvent> _milestoneEvents = [
    const ConstellationEvent(
      modifier: 'Demon-like Judge of Fire',
      message: 'is deeply touched by your reading endurance and is wiping away her tears.',
      coinsSponsored: 500,
    ),
    const ConstellationEvent(
      modifier: 'Secretive Plotter',
      message: 'is silently observing the cadence of your story.',
      coinsSponsored: 300,
    ),
    const ConstellationEvent(
      modifier: 'Abyssal Black Flame Dragon',
      message: 'scoffs proudly and demands you turn to the next climax.',
      coinsSponsored: 666,
    ),
    const ConstellationEvent(
      modifier: 'Prisoner of the Golden Headband',
      message: 'scratches his ear and nods in thorough satisfaction.',
      coinsSponsored: 400,
    ),
    const ConstellationEvent(
      modifier: 'Queen of the Darkest Spring',
      message: 'smiles warmly at your steadfast devotion to this world.',
      coinsSponsored: 800,
    ),
    const ConstellationEvent(
      modifier: 'Maritime War God',
      message: 'admires your unwavering discipline on this reading voyage.',
      coinsSponsored: 350,
    ),
  ];

  ConstellationEvent getRandomConstellationReaction() {
    final rand = Random();
    return _milestoneEvents[rand.nextInt(_milestoneEvents.length)];
  }

  Future<void> creditSponsoredCoins(int amount) async {
    if (amount <= 0) return;
    final state = storageService.loadOrvState();
    final updated = state.copyWith(coins: state.coins + amount);
    await storageService.saveOrvState(updated);
  }

  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return true;
    final state = storageService.loadOrvState();
    if (state.coins < amount) return false;
    final updated = state.copyWith(coins: state.coins - amount);
    await storageService.saveOrvState(updated);
    return true;
  }
}
