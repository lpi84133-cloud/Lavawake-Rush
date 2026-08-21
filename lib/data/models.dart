import 'package:flutter/material.dart';

import '../core/design/palette.dart';

/// The five absorbable material types. Named `Essence` rather than `Element` to
/// stay clear of Flutter's own `Element`.
enum Essence { stone, metal, fire, crystal, rime }

extension EssenceInfo on Essence {
  String get label => switch (this) {
    Essence.stone => 'Basalt',
    Essence.metal => 'Molten Metal',
    Essence.fire => 'Fire',
    Essence.crystal => 'Crystal',
    Essence.rime => 'Rime',
  };

  String get shortLabel => switch (this) {
    Essence.stone => 'STN',
    Essence.metal => 'MTL',
    Essence.fire => 'FIR',
    Essence.crystal => 'CRY',
    Essence.rime => 'RME',
  };

  Color get color => switch (this) {
    Essence.stone => Palette.stone,
    Essence.metal => Palette.metal,
    Essence.fire => Palette.fire,
    Essence.crystal => Palette.crystal,
    Essence.rime => Palette.frost,
  };

  IconData get icon => switch (this) {
    Essence.stone => Icons.landscape_rounded,
    Essence.metal => Icons.settings_rounded,
    Essence.fire => Icons.local_fire_department_rounded,
    Essence.crystal => Icons.diamond_rounded,
    Essence.rime => Icons.ac_unit_rounded,
  };

  String get perk => switch (this) {
    Essence.stone => 'Heavier flow, smashes obstacles, more inertia.',
    Essence.metal => 'Tougher shell and harder impacts.',
    Essence.fire => 'Runs hotter and melts targets faster.',
    Essence.crystal => 'Unlocks ranged shard volleys.',
    Essence.rime => 'Obsidian plating, less damage taken.',
  };
}

enum ResourceKind { magma, shards, alloy, obsidian, cores }

extension ResourceInfo on ResourceKind {
  String get label => switch (this) {
    ResourceKind.magma => 'Magma Energy',
    ResourceKind.shards => 'Crystal Shards',
    ResourceKind.alloy => 'Metal Alloy',
    ResourceKind.obsidian => 'Obsidian',
    ResourceKind.cores => 'Ancient Cores',
  };

  String get sprite => switch (this) {
    ResourceKind.magma => 'mat_magma_core',
    ResourceKind.shards => 'mat_ice_crystal',
    ResourceKind.alloy => 'mat_metal_ingot',
    ResourceKind.obsidian => 'mat_obsidian_shard',
    ResourceKind.cores => 'mat_ancient_core',
  };

  Color get color => switch (this) {
    ResourceKind.magma => Palette.lava,
    ResourceKind.shards => Palette.frost,
    ResourceKind.alloy => Palette.metal,
    ResourceKind.obsidian => Palette.obsidian,
    ResourceKind.cores => Palette.ember,
  };

  IconData get icon => switch (this) {
    ResourceKind.magma => Icons.whatshot_rounded,
    ResourceKind.shards => Icons.diamond_outlined,
    ResourceKind.alloy => Icons.hardware_rounded,
    ResourceKind.obsidian => Icons.change_history_rounded,
    ResourceKind.cores => Icons.brightness_7_rounded,
  };
}

enum Rarity { common, rare, elite, boss }

extension RarityInfo on Rarity {
  String get label => switch (this) {
    Rarity.common => 'Common',
    Rarity.rare => 'Rare',
    Rarity.elite => 'Elite',
    Rarity.boss => 'Boss',
  };

  Color get color => switch (this) {
    Rarity.common => Palette.textMuted,
    Rarity.rare => Palette.frost,
    Rarity.elite => Palette.crystal,
    Rarity.boss => Palette.lava,
  };
}

/// A bestiary entry. `armor` is the heat needed before the flow can melt it and
/// `mass` is how much bulk it adds once absorbed.
@immutable
class EnemyDef {
  const EnemyDef({
    required this.id,
    required this.name,
    required this.essence,
    required this.rarity,
    required this.armor,
    required this.toughness,
    required this.mass,
    required this.threat,
    required this.lore,
  });

