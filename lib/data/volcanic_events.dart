import 'package:flutter/material.dart';

import '../core/design/palette.dart';
import 'models.dart';
import 'mutations.dart';

/// One line of the event briefing.
@immutable
class EventRule {
  const EventRule({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// A weekly world-state event.
///
/// An event never touches campaign or rush runs. It is entered from its own
/// screen, and [apply] is folded on top of the permanent perk board for that
/// run alone — which is why the rest of the game keeps behaving exactly as it
/// did before events existed.
@immutable
class VolcanicEventDef {
  const VolcanicEventDef({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.accent,
    required this.icon,
    required this.rules,
    required this.quests,
    required this.apply,
  });

  final String id;
  final String name;
  final String tagline;
  final String description;
  final Color accent;
  final IconData icon;
  final List<EventRule> rules;

  /// Objectives that only advance on runs started from the event screen.
  final List<QuestDef> quests;

  /// Mutates the run modifiers after every perk has already been applied.
  final void Function(RunModifiers mods) apply;
}

/// The rotation itself, plus the calendar maths that decides which event is
/// live. Everything is derived from the date on the device, so the feature
/// works with no connection and survives a restart — the same approach the
/// daily objectives already use.
class VolcanicCalendar {
  const VolcanicCalendar._();

  /// A Monday, used as the anchor for week counting. UTC keeps the day
  /// arithmetic exact across daylight-saving transitions.
  static final DateTime _anchor = DateTime.utc(2024, 1, 1);

  static const List<VolcanicEventDef> events = [
    VolcanicEventDef(
      id: 'ev_rime_storm',
      name: 'Rime Storm',
      tagline: 'The caldera freezes over',
      description:
          'A cold front has settled on the channel. Your heat bleeds away almost twice as fast and '
          'rime bands cut the run apart — but everything left frozen in the ice is yours to take.',
      accent: Palette.frost,
      icon: Icons.ac_unit_rounded,
      rules: [
        EventRule(
          icon: Icons.thermostat_rounded,
          title: 'Heat bleeds fast',
          body: 'Core temperature drains 45% quicker than normal.',
        ),
        EventRule(
          icon: Icons.waves_rounded,
          title: 'Cold seams everywhere',
          body: 'Rime bands cut the channel a third more often.',
        ),
        EventRule(
          icon: Icons.diamond_rounded,
          title: 'Frozen spoils',
          body: 'Every resource drop is worth 60% more.',
        ),
      ],
      quests: [
        QuestDef(
          id: 'ev_rime_absorb',
          title: 'Absorb 70 frozen creatures',
          metric: QuestMetric.absorb,
          target: 70,
          reward: 26,
          rewardKind: ResourceKind.shards,
        ),
        QuestDef(
          id: 'ev_rime_distance',
          title: 'Push 2400 metres through the ice',
          metric: QuestMetric.distance,
          target: 2400,
          reward: 340,
          rewardKind: ResourceKind.magma,
        ),
        QuestDef(
          id: 'ev_rime_combo',
          title: 'Hold a 25 chain in the cold',
          metric: QuestMetric.combo,
          target: 25,
          reward: 4,
          rewardKind: ResourceKind.cores,
        ),
      ],
      apply: _applyRimeStorm,
    ),
    VolcanicEventDef(
      id: 'ev_eruption_day',
      name: 'Eruption Day',
      tagline: 'The channel runs at full tilt',
      description:
          'The mountain has opened up. The flow is dragged downhill half again as fast, the roster '
          'spawns thicker than any other week, and the loot pouring out of it is doubled.',
      accent: Palette.lava,
      icon: Icons.local_fire_department_rounded,
      rules: [
        EventRule(
          icon: Icons.speed_rounded,
          title: 'Half again as fast',
          body: 'The channel scrolls at 150% of its normal pace.',
        ),
        EventRule(
          icon: Icons.groups_rounded,
          title: 'Thicker roster',
          body: 'Creatures arrive 30% more frequently.',
        ),
        EventRule(
          icon: Icons.auto_awesome_rounded,
          title: 'Doubled spoils',
          body: 'Every resource drop counts twice.',
        ),
      ],
      quests: [
        QuestDef(
          id: 'ev_erupt_magma',
          title: 'Bank 900 magma in the eruption',
          metric: QuestMetric.magma,
          target: 900,
          reward: 5,
          rewardKind: ResourceKind.cores,
        ),
        QuestDef(
          id: 'ev_erupt_obstacles',
          title: 'Shatter 60 obstacles at speed',
          metric: QuestMetric.obstacles,
          target: 60,
          reward: 44,
          rewardKind: ResourceKind.obsidian,
        ),
        QuestDef(
          id: 'ev_erupt_runs',
          title: 'Survive 4 eruption runs',
          metric: QuestMetric.runs,
          target: 4,
          reward: 380,
          rewardKind: ResourceKind.magma,
        ),
      ],
      apply: _applyEruptionDay,
    ),
    VolcanicEventDef(
      id: 'ev_obsidian_trial',
      name: 'Obsidian Trial',
      tagline: 'Every hit lands harder',
      description:
          'A week for players who want the numbers to mean something. Damage taken climbs steeply, '
          'you are handed exactly one second chance, and the score you walk away with is more than '
          'doubled.',
      accent: Palette.obsidian,
      icon: Icons.shield_moon_rounded,
      rules: [
        EventRule(
          icon: Icons.dangerous_rounded,
          title: 'Heavier blows',
          body: 'Incoming damage is increased by 60%.',
        ),
        EventRule(
          icon: Icons.trending_up_rounded,
          title: 'Doubled score',
          body: 'Every point banked is multiplied by 2.2.',
        ),
        EventRule(
          icon: Icons.favorite_rounded,
          title: 'One second chance',
          body: 'The trial grants a single free revive per run.',
        ),
      ],
      quests: [
        QuestDef(
          id: 'ev_obsidian_elite',
          title: 'Melt 12 elites under pressure',
          metric: QuestMetric.eliteKills,
          target: 12,
          reward: 34,
          rewardKind: ResourceKind.shards,
        ),
        QuestDef(
          id: 'ev_obsidian_flawless',
          title: 'Finish one run untouched',
          metric: QuestMetric.flawless,
          target: 1,
          reward: 6,
          rewardKind: ResourceKind.cores,
        ),
        QuestDef(
          id: 'ev_obsidian_absorb',
          title: 'Absorb 55 creatures in the trial',
          metric: QuestMetric.absorb,
          target: 55,
          reward: 52,
          rewardKind: ResourceKind.obsidian,
        ),
      ],
      apply: _applyObsidianTrial,
    ),
    VolcanicEventDef(
      id: 'ev_crystal_bloom',
      name: 'Crystal Bloom',
      tagline: 'Shards pierce everything',
      description:
          'Crystal growth has taken the channel. Your volleys come out three shards heavier, they '
          'punch straight through whatever they hit, and the elite families crowd in to meet them.',
      accent: Palette.crystal,
      icon: Icons.diamond_rounded,
      rules: [
        EventRule(
          icon: Icons.grain_rounded,
          title: 'Heavier volleys',
          body: 'Three extra shards on every volley, fired more often.',
        ),
        EventRule(
          icon: Icons.arrow_forward_rounded,
          title: 'Piercing shards',
          body: 'Shards carry through the first target they strike.',
        ),
        EventRule(
          icon: Icons.workspace_premium_rounded,
          title: 'Elite bloom',
          body: 'Elite creatures appear far more readily.',
        ),
      ],
      quests: [
        QuestDef(
          id: 'ev_crystal_elite',
          title: 'Cut down 16 elites',
          metric: QuestMetric.eliteKills,
          target: 16,
          reward: 40,
          rewardKind: ResourceKind.shards,
        ),
        QuestDef(
          id: 'ev_crystal_essence',
          title: 'Carry all five essences in one run',
          metric: QuestMetric.essencesUsed,
          target: 5,
          reward: 5,
          rewardKind: ResourceKind.cores,
        ),
        QuestDef(
          id: 'ev_crystal_absorb',
          title: 'Absorb 80 creatures in the bloom',
          metric: QuestMetric.absorb,
          target: 80,
          reward: 300,
          rewardKind: ResourceKind.magma,
        ),
      ],
      apply: _applyCrystalBloom,
    ),
    VolcanicEventDef(
      id: 'ev_molten_surge',
      name: 'Molten Surge',
      tagline: 'The flow never cools',
      description:
          'The vents are wide open all week. Creatures melt down half again as fast, surges run '
          'long and recharge quickly, and every absorption stokes the core — at the cost of a flow '
          'that answers your finger a little more slowly.',
      accent: Palette.ember,
      icon: Icons.bolt_rounded,
      rules: [
        EventRule(
          icon: Icons.blur_circular_rounded,
          title: 'Faster melt',
          body: 'Creatures break down 55% quicker.',
        ),
        EventRule(
          icon: Icons.flash_on_rounded,
          title: 'Long surges',
          body: 'Surges last 50% longer and recharge in a third less time.',
        ),
        EventRule(
          icon: Icons.fitness_center_rounded,
          title: 'Heavier flow',
          body: 'The mass you carry drags 25% harder.',
        ),
      ],
      quests: [
        QuestDef(
          id: 'ev_molten_absorb',
          title: 'Absorb 110 creatures on the surge',
          metric: QuestMetric.absorb,
          target: 110,
          reward: 420,
          rewardKind: ResourceKind.magma,
        ),
        QuestDef(
          id: 'ev_molten_combo',
          title: 'Hold a 35 chain',
          metric: QuestMetric.combo,
          target: 35,
          reward: 6,
          rewardKind: ResourceKind.cores,
        ),
        QuestDef(
          id: 'ev_molten_distance',
          title: 'Ride 3000 metres of open vent',
          metric: QuestMetric.distance,
          target: 3000,
          reward: 58,
          rewardKind: ResourceKind.alloy,
        ),
      ],
      apply: _applyMoltenSurge,
    ),
  ];

  /// Whole weeks elapsed since [_anchor]. Negative dates are impossible in
  /// practice, and Dart's `%` stays non-negative regardless.
  static int weekNumber([DateTime? at]) {
    final now = at ?? DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.difference(_anchor).inDays ~/ 7;
  }

  /// Storage key for the running week, e.g. `w110`.
  static String weekKey([DateTime? at]) => 'w${weekNumber(at)}';

  static VolcanicEventDef current([DateTime? at]) =>
      events[weekNumber(at) % events.length];

  static VolcanicEventDef next([DateTime? at]) =>
      events[(weekNumber(at) + 1) % events.length];

  /// Midnight at the start of the coming Monday, local time.
  static DateTime endsAt([DateTime? at]) {
    final now = at ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.add(Duration(days: 8 - now.weekday));
  }

  static Duration remaining([DateTime? at]) => endsAt(at).difference(at ?? DateTime.now());

  /// Full readout for the event header. Days are dropped once the week is
  /// nearly over, which is the point at which the seconds start to matter.
  static String formatRemaining(Duration left) {
    if (left <= Duration.zero) return 'A MOMENT';
    final days = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    final seconds = left.inSeconds % 60;
    if (days > 0) return '${days}D ${hours}H ${_pad(minutes)}M';
    if (hours > 0) return '${hours}H ${_pad(minutes)}M ${_pad(seconds)}S';
    return '${_pad(minutes)}M ${_pad(seconds)}S';
  }

  /// Two-unit form for tight spaces such as the menu banner.
  static String formatRemainingShort(Duration left) {
    if (left <= Duration.zero) return 'ENDING';
    final days = left.inDays;
    final hours = left.inHours % 24;
    if (days > 0) return '${days}D ${hours}H';
    final minutes = left.inMinutes % 60;
    if (left.inHours > 0) return '${left.inHours}H ${_pad(minutes)}M';
    return '${_pad(minutes)}M ${_pad(left.inSeconds % 60)}S';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  /// Resolves a saved objective back to its definition across every event, so
  /// a stored week can be restored no matter which event it belonged to.
  static QuestDef? questById(String id) {
    for (final event in events) {
      for (final quest in event.quests) {
        if (quest.id == id) return quest;
      }
    }
    return null;
  }

  static VolcanicEventDef? byId(String id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }
}

// Written as top-level functions so every [VolcanicEventDef] can stay `const`.

void _applyRimeStorm(RunModifiers mods) {
  mods.heatDecayMul *= 1.45;
  mods.hazardRateMul *= 1.35;
  mods.lootMul *= 1.6;
}

void _applyEruptionDay(RunModifiers mods) {
  mods.scrollSpeedMul *= 1.5;
  mods.spawnRateMul *= 1.3;
  mods.lootMul *= 2.0;
}

void _applyObsidianTrial(RunModifiers mods) {
  mods.damageTakenMul *= 1.6;
  mods.scoreMul *= 2.2;
  mods.reviveCharges += 1;
}

void _applyCrystalBloom(RunModifiers mods) {
  mods.volleyShards += 3;
  mods.shardsPierce = true;
  mods.volleyCooldownMul *= 0.7;
  mods.eliteChanceBonus += 0.18;
}

void _applyMoltenSurge(RunModifiers mods) {
  mods.meltRateMul *= 1.55;
  mods.surgeDurationMul *= 1.5;
  mods.surgeCooldownMul *= 0.65;
  mods.heatPerAbsorb += 6;
  mods.massDragMul *= 1.25;
}
