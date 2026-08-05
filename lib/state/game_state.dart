import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/game_data.dart';
import '../data/models.dart';
import '../data/mutations.dart';
import '../data/perks.dart';
import 'save_service.dart';

/// Live progress for one daily objective.
class QuestProgress {
  QuestProgress({required this.def, required this.progress, required this.claimed});

  final QuestDef def;
  int progress;
  bool claimed;

  double get ratio => (progress / def.target).clamp(0.0, 1.0);
  bool get complete => progress >= def.target;
}

/// Aggregate lifetime numbers, surfaced on the statistics screen.
class LifetimeStats {
  LifetimeStats();

  int runs = 0;
  int victories = 0;
  int defeats = 0;
  int totalScore = 0;
  int absorbed = 0;
  int eliteAbsorbed = 0;
  int bosses = 0;
  int obstacles = 0;
  int bestCombo = 0;
  int flawlessRuns = 0;
  int questsDone = 0;
  double distance = 0;
  int playSeconds = 0;
  Map<ResourceKind, int> earned = {for (final r in ResourceKind.values) r: 0};
  Map<Essence, int> essenceUse = {for (final e in Essence.values) e: 0};

  Map<String, dynamic> toJson() => {
    'runs': runs,
    'victories': victories,
    'defeats': defeats,
    'totalScore': totalScore,
    'absorbed': absorbed,
    'eliteAbsorbed': eliteAbsorbed,
    'bosses': bosses,
    'obstacles': obstacles,
    'bestCombo': bestCombo,
    'flawlessRuns': flawlessRuns,
    'questsDone': questsDone,
    'distance': distance,
    'playSeconds': playSeconds,
    'earned': {for (final e in earned.entries) e.key.name: e.value},
    'essenceUse': {for (final e in essenceUse.entries) e.key.name: e.value},
  };

  static LifetimeStats fromJson(Map<String, dynamic> json) {
    final s = LifetimeStats();
    s.runs = json['runs'] as int? ?? 0;
    s.victories = json['victories'] as int? ?? 0;
    s.defeats = json['defeats'] as int? ?? 0;
    s.totalScore = json['totalScore'] as int? ?? 0;
    s.absorbed = json['absorbed'] as int? ?? 0;
    s.eliteAbsorbed = json['eliteAbsorbed'] as int? ?? 0;
    s.bosses = json['bosses'] as int? ?? 0;
    s.obstacles = json['obstacles'] as int? ?? 0;
    s.bestCombo = json['bestCombo'] as int? ?? 0;
    s.flawlessRuns = json['flawlessRuns'] as int? ?? 0;
    s.questsDone = json['questsDone'] as int? ?? 0;
    s.distance = (json['distance'] as num?)?.toDouble() ?? 0;
    s.playSeconds = json['playSeconds'] as int? ?? 0;
    final earned = json['earned'] as Map<String, dynamic>? ?? const {};
    for (final kind in ResourceKind.values) {
      s.earned[kind] = earned[kind.name] as int? ?? 0;
    }
    final use = json['essenceUse'] as Map<String, dynamic>? ?? const {};
    for (final essence in Essence.values) {
      s.essenceUse[essence] = use[essence.name] as int? ?? 0;
    }
    return s;
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({required this.name, required this.score, required this.isPlayer});

  final String name;
  final int score;
  final bool isPlayer;
}

/// The single owner of all mutable player progress.
class GameState extends ChangeNotifier {
  GameState(this._save) {
    _load();
  }

  final SaveService _save;
  final math.Random _rng = math.Random();

  // ------------------------------------------------------------------ fields

  String playerName = 'Lavawake';
  String? avatarPath;
  int xp = 0;
  bool onboardingDone = false;
  bool tutorialSeen = false;
  String selectedSkin = 'skin_ember';
  int lastTipIndex = 0;

  final Map<ResourceKind, int> resources = {for (final r in ResourceKind.values) r: 0};
  final Map<UpgradeTrack, int> upgrades = {for (final t in UpgradeTrack.values) t: 0};