  final String id;
  final String name;
  final Essence essence;
  final Rarity rarity;
  final double armor;
  final double toughness;
  final double mass;
  final int threat;
  final String lore;

  String get sprite => id;
}

@immutable
class ObstacleDef {
  const ObstacleDef({required this.id, required this.name, required this.massToBreak, required this.damage});

  final String id;
  final String name;
  final double massToBreak;
  final double damage;
}

@immutable
class RegionDef {
  const RegionDef({
    required this.index,
    required this.name,
    required this.subtitle,
    required this.background,
    required this.accent,
    required this.families,
    required this.levelCount,
    required this.description,
  });

  final int index;
  final String name;
  final String subtitle;
  final String background;
  final Color accent;

  /// Enemy id prefixes that spawn here.
  final List<String> families;
  final int levelCount;
  final String description;
}

@immutable
class LevelDef {
  const LevelDef({
    required this.regionIndex,
    required this.indexInRegion,
    required this.globalIndex,
    required this.name,
    required this.distance,
    required this.difficulty,
    required this.isBoss,
    required this.bossId,
    required this.rewards,
  });

  final int regionIndex;
  final int indexInRegion;
  final int globalIndex;
  final String name;
  final double distance;
  final double difficulty;
  final bool isBoss;
  final String? bossId;
  final Map<ResourceKind, int> rewards;
}

enum UpgradeTrack { heat, mass, speed, absorption, integrity, surge, shield, harvest }

extension UpgradeTrackInfo on UpgradeTrack {
  String get label => switch (this) {
    UpgradeTrack.heat => 'Core Temperature',
    UpgradeTrack.mass => 'Mass Density',
    UpgradeTrack.speed => 'Flow Velocity',
    UpgradeTrack.absorption => 'Absorption Rate',
    UpgradeTrack.integrity => 'Structural Integrity',
    UpgradeTrack.surge => 'Surge Charge',
    UpgradeTrack.shield => 'Obsidian Plating',
    UpgradeTrack.harvest => 'Harvest Yield',
  };

  String get blurb => switch (this) {
    UpgradeTrack.heat => 'Raises base heat and slows how quickly it bleeds away.',
    UpgradeTrack.mass => 'Adds bulk so heavier obstacles shatter on contact.',
    UpgradeTrack.speed => 'Sharpens how fast the flow answers your finger.',
    UpgradeTrack.absorption => 'Melts enemies down in fewer moments.',
    UpgradeTrack.integrity => 'Increases the durability pool you run on.',
    UpgradeTrack.surge => 'Longer surges with a shorter cooldown.',
    UpgradeTrack.shield => 'Reduces every point of damage that lands.',
    UpgradeTrack.harvest => 'Pulls more resources out of every run.',
  };

  IconData get icon => switch (this) {
    UpgradeTrack.heat => Icons.thermostat_rounded,
    UpgradeTrack.mass => Icons.fitness_center_rounded,
    UpgradeTrack.speed => Icons.speed_rounded,
    UpgradeTrack.absorption => Icons.blur_circular_rounded,
    UpgradeTrack.integrity => Icons.shield_moon_rounded,
    UpgradeTrack.surge => Icons.bolt_rounded,
    UpgradeTrack.shield => Icons.security_rounded,
    UpgradeTrack.harvest => Icons.auto_awesome_rounded,
  };

  ResourceKind get currency => switch (this) {
    UpgradeTrack.heat => ResourceKind.magma,
    UpgradeTrack.mass => ResourceKind.obsidian,
    UpgradeTrack.speed => ResourceKind.magma,
    UpgradeTrack.absorption => ResourceKind.shards,
    UpgradeTrack.integrity => ResourceKind.alloy,
    UpgradeTrack.surge => ResourceKind.magma,
    UpgradeTrack.shield => ResourceKind.obsidian,
    UpgradeTrack.harvest => ResourceKind.cores,
  };

