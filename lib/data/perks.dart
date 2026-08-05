import 'package:flutter/material.dart';

import '../core/design/palette.dart';
import 'mutations.dart';

/// The three columns of the post-run perk board.
enum PerkColumn { flow, hunger, fortune }

extension PerkColumnInfo on PerkColumn {
  String get label => switch (this) {
    PerkColumn.flow => 'Flow',
    PerkColumn.hunger => 'Hunger',
    PerkColumn.fortune => 'Fortune',
  };

  String get blurb => switch (this) {
    PerkColumn.flow => 'Survive longer and move cleaner.',
    PerkColumn.hunger => 'Eat faster and hit harder.',
    PerkColumn.fortune => 'Bend the draft and the payout.',
  };

  Color get color => switch (this) {
    PerkColumn.flow => Palette.frost,
    PerkColumn.hunger => Palette.crimson,
    PerkColumn.fortune => Palette.ember,
  };

  IconData get icon => switch (this) {
    PerkColumn.flow => Icons.waves_rounded,
    PerkColumn.hunger => Icons.local_fire_department_rounded,
    PerkColumn.fortune => Icons.auto_awesome_rounded,
  };
}

/// A permanent, spend-points upgrade earned by levelling up.
///
/// Unlike the resource-bought tracks in the lab, perks change how a *run* is
/// structured: extra draft rounds, revive charges, reroll tokens.
@immutable
class PerkDef {
  const PerkDef({
    required this.id,
    required this.name,
    required this.column,
    required this.tier,
    required this.ranks,
    required this.icon,
    required this.describe,
    required this.apply,
  });

  final String id;
  final String name;
  final PerkColumn column;

  /// 0, 1 or 2. A tier only opens once the tier above it has one rank spent.
  final int tier;
  final int ranks;
  final IconData icon;

  /// Copy for a given rank, so the card can show the exact live value.
  final String Function(int rank) describe;
  final void Function(RunModifiers m, int rank) apply;

  Color get color => column.color;
}

final List<PerkDef> kPerks = [
  // Flow ---------------------------------------------------------------------
  PerkDef(
    id: 'perk_thick_crust',
    name: 'Thick Crust',
    column: PerkColumn.flow,
    tier: 0,
    ranks: 4,
    icon: Icons.shield_outlined,
    describe: (r) => 'Damage taken reduced ${r * 5}%.',
    apply: (m, r) => m.damageTakenMul *= 1 - r * 0.05,
  ),
  PerkDef(
    id: 'perk_slick',
    name: 'Slickline',
    column: PerkColumn.flow,
    tier: 1,
    ranks: 3,
    icon: Icons.air_rounded,
    describe: (r) => 'Steering ${r * 6}% sharper.',
    apply: (m, r) => m.agilityMul *= 1 + r * 0.06,
  ),
  PerkDef(
    id: 'perk_second_wind',
    name: 'Second Wind',
    column: PerkColumn.flow,
    tier: 2,
    ranks: 1,
    icon: Icons.favorite_border_rounded,
    describe: (r) => r == 0 ? 'Survive one fatal hit each run.' : 'One revive per run, at 35% integrity.',
    apply: (m, r) => m.reviveCharges += r,
  ),

  // Hunger -------------------------------------------------------------------
  PerkDef(
    id: 'perk_kindling',
    name: 'Kindling',
    column: PerkColumn.hunger,
    tier: 0,
    ranks: 4,
    icon: Icons.whatshot_rounded,
    describe: (r) => 'Melt rate up ${r * 5}%.',
    apply: (m, r) => m.meltRateMul *= 1 + r * 0.05,
  ),
  PerkDef(
    id: 'perk_ember_return',
    name: 'Ember Return',
    column: PerkColumn.hunger,
    tier: 1,
    ranks: 3,
    icon: Icons.autorenew_rounded,
    describe: (r) => 'Each absorb returns ${r * 2} heat.',
    apply: (m, r) => m.heatPerAbsorb += r * 2,
  ),
  PerkDef(
    id: 'perk_open_maw',
    name: 'Open Maw',
    column: PerkColumn.hunger,
    tier: 2,
    ranks: 2,
    icon: Icons.open_in_full_rounded,
    describe: (r) => 'Absorption reach up ${r * 5}%.',
    apply: (m, r) => m.reachMul *= 1 + r * 0.05,
  ),

  // Fortune ------------------------------------------------------------------
  PerkDef(
    id: 'perk_prospect',
    name: 'Prospecting',
    column: PerkColumn.fortune,
    tier: 0,
    ranks: 4,
    icon: Icons.savings_rounded,
    describe: (r) => 'Loot yield up ${r * 6}%.',
    apply: (m, r) => m.lootMul *= 1 + r * 0.06,
  ),
  PerkDef(
    id: 'perk_restless',
    name: 'Restless Draft',
    column: PerkColumn.fortune,
    tier: 1,
    ranks: 2,
    icon: Icons.casino_rounded,
    describe: (r) => '$r extra reroll${r == 1 ? '' : 's'} in the vent chamber.',
    apply: (m, r) => m.rerolls += r,
  ),
  PerkDef(
    id: 'perk_extra_chamber',
    name: 'Deep Chamber',
    column: PerkColumn.fortune,
    tier: 2,
    ranks: 1,
    icon: Icons.add_circle_outline_rounded,
    describe: (r) => r == 0 ? 'One more mutation draft per run.' : 'One extra draft round every run.',
    apply: (m, r) => m.bonusDraftRounds += r,
  ),
];

final Map<String, PerkDef> kPerkById = {for (final p in kPerks) p.id: p};

int kPerkTotalRanks = kPerks.fold(0, (sum, p) => sum + p.ranks);