  /// Ranks spent per perk id on the Crucible board, funded by [perkPoints].
  final Map<String, int> perkRanks = {};
  int perkPoints = 0;
  int _lastRewardedLevel = 1;
  final Map<int, int> levelStars = {};
  final Map<int, int> levelBestScore = {};
  final Set<String> discovered = {};
  final Set<String> unlockedSkins = {'skin_ember'};
  final Set<String> unlockedAchievements = {};
  final List<QuestProgress> quests = [];
  final List<int> recentScores = [];
  final List<int> weeklyMinutes = List<int>.filled(7, 0);
  final List<LeaderboardEntry> _rivals = [];

  LifetimeStats stats = LifetimeStats();
  int endlessBest = 0;
  String questDay = '';

  // -------------------------------------------------------------- derivations

  int get playerLevel {
    var level = 1;
    var need = 320;
    var pool = xp;
    while (pool >= need && level < 99) {
      pool -= need;
      level++;
      need = (need * 1.16).round();
    }
    return level;
  }

  double get levelProgress {
    var level = 1;
    var need = 320;
    var pool = xp;
    while (pool >= need && level < 99) {
      pool -= need;
      level++;
      need = (need * 1.16).round();
    }
    return (pool / need).clamp(0.0, 1.0);
  }

  String get playerTitle {
    final level = playerLevel;
    if (level >= 40) return 'Primordial Flow';
    if (level >= 30) return 'Caldera Sovereign';
    if (level >= 22) return 'Forge Devourer';
    if (level >= 15) return 'Obsidian Tide';
    if (level >= 9) return 'Ember Current';
    if (level >= 4) return 'Waking Stream';
    return 'First Droplet';
  }

  /// Index of the highest level the player may start.
  int get furthestLevel {
    var index = 0;
    while (index < GameData.levelCount - 1 && (levelStars[index] ?? 0) > 0) {
      index++;
    }
    return index;
  }

  int get levelsCleared => levelStars.values.where((s) => s > 0).length;

  int get upgradeLevelsBought => upgrades.values.fold(0, (a, b) => a + b);

  int get collectionCount => discovered.length;

  double get collectionRatio => discovered.length / GameData.enemies.length;

  /// All regions are always visible and accessible — the first level of every
  /// zone is free so new players can explore the full world from day one.
  bool isRegionUnlocked(int regionIndex) => true;

  bool isLevelUnlocked(int globalIndex) {
    final level = GameData.levelAt(globalIndex);
    // The first level of every region is always open.
    if (level.indexInRegion == 0) return true;
    // Subsequent levels unlock once the previous level in the same region
    // has been cleared (at least one star).
    return (levelStars[globalIndex - 1] ?? 0) > 0;
  }

  int regionStars(int regionIndex) => GameData.levels
      .where((l) => l.regionIndex == regionIndex)
      .fold(0, (sum, l) => sum + (levelStars[l.globalIndex] ?? 0));

  int regionMaxStars(int regionIndex) =>
      GameData.levels.where((l) => l.regionIndex == regionIndex).length * 3;

  int bossesFelled() {
    var count = 0;
    for (final level in GameData.levels.where((l) => l.isBoss)) {
      if ((levelStars[level.globalIndex] ?? 0) > 0) count++;
    }
    return count;
  }

  /// Multiplier the engine applies for a given upgrade track.
  double bonus(UpgradeTrack track) => 1 + upgrades[track]! * track.step;

  int upgradeCost(UpgradeTrack track) {
    final level = upgrades[track]!;
    return (34 * math.pow(1.44, level)).round();
  }

  bool canAffordUpgrade(UpgradeTrack track) =>
      upgrades[track]! < track.maxLevel && resources[track.currency]! >= upgradeCost(track);

  int achievementProgress(AchievementDef def) => switch (def.metric) {
    'absorbed' => stats.absorbed,
    'eliteAbsorbed' => stats.eliteAbsorbed,
    'bosses' => bossesFelled(),
    'obstacles' => stats.obstacles,
    'distance' => stats.distance.round(),
    'levelsCleared' => levelsCleared,
    'bestCombo' => stats.bestCombo,
    'flawlessRuns' => stats.flawlessRuns,
    'upgradeLevels' => upgradeLevelsBought,
    'collection' => discovered.length,
    'skins' => unlockedSkins.length,
    'questsDone' => stats.questsDone,
    'totalScore' => stats.totalScore,
    _ => 0,
  };

