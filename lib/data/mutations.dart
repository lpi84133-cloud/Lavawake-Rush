import 'package:flutter/material.dart';

import '../core/design/palette.dart';
import 'models.dart';

/// Every number the simulation reads that a mutation, a perk or a chosen route is
/// allowed to change mid-run.
///
/// The engine owns one instance and never replaces it, so effects simply stack by
/// multiplying or adding into these fields as the player picks things up.
class RunModifiers {
  // Heat ---------------------------------------------------------------------
  double heatDecayMul = 1;
  double ventHeatMul = 1;
  double heatPerAbsorb = 0;

  // Offence ------------------------------------------------------------------
  double meltRateMul = 1;
  double reachMul = 1;
  double eruptGainMul = 1;
  double eruptReachMul = 1;
  int volleyShards = 3;
  double volleyCooldownMul = 1;
  bool shardsPierce = false;
  bool shatterAnything = false;
  double bossDamageMul = 1;

  // Defence ------------------------------------------------------------------
  double damageTakenMul = 1;
  double surgeDurationMul = 1;
  double surgeCooldownMul = 1;
  bool coldImmune = false;
  bool keepComboOnHit = false;
  double integrityPerAbsorb = 0;
  int reviveCharges = 0;
  double thornsDamage = 0;

  // Motion -------------------------------------------------------------------
  double agilityMul = 1;
  double scrollSpeedMul = 1;
  double massGainMul = 1;
  double massDragMul = 1;
  double magnetRadius = 0;

  // Economy ------------------------------------------------------------------
  double lootMul = 1;
  double scoreMul = 1;
  int comboThreshold = 12;
  double comboScoreStep = 0.04;
  double pickupRateMul = 1;

  // Risk taken on voluntarily; the fork and the pact both push these up.
  double spawnRateMul = 1;
  double hazardRateMul = 1;
  double eliteChanceBonus = 0;

  /// Extra draft rounds granted before the run starts.
  int bonusDraftRounds = 0;

  /// Reroll tokens for the mutation draft.
  int rerolls = 1;
}

enum MutationBranch { offence, defence, motion, economy, wild }

extension MutationBranchInfo on MutationBranch {
  String get label => switch (this) {
    MutationBranch.offence => 'Offence',
    MutationBranch.defence => 'Defence',
    MutationBranch.motion => 'Motion',
    MutationBranch.economy => 'Economy',
    MutationBranch.wild => 'Unstable',
  };

  Color get color => switch (this) {
    MutationBranch.offence => Palette.crimson,
    MutationBranch.defence => Palette.frost,
    MutationBranch.motion => Palette.venom,
    MutationBranch.economy => Palette.ember,
    MutationBranch.wild => Palette.crystal,
  };

  IconData get icon => switch (this) {
    MutationBranch.offence => Icons.local_fire_department_rounded,
    MutationBranch.defence => Icons.shield_moon_rounded,
    MutationBranch.motion => Icons.air_rounded,
    MutationBranch.economy => Icons.savings_rounded,
    MutationBranch.wild => Icons.science_rounded,
  };
}

/// One draftable mutation. `apply` mutates the live [RunModifiers], and `cost` is
/// the drawback shown in the card so every pick reads as a trade.
@immutable
class MutationDef {
  const MutationDef({
    required this.id,
    required this.name,
    required this.branch,
    required this.gain,
    required this.cost,
    required this.icon,
    required this.apply,
    this.maxStacks = 3,
    this.requiresEssence,
  });

  final String id;
  final String name;
  final MutationBranch branch;

  /// What the player gets, phrased for a card.
  final String gain;

  /// What it costs them. Empty for the handful of clean upgrades.
  final String cost;

  final IconData icon;
  final void Function(RunModifiers m) apply;
  final int maxStacks;

  /// Only offered once this material has been absorbed at least once this run.
  final Essence? requiresEssence;

  Color get color => branch.color;
}