  /// Per-level gain applied on top of the base stat.
  double get step => switch (this) {
    UpgradeTrack.heat => 0.09,
    UpgradeTrack.mass => 0.08,
    UpgradeTrack.speed => 0.07,
    UpgradeTrack.absorption => 0.10,
    UpgradeTrack.integrity => 0.11,
    UpgradeTrack.surge => 0.09,
    UpgradeTrack.shield => 0.06,
    UpgradeTrack.harvest => 0.12,
  };

  int get maxLevel => 8;
}

@immutable
class FormDef {
  const FormDef({
    required this.id,
    required this.name,
    required this.recipe,
    required this.sprite,
    required this.summary,
    required this.strength,
    required this.weakness,
  });

  final String id;
  final String name;
  final List<Essence> recipe;
  final String sprite;
  final String summary;
  final String strength;
  final String weakness;
}

@immutable
class SkinDef {
  const SkinDef({
    required this.id,
    required this.name,
    required this.sprite,
    required this.rarity,
    required this.unlockHint,
    required this.tint,
  });

  final String id;
  final String name;
  final String sprite;
  final Rarity rarity;
  final String unlockHint;
  final Color tint;
}

enum QuestMetric { absorb, eliteKills, obstacles, magma, bossKills, essencesUsed, flawless, distance, runs, combo }

@immutable
class QuestDef {
  const QuestDef({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.reward,
    required this.rewardKind,
  });

  final String id;
  final String title;
  final QuestMetric metric;
  final int target;
  final int reward;
  final ResourceKind rewardKind;
}

enum AchievementTier { bronze, silver, gold, molten }

extension AchievementTierInfo on AchievementTier {
  Color get color => switch (this) {
    AchievementTier.bronze => const Color(0xFFC08457),
    AchievementTier.silver => const Color(0xFFC9CBD4),
    AchievementTier.gold => const Color(0xFFEFC050),
    AchievementTier.molten => Palette.lava,
  };

  String get label => switch (this) {
    AchievementTier.bronze => 'Bronze',
    AchievementTier.silver => 'Silver',
    AchievementTier.gold => 'Gold',
    AchievementTier.molten => 'Molten',
  };

  /// Resource paid out when an achievement of this tier is first unlocked.
  /// A `null` kind means the tier pays a Crucible perk point instead.
  ResourceKind? get rewardKind => switch (this) {
    AchievementTier.bronze => ResourceKind.magma,
    AchievementTier.silver => ResourceKind.shards,
    AchievementTier.gold => ResourceKind.cores,
    AchievementTier.molten => null,
  };

  int get rewardAmount => switch (this) {
    AchievementTier.bronze => 150,
    AchievementTier.silver => 12,
    AchievementTier.gold => 5,
    AchievementTier.molten => 1,
  };

  String get rewardLabel =>
      rewardKind == null ? '+1 Perk Point' : '+$rewardAmount ${rewardKind!.label}';
}

@immutable
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.metric,
    required this.target,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final AchievementTier tier;
  final String metric;
  final int target;
  final IconData icon;
}

/// Outcome of one run, handed from the gameplay screen to the results screen.
@immutable
class RunResult {
  const RunResult({
    required this.levelIndex,
    required this.isEndless,
    required this.victory,
    required this.progress,
    required this.score,
    required this.absorbed,
    required this.eliteAbsorbed,
    required this.bossesFelled,
    required this.obstaclesSmashed,
    required this.bestCombo,
    required this.distance,
    required this.duration,
    required this.flawless,
    required this.essencesUsed,
    required this.loot,
    this.formsSeen = const {},
  });

  final int levelIndex;
  final bool isEndless;
  final bool victory;
  final double progress;
  final int score;
  final int absorbed;
  final int eliteAbsorbed;
  final int bossesFelled;
  final int obstaclesSmashed;
  final int bestCombo;
  final double distance;
  final Duration duration;
  final bool flawless;
  final Set<Essence> essencesUsed;
  final Map<ResourceKind, int> loot;

  /// Fusion forms the flow actually held at some point during the run, used to
  /// reveal recipes in the Forms Codex the first time they are achieved.
  final Set<String> formsSeen;
}