  bool isAchievementUnlocked(AchievementDef def) =>
      unlockedAchievements.contains(def.id) || achievementProgress(def) >= def.target;

  List<LeaderboardEntry> get leaderboard {
    final entries = [
      ..._rivals,
      LeaderboardEntry(name: playerName, score: math.max(endlessBest, _bestLevelScore()), isPlayer: true),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  int _bestLevelScore() => levelBestScore.values.fold(0, math.max);

  String nextTip() {
    lastTipIndex = (lastTipIndex + 1) % GameData.tips.length;
    _persist();
    return GameData.tips[lastTipIndex];
  }

  // ------------------------------------------------------------------ actions

  void setProfile({String? name, String? avatar}) {
    if (name != null && name.trim().isNotEmpty) playerName = name.trim();
    if (avatar != null) avatarPath = avatar;
    _persist();
    notifyListeners();
  }

  void clearAvatar() {
    avatarPath = null;
    _persist();
    notifyListeners();
  }

  void completeOnboarding() {
    onboardingDone = true;
    _persist();
    notifyListeners();
  }

  void markTutorialSeen() {
    tutorialSeen = true;
    _persist();
    notifyListeners();
  }

  bool selectSkin(String id) {
    if (!unlockedSkins.contains(id)) return false;
    selectedSkin = id;
    _persist();
    notifyListeners();
    return true;
  }

  bool buyUpgrade(UpgradeTrack track) {
    if (!canAffordUpgrade(track)) return false;
    resources[track.currency] = resources[track.currency]! - upgradeCost(track);
    upgrades[track] = upgrades[track]! + 1;
    _refreshUnlocks();
    _persist();
    notifyListeners();
    return true;
  }

  // -------------------------------------------------------------------- perks

  int perkRank(String id) => perkRanks[id] ?? 0;

  int get perkRanksSpent => perkRanks.values.fold(0, (a, b) => a + b);

  /// A perk tier only opens once at least one rank sits in the tier above it in
  /// the same column, giving the board a top-down unlock shape.
  bool isPerkUnlocked(PerkDef def) {
    if (def.tier == 0) return true;
    final above = kPerks.where((p) => p.column == def.column && p.tier == def.tier - 1);
    return above.any((p) => perkRank(p.id) > 0);
  }

  bool canBuyPerk(PerkDef def) =>
      perkPoints > 0 && perkRank(def.id) < def.ranks && isPerkUnlocked(def);

  bool buyPerk(PerkDef def) {
    if (!canBuyPerk(def)) return false;
    perkPoints--;
    perkRanks[def.id] = perkRank(def.id) + 1;
    _persist();
    notifyListeners();
    return true;
  }

  /// Wipes every spent perk rank and refunds the points, so a player can freely
  /// re-plan their board between runs.
  void respecPerks() {
    perkPoints += perkRanksSpent;
    perkRanks.clear();
    _persist();
    notifyListeners();
  }

  /// Builds the pre-seeded [RunModifiers] a fresh run starts from, folding in
  /// every purchased perk rank.
  RunModifiers buildRunModifiers() {
    final mods = RunModifiers();
    for (final def in kPerks) {
      final rank = perkRank(def.id);
      if (rank > 0) def.apply(mods, rank);
    }
    return mods;
  }

  /// Forge exchanges a bundle of one resource for a scarcer one.
  bool forge(ResourceKind from, ResourceKind to, int amount, int yield_) {
    if (resources[from]! < amount) return false;
    resources[from] = resources[from]! - amount;
    resources[to] = resources[to]! + yield_;
    stats.earned[to] = stats.earned[to]! + yield_;
    _refreshUnlocks();
    _persist();
    notifyListeners();
    return true;
  }

  bool claimQuest(QuestProgress quest) {
    if (!quest.complete || quest.claimed) return false;
    quest.claimed = true;
    resources[quest.def.rewardKind] = resources[quest.def.rewardKind]! + quest.def.reward;
    stats.earned[quest.def.rewardKind] = stats.earned[quest.def.rewardKind]! + quest.def.reward;
    stats.questsDone++;
    _refreshUnlocks();
    _persist();
    notifyListeners();
    return true;
  }

  /// Folds a finished run into every progress system at once.
  void applyRunResult(RunResult result) {
    stats.runs++;
    if (result.victory) {
      stats.victories++;
    } else {
      stats.defeats++;
    }
    stats.totalScore += result.score;
    stats.absorbed += result.absorbed;
    stats.eliteAbsorbed += result.eliteAbsorbed;
    stats.bosses += result.bossesFelled;
    stats.obstacles += result.obstaclesSmashed;
    stats.distance += result.distance;
    stats.playSeconds += result.duration.inSeconds;
    stats.bestCombo = math.max(stats.bestCombo, result.bestCombo);
    if (result.victory && result.flawless) stats.flawlessRuns++;
    for (final essence in result.essencesUsed) {
      stats.essenceUse[essence] = stats.essenceUse[essence]! + 1;
    }

    for (final entry in result.loot.entries) {
      resources[entry.key] = resources[entry.key]! + entry.value;
      stats.earned[entry.key] = stats.earned[entry.key]! + entry.value;
    }

    xp += (result.score / 8).round() + result.absorbed * 3 + (result.victory ? 120 : 30);
    _awardPerkPoints();

    recentScores.add(result.score);
    if (recentScores.length > 14) recentScores.removeRange(0, recentScores.length - 14);
    final weekday = DateTime.now().weekday - 1;
    weeklyMinutes[weekday] = weeklyMinutes[weekday] + math.max(1, result.duration.inSeconds ~/ 60);

    if (result.isEndless) {
      endlessBest = math.max(endlessBest, result.score);
    } else {
      final stars = result.victory ? _starsFor(result) : 0;
      if (stars > (levelStars[result.levelIndex] ?? 0)) levelStars[result.levelIndex] = stars;
      if (result.score > (levelBestScore[result.levelIndex] ?? 0)) {
        levelBestScore[result.levelIndex] = result.score;
      }
    }

    _advanceQuests(result);
    _refreshUnlocks();
    _persist();
    notifyListeners();
  }

  void recordDiscovery(String enemyId) {
    if (discovered.add(enemyId)) {
      _refreshUnlocks();
      _persist();
      notifyListeners();
    }
  }

  void recordDiscoveries(Iterable<String> ids) {
    var changed = false;
    for (final id in ids) {
      changed |= discovered.add(id);
    }
    if (changed) {
      _refreshUnlocks();
      _persist();
      notifyListeners();
    }
  }

  void resetProgress() {
    playerName = 'Lavawake';
    avatarPath = null;
    xp = 0;
    onboardingDone = false;
    tutorialSeen = false;
    selectedSkin = 'skin_ember';
    for (final r in ResourceKind.values) {
      resources[r] = 0;
    }
    for (final t in UpgradeTrack.values) {
      upgrades[t] = 0;
    }
    perkRanks.clear();
    perkPoints = 0;
    _lastRewardedLevel = 1;
    levelStars.clear();
    levelBestScore.clear();
    discovered.clear();
    unlockedSkins
      ..clear()
      ..add('skin_ember');
    unlockedAchievements.clear();
    recentScores.clear();
    for (var i = 0; i < weeklyMinutes.length; i++) {
      weeklyMinutes[i] = 0;
    }
    stats = LifetimeStats();
    endlessBest = 0;
    questDay = '';
    _rollQuests();
    _seedRivals();
    _save.wipeProgress();
    _persist();
    notifyListeners();
  }

  /// One perk point per player level gained, so the Crucible fills as the flow
  /// grows.
  void _awardPerkPoints() {
    final level = playerLevel;
    if (level > _lastRewardedLevel) {
      perkPoints += level - _lastRewardedLevel;
      _lastRewardedLevel = level;
    }
  }

  int _starsFor(RunResult result) {
    var stars = 1;
    if (result.flawless || result.bestCombo >= 15) stars++;
    if (result.absorbed >= 18 && result.progress >= 1) stars++;
    return stars.clamp(1, 3);
  }

  void _advanceQuests(RunResult result) {
    for (final quest in quests) {
      if (quest.claimed) continue;
      quest.progress += switch (quest.def.metric) {
        QuestMetric.absorb => result.absorbed,
        QuestMetric.eliteKills => result.eliteAbsorbed,
        QuestMetric.obstacles => result.obstaclesSmashed,
        QuestMetric.magma => result.loot[ResourceKind.magma] ?? 0,
        QuestMetric.bossKills => result.bossesFelled,
        QuestMetric.essencesUsed => result.essencesUsed.length >= 5 ? 5 : 0,
        QuestMetric.flawless => result.victory && result.flawless ? 1 : 0,
        QuestMetric.distance => result.distance.round(),
        QuestMetric.runs => 1,
        QuestMetric.combo => result.bestCombo >= quest.def.target ? quest.def.target : 0,
      };
      if (quest.def.metric == QuestMetric.combo && result.bestCombo < quest.def.target) {
        quest.progress = math.max(quest.progress, result.bestCombo);
      }
      quest.progress = quest.progress.clamp(0, quest.def.target);
    }
  }

  /// Grants any skin or achievement whose condition is now satisfied.
  void _refreshUnlocks() {
    void grant(String id) => unlockedSkins.add(id);

    if (stats.absorbed >= 100) grant('skin_crimson');
    if (stats.obstacles >= 150) grant('skin_charcoal');
    if (_regionCleared(0)) grant('skin_obsidian');
    if (_regionCleared(1)) grant('skin_glacier');
    if (_regionCleared(3)) grant('skin_amethyst');
    if (_regionCleared(4)) grant('skin_bronze');
    if (stats.flawlessRuns >= 1) grant('skin_venom');
    if (stats.bestCombo >= 30) grant('skin_sulphur');
    if (stats.essenceUse[Essence.rime]! >= 40) grant('skin_cryo');
    if (bossesFelled() >= 6) grant('skin_prism');
    if (discovered.length >= GameData.enemies.length) grant('skin_void');

    for (final def in GameData.achievements) {
      if (achievementProgress(def) >= def.target) unlockedAchievements.add(def.id);
    }
  }

  bool _regionCleared(int regionIndex) {
    final region = GameData.regions[regionIndex];
    return GameData.levels
        .where((l) => l.regionIndex == region.index)
        .every((l) => (levelStars[l.globalIndex] ?? 0) > 0);
  }

  // ------------------------------------------------------------------- quests

  void refreshDailyQuestsIfNeeded() {
    final today = _todayKey();
    if (questDay == today && quests.isNotEmpty) return;
    questDay = today;
    _rollQuests();
    _persist();
    notifyListeners();
  }

  void _rollQuests() {
    // The seed is the calendar day, so the same four objectives persist across
    // restarts without needing a server.
    final seed = questDay.isEmpty ? DateTime.now().day : questDay.hashCode;
    final pool = [...GameData.questPool]..shuffle(math.Random(seed));
    quests
      ..clear()
      ..addAll(pool.take(4).map((def) => QuestProgress(def: def, progress: 0, claimed: false)));
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _seedRivals() {
    _rivals.clear();
    final base = 4200 + levelsCleared * 900;
    for (var i = 0; i < GameData.rivalNames.length; i++) {
      final jitter = _rng.nextInt(1600);
      _rivals.add(
        LeaderboardEntry(
          name: GameData.rivalNames[i],
          score: base + (GameData.rivalNames.length - i) * 1150 + jitter,
          isPlayer: false,
        ),
      );
    }
  }

  // -------------------------------------------------------------- persistence

  void _load() {
    final data = _save.readProgress();
    playerName = data['playerName'] as String? ?? 'Lavawake';
    avatarPath = data['avatarPath'] as String?;
    xp = data['xp'] as int? ?? 0;
    onboardingDone = data['onboardingDone'] as bool? ?? false;
    tutorialSeen = data['tutorialSeen'] as bool? ?? false;
    selectedSkin = data['selectedSkin'] as String? ?? 'skin_ember';
    lastTipIndex = data['lastTipIndex'] as int? ?? 0;
    endlessBest = data['endlessBest'] as int? ?? 0;
    questDay = data['questDay'] as String? ?? '';

    final res = data['resources'] as Map<String, dynamic>? ?? const {};
    for (final kind in ResourceKind.values) {
      resources[kind] = res[kind.name] as int? ?? 0;
    }
    final up = data['upgrades'] as Map<String, dynamic>? ?? const {};
    for (final track in UpgradeTrack.values) {
      upgrades[track] = (up[track.name] as int? ?? 0).clamp(0, track.maxLevel);
    }
    perkPoints = data['perkPoints'] as int? ?? 0;
    _lastRewardedLevel = data['lastRewardedLevel'] as int? ?? 1;
    final perks = data['perkRanks'] as Map<String, dynamic>? ?? const {};
    perks.forEach((key, value) {
      final def = kPerkById[key];
      if (def != null && value is int) perkRanks[key] = value.clamp(0, def.ranks);
    });
    final stars = data['levelStars'] as Map<String, dynamic>? ?? const {};
    stars.forEach((key, value) {
      final index = int.tryParse(key);
      if (index != null && value is int) levelStars[index] = value;
    });
    final best = data['levelBestScore'] as Map<String, dynamic>? ?? const {};
    best.forEach((key, value) {
      final index = int.tryParse(key);
      if (index != null && value is int) levelBestScore[index] = value;
    });
    discovered.addAll((data['discovered'] as List?)?.whereType<String>() ?? const []);
    unlockedSkins.addAll((data['unlockedSkins'] as List?)?.whereType<String>() ?? const []);
    unlockedAchievements.addAll((data['achievements'] as List?)?.whereType<String>() ?? const []);
    recentScores.addAll((data['recentScores'] as List?)?.whereType<int>() ?? const []);
    final weekly = (data['weeklyMinutes'] as List?)?.whereType<int>().toList() ?? const [];
    for (var i = 0; i < weeklyMinutes.length && i < weekly.length; i++) {
      weeklyMinutes[i] = weekly[i];
    }
    stats = LifetimeStats.fromJson(data['stats'] as Map<String, dynamic>? ?? const {});

    final savedQuests = data['quests'] as List? ?? const [];
    for (final raw in savedQuests) {
      if (raw is! Map) continue;
      final def = GameData.questPool.firstWhere(
        (q) => q.id == raw['id'],
        orElse: () => GameData.questPool.first,
      );
      quests.add(
        QuestProgress(
          def: def,
          progress: raw['progress'] as int? ?? 0,
          claimed: raw['claimed'] as bool? ?? false,
        ),
      );
    }
    if (quests.isEmpty) _rollQuests();
    _seedRivals();
  }

  void _persist() {
    _save.writeProgress({
      'playerName': playerName,
      'avatarPath': avatarPath,
      'xp': xp,
      'onboardingDone': onboardingDone,
      'tutorialSeen': tutorialSeen,
      'selectedSkin': selectedSkin,
      'lastTipIndex': lastTipIndex,
      'endlessBest': endlessBest,
      'questDay': questDay,
      'resources': {for (final e in resources.entries) e.key.name: e.value},
      'upgrades': {for (final e in upgrades.entries) e.key.name: e.value},
      'perkRanks': {for (final e in perkRanks.entries) e.key: e.value},
      'perkPoints': perkPoints,
      'lastRewardedLevel': _lastRewardedLevel,
      'levelStars': {for (final e in levelStars.entries) e.key.toString(): e.value},
      'levelBestScore': {for (final e in levelBestScore.entries) e.key.toString(): e.value},
      'discovered': discovered.toList(),
      'unlockedSkins': unlockedSkins.toList(),
      'achievements': unlockedAchievements.toList(),
      'recentScores': recentScores,
      'weeklyMinutes': weeklyMinutes,
      'stats': stats.toJson(),
      'quests': [
        for (final q in quests) {'id': q.def.id, 'progress': q.progress, 'claimed': q.claimed},
      ],
    });
  }
}