/// The draft pool. Deliberately full of trade-offs so a run's build has a shape
/// instead of turning into a pile of flat buffs.
final List<MutationDef> kMutations = [
  // Offence ------------------------------------------------------------------
  MutationDef(
    id: 'mut_white_heat',
    name: 'White Heat',
    branch: MutationBranch.offence,
    gain: 'Melt targets 30% faster.',
    cost: 'Heat bleeds 18% quicker.',
    icon: Icons.whatshot_rounded,
    apply: (m) {
      m.meltRateMul *= 1.30;
      m.heatDecayMul *= 1.18;
    },
  ),
  MutationDef(
    id: 'mut_wide_maw',
    name: 'Wide Maw',
    branch: MutationBranch.offence,
    gain: 'Absorption reach grows 16%.',
    cost: 'You are a bigger target too.',
    icon: Icons.open_in_full_rounded,
    apply: (m) => m.reachMul *= 1.16,
  ),
  MutationDef(
    id: 'mut_pressure_valve',
    name: 'Pressure Valve',
    branch: MutationBranch.offence,
    gain: 'Erupt charges 45% faster.',
    cost: 'Erupt radius shrinks 15%.',
    icon: Icons.blur_on_rounded,
    apply: (m) {
      m.eruptGainMul *= 1.45;
      m.eruptReachMul *= 0.85;
    },
  ),
  MutationDef(
    id: 'mut_shrapnel',
    name: 'Shrapnel Lattice',
    branch: MutationBranch.offence,
    gain: 'Two extra shards per volley.',
    cost: 'Volley cooldown up 20%.',
    icon: Icons.grain_rounded,
    requiresEssence: Essence.crystal,
    apply: (m) {
      m.volleyShards += 2;
      m.volleyCooldownMul *= 1.20;
    },
  ),
  MutationDef(
    id: 'mut_piercing',
    name: 'Piercing Shards',
    branch: MutationBranch.offence,
    gain: 'Shards punch through every target.',
    cost: '',
    icon: Icons.arrow_forward_rounded,
    maxStacks: 1,
    requiresEssence: Essence.crystal,
    apply: (m) => m.shardsPierce = true,
  ),
  MutationDef(
    id: 'mut_wrecking',
    name: 'Wrecking Flow',
    branch: MutationBranch.offence,
    gain: 'Shatter any obstacle regardless of mass.',
    cost: 'Steering slows 10%.',
    icon: Icons.construction_rounded,
    maxStacks: 1,
    apply: (m) {
      m.shatterAnything = true;
      m.agilityMul *= 0.90;
    },
  ),
  MutationDef(
    id: 'mut_giantslayer',
    name: 'Giantslayer',
    branch: MutationBranch.offence,
    gain: 'Boss damage up 35%.',
    cost: 'Damage taken up 10%.',
    icon: Icons.gpp_bad_rounded,
    apply: (m) {
      m.bossDamageMul *= 1.35;
      m.damageTakenMul *= 1.10;
    },
  ),

  // Defence ------------------------------------------------------------------
  MutationDef(
    id: 'mut_obsidian_skin',
    name: 'Obsidian Skin',
    branch: MutationBranch.defence,
    gain: 'Take 22% less damage.',
    cost: 'Melt rate down 8%.',
    icon: Icons.security_rounded,
    apply: (m) {
      m.damageTakenMul *= 0.78;
      m.meltRateMul *= 0.92;
    },
  ),
  MutationDef(
    id: 'mut_long_surge',
    name: 'Long Surge',
    branch: MutationBranch.defence,
    gain: 'Surge lasts 40% longer.',
    cost: 'Surge cooldown up 25%.',
    icon: Icons.bolt_rounded,
    apply: (m) {
      m.surgeDurationMul *= 1.40;
      m.surgeCooldownMul *= 1.25;
    },
  ),
  MutationDef(
    id: 'mut_rime_ward',
    name: 'Rime Ward',
    branch: MutationBranch.defence,
    gain: 'Cold seams no longer drain heat.',
    cost: '',
    icon: Icons.ac_unit_rounded,
    maxStacks: 1,
    requiresEssence: Essence.rime,
    apply: (m) => m.coldImmune = true,
  ),
  MutationDef(
    id: 'mut_stubborn_chain',
    name: 'Stubborn Chain',
    branch: MutationBranch.defence,
    gain: 'Your combo survives a hit.',
    cost: 'Score per combo step down a third.',
    icon: Icons.link_rounded,
    maxStacks: 1,
    apply: (m) {
      m.keepComboOnHit = true;
      m.comboScoreStep *= 0.66;
    },
  ),
  MutationDef(
    id: 'mut_feeding_repair',
    name: 'Feeding Repair',
    branch: MutationBranch.defence,
    gain: 'Every absorb repairs 2 integrity.',
    cost: 'Loot yield down 10%.',
    icon: Icons.healing_rounded,
    apply: (m) {
      m.integrityPerAbsorb += 2;
      m.lootMul *= 0.90;
    },
  ),
  MutationDef(
    id: 'mut_second_crust',
    name: 'Second Crust',
    branch: MutationBranch.defence,
    gain: 'Survive one fatal hit at 35% integrity.',
    cost: 'Score multiplier down 10%.',
    icon: Icons.favorite_rounded,
    maxStacks: 2,
    apply: (m) {
      m.reviveCharges += 1;
      m.scoreMul *= 0.90;
    },
  ),
  MutationDef(
    id: 'mut_thorns',
    name: 'Backdraft',
    branch: MutationBranch.defence,
    gain: 'Whatever hits you takes damage back.',
    cost: 'Heat bleeds 10% quicker.',
    icon: Icons.flare_rounded,
    apply: (m) {
      m.thornsDamage += 2.2;
      m.heatDecayMul *= 1.10;
    },
  ),

  // Motion -------------------------------------------------------------------
  MutationDef(
    id: 'mut_quicksilver',
    name: 'Quicksilver',
    branch: MutationBranch.motion,
    gain: 'Steering responds 22% faster.',
    cost: 'Mass gain down 15%, so you stay small.',
    icon: Icons.speed_rounded,
    apply: (m) {
      m.agilityMul *= 1.22;
      m.massGainMul *= 0.85;
    },
  ),
  MutationDef(
    id: 'mut_downhill',
    name: 'Downhill Rush',
    branch: MutationBranch.motion,
    gain: 'Channel speed up 14% and score with it.',
    cost: 'Less time to read what is coming.',
    icon: Icons.trending_down_rounded,
    apply: (m) {
      m.scrollSpeedMul *= 1.14;
      m.scoreMul *= 1.12;
    },
  ),
  MutationDef(
    id: 'mut_dense_core',
    name: 'Dense Core',
    branch: MutationBranch.motion,
    gain: 'Mass gain up 35%; heavier flows break more.',
    cost: 'Steering slows with the extra bulk.',
    icon: Icons.fitness_center_rounded,
    apply: (m) {
      m.massGainMul *= 1.35;
      m.agilityMul *= 0.92;
    },
  ),
  MutationDef(
    id: 'mut_no_shed',
    name: 'Held Together',
    branch: MutationBranch.motion,
    gain: 'Mass stops draining away between meals.',
    cost: '',
    icon: Icons.lock_clock_rounded,
    maxStacks: 1,
    apply: (m) => m.massDragMul = 0,
  ),
  MutationDef(
    id: 'mut_magnet',
    name: 'Hungry Field',
    branch: MutationBranch.motion,
    gain: 'Resources are pulled toward you.',
    cost: '',
    icon: Icons.filter_tilt_shift_rounded,
    maxStacks: 3,
    apply: (m) => m.magnetRadius += 190,
  ),

  // Economy ------------------------------------------------------------------
  MutationDef(
    id: 'mut_rich_seam',
    name: 'Rich Seam',
    branch: MutationBranch.economy,
    gain: 'Loot yield up 30%.',
    cost: 'Integrity pool down 8%.',
    icon: Icons.savings_rounded,
    apply: (m) => m.lootMul *= 1.30,
  ),
  MutationDef(
    id: 'mut_prospector',
    name: 'Prospector',
    branch: MutationBranch.economy,
    gain: 'Resource nodes appear 35% more often.',
    cost: 'Fewer heat vents in their place.',
    icon: Icons.travel_explore_rounded,
    apply: (m) => m.pickupRateMul *= 1.35,
  ),
  MutationDef(
    id: 'mut_short_fuse',
    name: 'Short Fuse',
    branch: MutationBranch.economy,
    gain: 'Overdrive triggers at 7 combo instead of 12.',
    cost: 'Damage taken up 12%.',
    icon: Icons.flash_on_rounded,
    maxStacks: 1,
    apply: (m) {
      m.comboThreshold = 7;
      m.damageTakenMul *= 1.12;
    },
  ),
  MutationDef(
    id: 'mut_tribute',
    name: 'Tribute',
    branch: MutationBranch.economy,
    gain: 'Score multiplier up 25%.',
    cost: 'Integrity repairs no longer come from vents.',
    icon: Icons.emoji_events_rounded,
    apply: (m) => m.scoreMul *= 1.25,
  ),
  MutationDef(
    id: 'mut_furnace_tap',
    name: 'Furnace Tap',
    branch: MutationBranch.economy,
    gain: 'Vents restore 60% more heat.',
    cost: '',
    icon: Icons.water_drop_rounded,
    requiresEssence: Essence.fire,
    apply: (m) => m.ventHeatMul *= 1.60,
  ),

  // Unstable -----------------------------------------------------------------
  MutationDef(
    id: 'mut_glass_cannon',
    name: 'Glasswake',
    branch: MutationBranch.wild,
    gain: 'Melt rate and score both up 45%.',
    cost: 'You take 40% more damage.',
    icon: Icons.warning_amber_rounded,
    maxStacks: 1,
    apply: (m) {
      m.meltRateMul *= 1.45;
      m.scoreMul *= 1.45;
      m.damageTakenMul *= 1.40;
    },
  ),
  MutationDef(
    id: 'mut_feeding_frenzy',
    name: 'Feeding Frenzy',
    branch: MutationBranch.wild,
    gain: 'Twice the creatures, twice the food.',
    cost: 'Twice the creatures.',
    icon: Icons.groups_rounded,
    maxStacks: 2,
    apply: (m) {
      m.spawnRateMul *= 1.45;
      m.lootMul *= 1.18;
      m.scoreMul *= 1.10;
    },
  ),
  MutationDef(
    id: 'mut_elite_hunt',
    name: 'Elite Hunt',
    branch: MutationBranch.wild,
    gain: 'Far more elites, and each is worth more.',
    cost: 'Elites hit hard.',
    icon: Icons.military_tech_rounded,
    apply: (m) {
      m.eliteChanceBonus += 0.28;
      m.scoreMul *= 1.15;
    },
  ),
  MutationDef(
    id: 'mut_perpetual',
    name: 'Perpetual Burn',
    branch: MutationBranch.wild,
    gain: 'Each absorb returns 6 heat on top.',
    cost: 'Base heat drains 25% faster.',
    icon: Icons.autorenew_rounded,
    apply: (m) {
      m.heatPerAbsorb += 6;
      m.heatDecayMul *= 1.25;
    },
  ),
  MutationDef(
    id: 'mut_reroll_stock',
    name: 'Restless Core',
    branch: MutationBranch.wild,
    gain: 'Two extra draft rerolls.',
    cost: '',
    icon: Icons.casino_rounded,
    maxStacks: 1,
    apply: (m) => m.rerolls += 2,
  ),
];

final Map<String, MutationDef> kMutationById = {for (final m in kMutations) m.id: m};
