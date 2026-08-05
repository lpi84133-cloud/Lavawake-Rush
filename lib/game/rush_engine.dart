import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../data/game_data.dart';
import '../data/models.dart';
import '../data/mutations.dart';

/// Simulation coordinates. The world is a fixed 1000 units tall; width follows
/// the viewport aspect ratio so circles stay circular at any screen size.
const double kWorldHeight = 1000;

/// World units per in-fiction metre, used for level distance and the HUD.
const double kUnitsPerMetre = 11.0;

/// The high-level state machine of a run. The three roguelite beats -
/// [chamber], [fork] and [pact] - freeze the simulation and hand control to an
/// overlay in the gameplay screen.
enum RushPhase { intro, running, chamber, fork, pact, crisis, paused, boss, won, lost }

enum EntityKind { enemy, obstacle, pickup, vent, coldSeam, boss, hostileShot, playerShard }

/// One simulated thing in the channel. A single mutable class keeps the update
/// loop allocation-free once a run is under way.
class Entity {
  Entity({
    required this.kind,
    required this.sprite,
    required this.x,
    required this.y,
    required this.radius,
    this.essence,
    this.rarity = Rarity.common,
    this.hp = 1,
    this.armor = 0,
    this.mass = 0,
    this.defId,
    this.vx = 0,
    this.vy = 0,
    this.width = 0,
    this.payload = 0,
    this.resource,
  }) : maxHp = hp,
       spin = 0;

  final EntityKind kind;
  final String sprite;
  final Essence? essence;
  final Rarity rarity;
  final String? defId;
  final ResourceKind? resource;

  double x;
  double y;
  double vx;
  double vy;
  double radius;

  /// Horizontal extent for band-shaped entities such as cold seams.
  double width;

  double hp;
  final double maxHp;
  final double armor;
  final double mass;
  final double payload;

  double melt = 0;
  double spin;
  double flash = 0;
  bool dead = false;
  bool grazed = false;
  double shotTimer = 1.4;

  double get meltRatio => (melt).clamp(0.0, 1.0);
  double get hpRatio => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);
}

class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.hue);

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double size;

  /// 0 = ember orange, 1 = the entity's own tint.
  final double hue;
  double age = 0;

  double get t => (age / life).clamp(0.0, 1.0);
}

class FloatingText {
  FloatingText(this.x, this.y, this.text, this.tint);

  double x;
  double y;
  final String text;
  final int tint;
  double age = 0;
}

/// Configuration handed to the engine when a run starts.
class RunConfig {
  const RunConfig({
    required this.level,
    required this.endless,
    required this.heatBonus,
    required this.massBonus,
    required this.speedBonus,
    required this.absorptionBonus,
    required this.integrityBonus,
    required this.surgeBonus,
    required this.shieldBonus,
    required this.harvestBonus,
    required this.laneControls,
    required this.particleScale,
    required this.modifiers,
    this.seed,
  });

  final LevelDef? level;
  final bool endless;
  final double heatBonus;
  final double massBonus;
  final double speedBonus;
  final double absorptionBonus;
  final double integrityBonus;
  final double surgeBonus;
  final double shieldBonus;
  final double harvestBonus;
  final bool laneControls;
  final double particleScale;

  /// Permanent-perk contribution, pre-seeded before the run and further stacked
  /// by in-run mutation drafts.
  final RunModifiers modifiers;
  final int? seed;

  double get difficulty => endless ? 1.4 : (level?.difficulty ?? 1);

  double get targetDistance => endless ? double.infinity : (level?.distance ?? 1000);

  bool get isBossLevel => !endless && (level?.isBoss ?? false);

  int get regionIndex => endless ? 5 : (level?.regionIndex ?? 0);
}

/// The absorbed-material state that drives the player's active form.
class EssenceMeter {
  final Map<Essence, double> charge = {for (final e in Essence.values) e: 0};

  void add(Essence essence, double amount) {
    charge[essence] = (charge[essence]! + amount).clamp(0.0, 1.0);
  }

  void decay(double dt, double rate) {
    for (final essence in Essence.values) {
      final value = charge[essence]!;
      if (value > 0) charge[essence] = math.max(0, value - rate * dt);
    }
  }

  List<Essence> get dominant {
    final sorted = Essence.values.where((e) => charge[e]! > 0.16).toList()
      ..sort((a, b) => charge[b]!.compareTo(charge[a]!));
    return sorted;
  }

  double get total => charge.values.fold(0.0, (a, b) => a + b);
}

/// A pending choice offered to the player. Reused for the draft, the fork and
/// the pact so the overlay code has one shape to render.
class RunChoice {
  RunChoice({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.gain,
    required this.cost,
    required this.branch,
    this.mutation,
  });

  final String id;
  final String title;
  final String subtitle;
  final String gain;
  final String cost;
  final MutationBranch branch;
  final MutationDef? mutation;
}

/// The whole gameplay simulation. Owns no widgets and no rendering, so it can be
/// stepped from a ticker and drawn by a `CustomPainter`.
class RushEngine {
  RushEngine(this.config) : _rng = math.Random(config.seed ?? DateTime.now().microsecondsSinceEpoch) {
    mods = config.modifiers;
    maxHeat = 100 * config.heatBonus;
    heat = maxHeat * 0.78;
    maxIntegrity = 100 * config.integrityBonus * (1 - _integrityPenalty());
    integrity = maxIntegrity;
    _region = GameData.regions[config.regionIndex];
    _pool = [
      for (final prefix in _region.families) ...GameData.family(prefix),
    ];
    if (_pool.isEmpty) _pool = GameData.family('golem_');
    _reroll = mods.rerolls;
    _plannedChambers = _planChambers();
  }

  final RunConfig config;
  final math.Random _rng;
  late final RunModifiers mods;

  /// Bumped once per simulated frame; the painter listens to this.
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  /// Bumped a few times a second so the HUD can rebuild without per-frame cost.
  final ValueNotifier<int> hudTick = ValueNotifier<int>(0);

  /// Bumped whenever a decision overlay opens or closes, so the gameplay screen
  /// can swap its overlay stack.
  final ValueNotifier<int> overlayTick = ValueNotifier<int>(0);

  late final RegionDef _region;
  late List<EnemyDef> _pool;

  // ------------------------------------------------------------------- state

  RushPhase phase = RushPhase.intro;
  double worldWidth = 1800;

  final List<Entity> entities = [];
  final List<Particle> particles = [];
  final List<FloatingText> floaters = [];
  final EssenceMeter essences = EssenceMeter();

  double playerX = 260;
  double playerY = kWorldHeight * 0.5;
  double _targetX = 260;
  double _targetY = kWorldHeight * 0.5;

  double heat = 70;
  double maxHeat = 100;
  double integrity = 100;
  double maxIntegrity = 100;
  double mass = 0.12;

  double scrollSpeed = 430;
  double distance = 0;
  double elapsed = 0;
  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int absorbed = 0;
  int eliteAbsorbed = 0;
  int bossesFelled = 0;
  int obstaclesSmashed = 0;
  bool damageTaken = false;

  final Set<Essence> essencesUsed = {};
  final Set<String> discovered = {};
  final Map<ResourceKind, int> loot = {for (final r in ResourceKind.values) r: 0};

  // Roguelite run state ------------------------------------------------------
  final List<MutationDef> takenMutations = [];
  final Map<String, int> _mutationStacks = {};
  List<RunChoice> pendingChoices = [];
  String choiceTitle = '';
  String choicePrompt = '';
  bool choiceIsPact = false;
  int _reroll = 0;
  int overdriveStacks = 0;
  double overdriveTimer = 0;
  int revivesLeft = 0;

  List<double> _plannedChambers = [];
  int _nextChamber = 0;
  bool _forkOffered = false;
  bool _crisisArmed = true;

  double surgeTimer = 0;
  double surgeCooldown = 0;
  double eruptCharge = 0;
  double volleyCooldown = 0;
  double shake = 0;
  double _damageCooldown = 0;
  double _spawnTimer = 0.9;
  double _pickupTimer = 2.4;
  double _hazardTimer = 6;
  double _hudAccumulator = 0;
  double _flashHit = 0;
  Entity? boss;
  int bossPhase = 1;
  bool bossEnraged = false;
  String? bossCallout;
  double bossCalloutAt = -10;
  String? lastAbsorbedName;
  double lastAbsorbedAt = -10;

  // --------------------------------------------------------------- derivation

  double get surgeDuration => 1.15 * config.surgeBonus * mods.surgeDurationMul;
  double get surgeCooldownLength => 6.5 / config.surgeBonus * mods.surgeCooldownMul;
  bool get surging => surgeTimer > 0;
  bool get canSurge => surgeCooldown <= 0 && heat > 18 && phase == RushPhase.running;
  bool get canErupt => eruptCharge >= 1 && (phase == RushPhase.running || phase == RushPhase.boss);
  bool get canVolley =>
      volleyCooldown <= 0 &&
      essences.charge[Essence.crystal]! > 0.18 &&
      (phase == RushPhase.running || phase == RushPhase.boss);
  bool get overdrive => overdriveTimer > 0;
  int get rerollsLeft => _reroll;

  /// True while the simulation is halted for a decision overlay.
  bool get awaitingChoice =>
      phase == RushPhase.chamber || phase == RushPhase.fork || phase == RushPhase.pact;

  double get heatRatio => (heat / maxHeat).clamp(0.0, 1.0);
  double get integrityRatio => (integrity / maxIntegrity).clamp(0.0, 1.0);
  double get hitFlash => _flashHit.clamp(0.0, 1.0);

  double get progress => config.endless
      ? (distance / 4000).clamp(0.0, 1.0)
      : (distance / config.targetDistance).clamp(0.0, 1.0);

  double get playerRadius => 44 + mass * 105;

  RegionDef get region => _region;

  double _integrityPenalty() {
    // Rich Seam and similar economy mutations shave the integrity pool; kept
    // small so a build never becomes unplayable.
    var penalty = 0.0;
    for (final m in takenMutations) {
      if (m.id == 'mut_rich_seam') penalty += 0.08;
    }
    return penalty.clamp(0.0, 0.4);
  }

  /// The composite form implied by the two strongest absorbed materials.
  FormDef get activeForm {
    final dominant = essences.dominant;
    if (dominant.length >= 5 && essences.charge.values.every((v) => v > 0.42)) {
      return GameData.forms.last;
    }
    if (dominant.length >= 2) {
      final pair = {dominant[0], dominant[1]};
      for (final form in GameData.forms) {
        if (form.recipe.length == 2 && form.recipe.toSet().containsAll(pair)) return form;
      }
    }
    return GameData.forms.first;
  }

  /// The flow visibly grows through the eight evolution sprites as it feeds.
  String get playerSprite => _playerStageSprites[switch (mass) {
    < 0.18 => 0,
    < 0.30 => 1,
    < 0.45 => 2,
    < 0.62 => 3,
    < 0.80 => 4,
    < 1.05 => 5,
    < 1.35 => 6,
    _ => 7,
  }];

  static const List<String> _playerStageSprites = [
    'player_stage_1_droplet',
    'player_stage_2_splash',
    'player_stage_3_crust',
    'player_stage_4_basalt',
    'player_stage_5_forged',
    'player_stage_6_inferno',
    'player_stage_7_crystalline',
    'player_stage_8_prime',
  ];

  // ------------------------------------------------------------------- setup

  /// Distances (as run progress, 0..1) at which a vent chamber interrupts play.
  List<double> _planChambers() {
    if (config.endless) {
      // Endless chambers are triggered by distance milestones instead; see
      // [_advanceChambersEndless].
      return const [];
    }
    final rounds = 1 + config.regionIndex ~/ 3 + mods.bonusDraftRounds;
    return [for (var i = 1; i <= rounds; i++) i / (rounds + 1)];
  }

  int _endlessChamberMilestone = 1;

  // ------------------------------------------------------------------ control

  void setViewport(Size size) {
    if (size.height <= 0) return;
    worldWidth = kWorldHeight * (size.width / size.height);
    _targetX = _targetX.clamp(playerRadius + 20, worldWidth * 0.62);
  }

  void begin() {
    if (phase == RushPhase.intro) {
      phase = RushPhase.running;
      revivesLeft = mods.reviveCharges;
      // Bonus draft rounds are handed out immediately as an opening chamber.
      _openChamber(opening: true);
    }
  }

  void pause() {
    if (phase == RushPhase.running || phase == RushPhase.boss) phase = RushPhase.paused;
    _notifyHud();
  }

  void resume() {
    if (phase == RushPhase.paused) phase = boss != null ? RushPhase.boss : RushPhase.running;
    _notifyHud();
  }

  void abandon() {
    if (phase == RushPhase.won || phase == RushPhase.lost) return;
    phase = RushPhase.lost;
    _notifyHud();
  }

  void steerTo(Offset worldPoint) {
    _targetX = worldPoint.dx.clamp(playerRadius + 16, worldWidth * 0.62);
    _targetY = worldPoint.dy.clamp(playerRadius * 0.6, kWorldHeight - playerRadius * 0.6);
  }

  void steerToLane(int lane) {
    _targetY = kWorldHeight * switch (lane) {
      0 => 0.22,
      1 => 0.5,
      _ => 0.78,
    };
  }

  void nudge(double dy) {
    _targetY = (_targetY + dy).clamp(playerRadius * 0.6, kWorldHeight - playerRadius * 0.6);
  }

  bool surge() {
    if (!canSurge) return false;
    surgeTimer = surgeDuration;
    surgeCooldown = surgeCooldownLength;
    heat -= 16;
    shake = math.max(shake, 7);
    _spawnBurst(playerX, playerY, 26, Essence.fire);
    return true;
  }

  bool erupt() {
    if (!canErupt) return false;
    eruptCharge = 0;
    shake = math.max(shake, 14);
    _spawnBurst(playerX, playerY, 46, Essence.fire);
    final reach = 420.0 * mods.eruptReachMul;
    for (final entity in entities) {
      if (entity.dead) continue;
      final dx = entity.x - playerX;
      final dy = entity.y - playerY;
      if (dx * dx + dy * dy > reach * reach) continue;
      switch (entity.kind) {
        case EntityKind.enemy:
          _absorb(entity, instant: true);
        case EntityKind.obstacle:
          _shatter(entity);
        case EntityKind.hostileShot:
          entity.dead = true;
        case EntityKind.boss:
          _damageBoss(entity, 2.6 * mods.bossDamageMul);
        case EntityKind.pickup:
        case EntityKind.vent:
        case EntityKind.coldSeam:
        case EntityKind.playerShard:
          break;
      }
    }
    _addFloater(playerX, playerY - 70, 'ERUPT', 0xFFFFB020);
    return true;
  }

  bool volley() {
    if (!canVolley) return false;
    volleyCooldown = 0.85 / config.absorptionBonus * mods.volleyCooldownMul;
    essences.add(Essence.crystal, -0.16);
    heat -= 4;
    final count = mods.volleyShards;
    final mid = (count - 1) / 2;
    for (var i = 0; i < count; i++) {
      final offset = (i - mid);
      entities.add(
        Entity(
          kind: EntityKind.playerShard,
          sprite: 'fx_shard_scatter',
          x: playerX + playerRadius * 0.7,
          y: playerY + offset * 42,
          radius: 26,
          vx: 1250,
          vy: offset * 60,
        ),
      );
    }
    return true;
  }

  // --------------------------------------------------------------------- loop

  void update(double dt) {
    if (phase == RushPhase.paused || phase == RushPhase.won || phase == RushPhase.lost) return;
    if (phase == RushPhase.intro || awaitingChoice) return;

    // Clamp the step so a dropped frame cannot teleport anything through a wall.
    dt = dt.clamp(0.0, 1 / 30);
    elapsed += dt;

    _advanceSpeed(dt);
    _advancePlayer(dt);
    _advanceMeters(dt);
    _advanceEntities(dt);
    _advanceSpawns(dt);
    _advanceParticles(dt);
    _advanceChambers();
    _checkPhase();
    _enforceLimits();

    frame.value++;
    _hudAccumulator += dt;
    if (_hudAccumulator >= 1 / 18) {
      _hudAccumulator = 0;
      _notifyHud();
    }
  }

  void _advanceSpeed(double dt) {
    final ramp = config.endless ? 1 + elapsed / 90 : 1 + progress * 0.35;
    final base = (400 + config.difficulty * 44) * mods.scrollSpeedMul;
    final target = base * ramp * (surging ? 1.55 : 1) * (overdrive ? 1.18 : 1);
    scrollSpeed += (target - scrollSpeed) * math.min(1, dt * 3.2);
    // Hard sanity clamp: a non-finite or runaway scroll speed would break the
    // off-screen culling below and let the entity list grow without bound.
    scrollSpeed = scrollSpeed.isFinite ? scrollSpeed.clamp(60.0, 3600.0) : 430.0;
    if (phase != RushPhase.boss) distance += scrollSpeed * dt / kUnitsPerMetre;
    if (!distance.isFinite) distance = 0;
    score += (scrollSpeed * dt / 26 * mods.scoreMul).round();
  }

  void _advancePlayer(double dt) {
    // Heavier flows answer the finger more slowly; this is the mass trade-off.
    // Base raised 9.5→13 so the initial feel is snappier; mass coefficient
    // lowered 0.55→0.30 so late-game heavy builds stay steerable.
    final agility = (13.0 * config.speedBonus * mods.agilityMul) / (1 + mass * 0.30);
    playerX += (_targetX - playerX) * math.min(1, dt * agility);
    playerY += (_targetY - playerY) * math.min(1, dt * agility);
    if (!playerX.isFinite) playerX = _targetX = worldWidth * 0.3;
    if (!playerY.isFinite) playerY = _targetY = kWorldHeight * 0.5;
    playerY = playerY.clamp(playerRadius * 0.55, kWorldHeight - playerRadius * 0.55);

    if (surgeTimer > 0) surgeTimer -= dt;
    if (surgeCooldown > 0) surgeCooldown -= dt;
    if (volleyCooldown > 0) volleyCooldown -= dt;
    if (_damageCooldown > 0) _damageCooldown -= dt;
    if (overdriveTimer > 0) {
      overdriveTimer -= dt;
      if (overdriveTimer <= 0) overdriveStacks = 0;
    }
    if (shake > 0) shake = math.max(0, shake - dt * 26);
    if (_flashHit > 0) _flashHit = math.max(0, _flashHit - dt * 3.4);

    // Magnet pulls loose resources toward the flow.
    if (mods.magnetRadius > 0) {
      for (final entity in entities) {
        if (entity.dead || entity.kind != EntityKind.pickup) continue;
        final dx = playerX - entity.x;
        final dy = playerY - entity.y;
        final d2 = dx * dx + dy * dy;
        if (d2 < mods.magnetRadius * mods.magnetRadius && d2 > 1) {
          final d = math.sqrt(d2);
          entity.x += dx / d * 520 * dt;
          entity.y += dy / d * 520 * dt;
        }
      }
    }

    // A cheap heat trail sells the sense of a molten body in motion.
    if (particles.length < 220 * config.particleScale && _rng.nextDouble() < 0.7) {
      particles.add(
        Particle(
          playerX - playerRadius * 0.5,
          playerY + (_rng.nextDouble() - 0.5) * playerRadius,
          -scrollSpeed * 0.35 - _rng.nextDouble() * 120,
          (_rng.nextDouble() - 0.5) * 60,
          0.5 + _rng.nextDouble() * 0.4,
          6 + _rng.nextDouble() * 10,
          0,
        ),
      );
    }
  }

  void _advanceMeters(double dt) {
    final form = activeForm;
    // Rates reduced ~14 % so early-game heat pressure is meaningful but not instant-death.
    var decay = 2.9;
    if (form.id == 'form_cinderstone') decay = 4.4;
    if (form.id == 'form_blackiron') decay = 2.2;
    if (form.id == 'form_primordial') decay = 3.7;
    heat = math.max(0, heat - decay * dt / config.heatBonus * mods.heatDecayMul);

    essences.decay(dt, form.id == 'form_primordial' ? 0.075 : 0.052);

    // Mass slowly sheds so the flow never becomes permanently unsteerable.
    mass = math.max(0.10, mass - dt * 0.012 * mods.massDragMul);
  }

  void _advanceEntities(double dt) {
    final scroll = scrollSpeed * dt;
    for (final entity in entities) {
      if (entity.dead) continue;
      entity.x -= scroll;
      entity.x += entity.vx * dt;
      entity.y += entity.vy * dt;
      entity.spin += dt;
      if (entity.flash > 0) entity.flash = math.max(0, entity.flash - dt * 4);

      switch (entity.kind) {
        case EntityKind.enemy:
          // Enemies drift toward the flow just enough to feel aware of it.
          entity.y += math.sin(elapsed * 1.6 + entity.spin) * 18 * dt;
          if (entity.rarity == Rarity.elite) {
            entity.y += (playerY - entity.y).sign * 26 * dt;
          }
        case EntityKind.boss:
          _advanceBoss(entity, dt);
        case EntityKind.playerShard:
          if (entity.x > worldWidth + 80) entity.dead = true;
        case EntityKind.pickup:
        case EntityKind.vent:
          entity.y += math.sin(elapsed * 2.2 + entity.spin) * 26 * dt;
        case EntityKind.obstacle:
        case EntityKind.hostileShot:
        case EntityKind.coldSeam:
          break;
      }

      if (entity.kind == EntityKind.coldSeam) {
        if (entity.x + entity.width < -120) entity.dead = true;
      } else if (entity.kind != EntityKind.boss && entity.x < -220) {
        if (entity.kind == EntityKind.enemy) combo = 0;
        entity.dead = true;
      }
    }

    _resolveCollisions(dt);
    entities.removeWhere((e) => e.dead);
  }

  void _advanceBoss(Entity bossEntity, double dt) {
    final anchor = worldWidth * 0.70;
    bossEntity.x += (anchor - bossEntity.x) * math.min(1, dt * 1.6);
    final sway = bossEnraged ? 0.34 : 0.26;
    bossEntity.y = kWorldHeight * 0.5 + math.sin(elapsed * (bossEnraged ? 1.15 : 0.85)) * kWorldHeight * sway;

    // Phase transitions at the two-thirds and one-third HP marks change the
    // attack cadence and announce themselves through a callout.
    final ratio = bossEntity.hpRatio;
    if (bossPhase == 1 && ratio <= 0.66) {
      bossPhase = 2;
      _bossCallout('The core splits open');
      _spawnBurst(bossEntity.x, bossEntity.y, 40, bossEntity.essence);
    } else if (bossPhase == 2 && ratio <= 0.33) {
      bossPhase = 3;
      bossEnraged = true;
      _bossCallout('Enraged - it is coming apart');
      shake = math.max(shake, 16);
    }

    bossEntity.shotTimer -= dt;
    if (bossEntity.shotTimer <= 0) {
      final cadence = math.max(0.4, (1.5 - config.difficulty * 0.08) / bossPhase);
      bossEntity.shotTimer = cadence;
      final spread = bossPhase + 1;
      for (var i = 0; i < spread; i++) {
        final off = (i - (spread - 1) / 2);
        entities.add(
          Entity(
            kind: EntityKind.hostileShot,
            sprite: off == 0 ? 'fx_magma_droplets' : 'fx_ember_spray',
            x: bossEntity.x - bossEntity.radius * 0.6,
            y: bossEntity.y + off * 90,
            radius: 34,
            vx: -260 - config.difficulty * 12,
            vy: (playerY - bossEntity.y) * 0.4 + off * 40,
            payload: 7,
          ),
        );
      }
    }
  }

  void _resolveCollisions(double dt) {
    final form = activeForm;
    final absorbRate = config.absorptionBonus *
        mods.meltRateMul *
        switch (form.id) {
          'form_cinderstone' => 1.35,
          'form_prismfire' => 1.15,
          'form_glacierheart' => 0.75,
          'form_primordial' => 1.45,
          _ => 1.0,
        };
    final reachBonus = playerRadius * (mods.reachMul - 1);

    for (final entity in entities) {
      if (entity.dead) continue;

      if (entity.kind == EntityKind.coldSeam) {
        final inside = playerX + playerRadius > entity.x && playerX - playerRadius < entity.x + entity.width;
        if (inside && form.id != 'form_glacierheart' && !mods.coldImmune) {
          heat = math.max(0, heat - 26 * dt);
          if (_rng.nextDouble() < 0.2) _spawnBurst(playerX, playerY, 2, Essence.rime);
        }
        continue;
      }

      // Player shards melt whatever they touch on their way out of the screen.
      if (entity.kind == EntityKind.playerShard) {
        for (final target in entities) {
          if (target.dead || target == entity) continue;
          if (target.kind != EntityKind.enemy && target.kind != EntityKind.boss) continue;
          if (!_overlaps(entity, target)) continue;
          if (!mods.shardsPierce) entity.dead = true;
          if (target.kind == EntityKind.boss) {
            _damageBoss(target, 0.9 * mods.bossDamageMul);
          } else {
            target.melt += 0.55;
            target.flash = 1;
            if (target.melt >= 1) _absorb(target);
          }
          if (!mods.shardsPierce) break;
        }
        continue;
      }

      final dx = entity.x - playerX;
      final dy = entity.y - playerY;
      final reach = entity.radius + playerRadius + reachBonus;
      if (dx * dx + dy * dy > reach * reach) continue;

      switch (entity.kind) {
        case EntityKind.pickup:
          _collect(entity);
        case EntityKind.vent:
          heat = math.min(maxHeat, heat + 42 * mods.ventHeatMul);
          entity.dead = true;
          _addFloater(entity.x, entity.y, '+HEAT', 0xFFFF8A3D);
          _spawnBurst(entity.x, entity.y, 12, Essence.fire);
        case EntityKind.hostileShot:
          entity.dead = true;
          _hurt(entity.payload);
        case EntityKind.obstacle:
          final def = GameData.obstacles.firstWhere(
            (o) => o.id == entity.defId,
            orElse: () => GameData.obstacles.first,
          );
          if (surging || mods.shatterAnything || mass * config.massBonus >= def.massToBreak) {
            _shatter(entity);
          } else {
            _hurt(def.damage);
            entity.x += 90;
            heat = math.max(0, heat - 6);
          }
        case EntityKind.enemy:
          if (surging) {
            _absorb(entity, instant: true);
          } else if (heatRatio >= entity.armor) {
            entity.melt += absorbRate * dt * (0.55 + heatRatio * 1.15) / math.max(0.4, entity.maxHp * 0.36);
            entity.flash = 0.8;
            heat = math.max(0, heat - 5 * dt);
            if (entity.melt >= 1) _absorb(entity);
          } else {
            // Not hot enough: the armour holds and the flow pays for it.
            _hurt(5 + entity.rarity.index * 2.5);
            entity.x += 70;
          }
        case EntityKind.boss:
          if (surging || heatRatio >= entity.armor) {
            _damageBoss(entity, dt * absorbRate * 1.5 * (0.5 + heatRatio) * mods.bossDamageMul);
          } else {
            _hurt(14);
          }
        case EntityKind.coldSeam:
        case EntityKind.playerShard:
          break;
      }
    }

    // Graze pass: enemies that brush very close but miss reward the player with
    // a heat tick, erupt charge and a score bonus. Encourages risky play.
    if (!surging) {
      for (final entity in entities) {
        if (entity.dead || entity.grazed || entity.kind != EntityKind.enemy) continue;
        final dx = entity.x - playerX;
        final dy = entity.y - playerY;
        final baseReach = entity.radius + playerRadius + reachBonus;
        final grazeReach = baseReach * 1.72;
        final d2 = dx * dx + dy * dy;
        if (d2 > baseReach * baseReach && d2 <= grazeReach * grazeReach) {
          entity.grazed = true;
          heat = math.min(maxHeat, heat + 7 * mods.ventHeatMul);
          eruptCharge = math.min(1, eruptCharge + 0.022 * mods.eruptGainMul);
          score += (18 * mods.scoreMul).round();
          _addFloater(entity.x, entity.y - entity.radius * 0.6, 'GRAZE', 0xFFFFE650);
          _spawnBurst(entity.x, entity.y, 3, entity.essence);
        }
      }
    }
  }

  void _collect(Entity entity) {
    entity.dead = true;
    final kind = entity.resource ?? ResourceKind.magma;
    final amount = (entity.payload * config.harvestBonus * mods.lootMul).round().clamp(1, 999);
    loot[kind] = loot[kind]! + amount;
    score += (20 * mods.scoreMul).round();
    _addFloater(entity.x, entity.y, '+$amount', kind.color.toARGB32());
    _spawnBurst(entity.x, entity.y, 8, null);
  }

  void _shatter(Entity entity) {
    entity.dead = true;
    obstaclesSmashed++;
    score += (30 + (combo * 2) * mods.scoreMul).round();
    if (_rng.nextDouble() < 0.5) {
      loot[ResourceKind.obsidian] = loot[ResourceKind.obsidian]! + 1;
    }
    shake = math.max(shake, 5);
    _spawnBurst(entity.x, entity.y, 16, Essence.stone);
  }

  void _absorb(Entity entity, {bool instant = false}) {
    if (entity.dead) return;
    entity.dead = true;
    absorbed++;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    if (entity.rarity == Rarity.elite) eliteAbsorbed++;

    // Overdrive: hit the combo threshold and the flow briefly goes molten,
    // melting on contact and scoring more.
    if (combo > 0 && combo % mods.comboThreshold == 0) {
      overdriveStacks = math.min(5, overdriveStacks + 1);
      overdriveTimer = 4.5;
      _addFloater(playerX, playerY - 90, 'OVERDRIVE', 0xFFFF5A1F);
      shake = math.max(shake, 8);
    }

    final essence = entity.essence;
    if (essence != null) {
      essences.add(essence, instant ? 0.30 : 0.38);
      essencesUsed.add(essence);
    }
    mass = math.min(1.9, mass + entity.mass * config.massBonus * mods.massGainMul * 0.65);
    heat = math.min(maxHeat, heat + (essence == Essence.fire ? 23 : 11) + mods.heatPerAbsorb);
    eruptCharge = math.min(1, eruptCharge + 0.10 * mods.eruptGainMul);
    integrity = math.min(maxIntegrity, integrity + 1.4 + mods.integrityPerAbsorb);

    final overdriveMul = overdrive ? 1.4 : 1.0;
    final multiplier = (1 + combo * mods.comboScoreStep).clamp(1.0, 3.0) * mods.scoreMul * overdriveMul;
    final base = 55 + entity.rarity.index * 45;
    score += (base * multiplier).round();

    if (entity.defId != null) discovered.add(entity.defId!);
    final def = entity.defId == null ? null : GameData.enemyById[entity.defId];
    if (def != null) {
      lastAbsorbedName = def.name;
      lastAbsorbedAt = elapsed;
      loot[ResourceKind.magma] = loot[ResourceKind.magma]! +
          ((3 + def.threat) * config.harvestBonus * mods.lootMul).round();
      if (def.rarity == Rarity.elite && _rng.nextDouble() < 0.35) {
        final bonusKind = switch (def.essence) {
          Essence.crystal => ResourceKind.shards,
          Essence.metal => ResourceKind.alloy,
          Essence.rime => ResourceKind.obsidian,
          _ => ResourceKind.magma,
        };
        loot[bonusKind] = loot[bonusKind]! + 1;
      }
    }

    _spawnBurst(entity.x, entity.y, 20, essence);
    _addFloater(entity.x, entity.y, combo > 2 ? 'x$combo' : '+${(base * multiplier).round()}', 0xFFFFC13D);
    shake = math.max(shake, 4);
  }

  void _damageBoss(Entity bossEntity, double amount) {
    bossEntity.hp -= amount;
    bossEntity.flash = 1;
    heat = math.max(0, heat - amount * 2.2);
    score += (amount * 90 * mods.scoreMul).round();
    if (_rng.nextDouble() < 0.4) _spawnBurst(bossEntity.x - bossEntity.radius * 0.4, bossEntity.y, 6, bossEntity.essence);
    if (bossEntity.hp <= 0) {
      bossEntity.dead = true;
      boss = null;
      bossesFelled++;
      score += (2600 * mods.scoreMul).round();
      shake = 20;
      _spawnBurst(bossEntity.x, bossEntity.y, 70, bossEntity.essence);
      if (bossEntity.defId != null) discovered.add(bossEntity.defId!);
      loot[ResourceKind.cores] = loot[ResourceKind.cores]! + 2;
      phase = RushPhase.won;
      _notifyHud();
    }
  }

  void _hurt(double amount) {
    if (surging || _damageCooldown > 0) return;
    final form = activeForm;
    var mitigation = 1 / config.shieldBonus * mods.damageTakenMul;
    if (form.id == 'form_blackiron') mitigation *= 0.62;
    if (form.id == 'form_slagsteel') mitigation *= 0.80;
    if (form.id == 'form_prismfire') mitigation *= 1.18;
    if (form.id == 'form_primordial') mitigation *= 0.7;

    integrity -= amount * mitigation;
    if (!mods.keepComboOnHit) combo = 0;
    damageTaken = true;
    _damageCooldown = 0.55;
    _flashHit = 1;
    shake = math.max(shake, 10);
    _spawnBurst(playerX, playerY, 14, null);

    if (mods.thornsDamage > 0) {
      for (final e in entities) {
        if (e.dead) continue;
        if (e.kind == EntityKind.enemy && _overlaps(_playerHitbox(), e)) {
          e.melt += 0.4;
          e.flash = 1;
          if (e.melt >= 1) _absorb(e);
        }
      }
    }

    if (integrity <= 0) {
      if (revivesLeft > 0) {
        revivesLeft--;
        integrity = maxIntegrity * 0.35;
        surgeTimer = math.max(surgeTimer, 0.9);
        shake = 18;
        _spawnBurst(playerX, playerY, 50, Essence.fire);
        _addFloater(playerX, playerY - 90, 'REKINDLED', 0xFFFFB020);
        _notifyHud();
        return;
      }
      integrity = 0;
      phase = RushPhase.lost;
      _notifyHud();
    }
    _maybeTriggerCrisis();
  }

  Entity _playerHitbox() => Entity(
    kind: EntityKind.playerShard,
    sprite: '',
    x: playerX,
    y: playerY,
    radius: playerRadius,
  );

  // ------------------------------------------------------------- roguelite flow

  /// Fires once when integrity first drops into the danger band, offering a
  /// single life-or-greed pact.
  void _maybeTriggerCrisis() {
    if (!_crisisArmed || config.endless) return;
    if (integrityRatio > 0.28 || integrityRatio <= 0) return;
    _crisisArmed = false;
    _openPact();
  }

  void _advanceChambers() {
    if (awaitingChoice) return;
    if (config.endless) {
      final milestone = _endlessChamberMilestone * 1400.0;
      if (distance >= milestone) {
        _endlessChamberMilestone++;
        _openChamber();
      }
      // A one-time fork in endless once things get fast.
      if (!_forkOffered && distance > 2800) {
        _forkOffered = true;
        _openFork();
      }
      return;
    }

    if (_nextChamber < _plannedChambers.length && progress >= _plannedChambers[_nextChamber]) {
      _nextChamber++;
      // Every other chamber becomes a route fork instead of a draft, so the run
      // has a branching shape rather than a straight line of buffs.
      if (!_forkOffered && _nextChamber == (_plannedChambers.length ~/ 2) + 1) {
        _forkOffered = true;
        _openFork();
      } else {
        _openChamber();
      }
    }
  }

  List<MutationDef> _draftPool() {
    return kMutations.where((m) {
      final stacks = _mutationStacks[m.id] ?? 0;
      if (stacks >= m.maxStacks) return false;
      if (m.requiresEssence != null && !essencesUsed.contains(m.requiresEssence)) return false;
      return true;
    }).toList();
  }

  void _openChamber({bool opening = false}) {
    final pool = _draftPool()..shuffle(_rng);
    if (pool.isEmpty) return;
    final picks = pool.take(3).toList();
    pendingChoices = [for (final m in picks) _mutationChoice(m)];
    choiceTitle = opening ? 'Awakening Chamber' : 'Vent Chamber';
    choicePrompt = 'The flow pools in a vent. Fuse one mutation into your core.';
    choiceIsPact = false;
    phase = RushPhase.chamber;
    _pingOverlay();
  }

  void _openFork() {
    // Two contrasting routes: safe-but-lean vs dangerous-but-rich.
    pendingChoices = [
      RunChoice(
        id: 'fork_safe',
        title: 'Cooled Shelf',
        subtitle: 'Take the steady route',
        gain: 'Damage taken -15% for the rest of the run.',
        cost: 'Score gain -8%.',
        branch: MutationBranch.defence,
      ),
      RunChoice(
        id: 'fork_rich',
        title: 'Molten Artery',
        subtitle: 'Dive into the hot channel',
        gain: 'Loot +25%, score +18%.',
        cost: 'Spawns +30%, hazards more often.',
        branch: MutationBranch.wild,
      ),
    ];
    choiceTitle = 'The Channel Splits';
    choicePrompt = 'Two ways down the mountain. There is no going back.';
    choiceIsPact = false;
    phase = RushPhase.fork;
    _pingOverlay();
  }

  void _openPact() {
    pendingChoices = [
      RunChoice(
        id: 'pact_mend',
        title: 'Bank the Heat',
        subtitle: 'Play it safe',
        gain: 'Repair 45% integrity right now.',
        cost: 'Lose a third of your banked loot.',
        branch: MutationBranch.defence,
      ),
      RunChoice(
        id: 'pact_gamble',
        title: 'Feed the Rift',
        subtitle: 'Double or nothing',
        gain: 'Score multiplier +40% for the rest of the run.',
        cost: 'No repair. One more hit could end it.',
        branch: MutationBranch.wild,
      ),
    ];
    choiceTitle = 'Rift Pact';
    choicePrompt = 'The flow is failing. The mountain offers a bargain.';
    choiceIsPact = true;
    phase = RushPhase.pact;
    _pingOverlay();
  }

  RunChoice _mutationChoice(MutationDef m) => RunChoice(
    id: m.id,
    title: m.name,
    subtitle: m.branch.label,
    gain: m.gain,
    cost: m.cost,
    branch: m.branch,
    mutation: m,
  );

  /// Draws a fresh set of three mutations for the current chamber.
  bool reroll() {
    if (_reroll <= 0 || phase != RushPhase.chamber) return false;
    _reroll--;
    final pool = _draftPool()..shuffle(_rng);
    if (pool.isEmpty) return false;
    pendingChoices = [for (final m in pool.take(3)) _mutationChoice(m)];
    _pingOverlay();
    return true;
  }

  /// Applies whichever choice the player tapped and resumes the simulation.
  void choose(String id) {
    final wasPact = phase == RushPhase.pact;
    final wasFork = phase == RushPhase.fork;
    final choice = pendingChoices.where((c) => c.id == id).firstOrNull;

    if (choice?.mutation != null) {
      final m = choice!.mutation!;
      m.apply(mods);
      takenMutations.add(m);
      _mutationStacks[m.id] = (_mutationStacks[m.id] ?? 0) + 1;
      // Some fields feed derived caps; refresh the ones that matter.
      maxIntegrity = 100 * config.integrityBonus * (1 - _integrityPenalty());
      integrity = math.min(integrity, maxIntegrity);
      revivesLeft = math.max(revivesLeft, mods.reviveCharges);
    } else if (wasFork) {
      if (id == 'fork_safe') {
        mods.damageTakenMul *= 0.85;
        mods.scoreMul *= 0.92;
      } else {
        mods.lootMul *= 1.25;
        mods.scoreMul *= 1.18;
        mods.spawnRateMul *= 1.30;
        mods.hazardRateMul *= 1.30;
      }
    } else if (wasPact) {
      if (id == 'pact_mend') {
        integrity = math.min(maxIntegrity, integrity + maxIntegrity * 0.45);
        for (final k in ResourceKind.values) {
          loot[k] = (loot[k]! * 0.66).round();
        }
      } else {
        mods.scoreMul *= 1.40;
      }
    }

    pendingChoices = [];
    phase = boss != null ? RushPhase.boss : RushPhase.running;
    _pingOverlay();
    _notifyHud();
  }

  void _pingOverlay() => overlayTick.value++;

  // ------------------------------------------------------------------ spawning

  void _advanceSpawns(double dt) {
    if (phase == RushPhase.boss) return;

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      final rate = mods.spawnRateMul;
      _spawnTimer = math.max(0.28, (1.35 - config.difficulty * 0.07) * (0.7 + _rng.nextDouble() * 0.7) / rate);
      if (_rng.nextDouble() < 0.62) {
        _spawnEnemy();
      } else {
        _spawnObstacle();
      }
    }

    _pickupTimer -= dt;
    if (_pickupTimer <= 0) {
      _pickupTimer = (1.9 + _rng.nextDouble() * 2.4) / mods.pickupRateMul;
      _rng.nextDouble() < 0.26 ? _spawnVent() : _spawnPickup();
    }

    _hazardTimer -= dt;
    if (_hazardTimer <= 0) {
      _hazardTimer = (7.5 + _rng.nextDouble() * 7) / mods.hazardRateMul;
      if (config.regionIndex == 1 || config.regionIndex == 3 || config.endless) _spawnColdSeam();
    }
  }

  double _laneY() {
    if (config.laneControls) {
      return kWorldHeight * [0.22, 0.5, 0.78][_rng.nextInt(3)];
    }
    return kWorldHeight * (0.14 + _rng.nextDouble() * 0.72);
  }

  void _spawnEnemy() {
    // Weight the roster by how far into the run the player is, so early seconds
    // stay readable and later ones get genuinely dangerous.
    final pressure = (config.difficulty * 0.22 + progress * 0.8 + elapsed / 70).clamp(0.0, 1.0);
    final eliteGate = 0.55 - mods.eliteChanceBonus;
    final candidates = _pool.where((e) {
      if (e.rarity == Rarity.boss) return false;
      return switch (e.rarity) {
        Rarity.common => true,
        Rarity.rare => pressure > 0.22,
        Rarity.elite => pressure > eliteGate,
        Rarity.boss => false,
      };
    }).toList();
    if (candidates.isEmpty) return;
    final def = candidates[_rng.nextInt(candidates.length)];

    entities.add(
      Entity(
        kind: EntityKind.enemy,
        sprite: def.id,
        defId: def.id,
        essence: def.essence,
        rarity: def.rarity,
        x: worldWidth + 180,
        y: _laneY(),
        radius: 52 + def.mass * 190,
        hp: def.toughness,
        armor: def.armor,
        mass: def.mass,
      ),
    );
  }

  void _spawnObstacle() {
    final reachable = GameData.obstacles
        .where((o) => o.massToBreak < 0.22 + config.difficulty * 0.12)
        .toList();
    final def = (reachable.isEmpty ? GameData.obstacles : reachable)[_rng.nextInt(
      reachable.isEmpty ? GameData.obstacles.length : reachable.length,
    )];
    entities.add(
      Entity(
        kind: EntityKind.obstacle,
        sprite: def.id,
        defId: def.id,
        x: worldWidth + 160,
        y: _laneY(),
        radius: 58 + def.massToBreak * 90,
      ),
    );
  }

  void _spawnPickup() {
    const weights = {
      ResourceKind.magma: 6,
      ResourceKind.obsidian: 3,
      ResourceKind.alloy: 3,
      ResourceKind.shards: 2,
      ResourceKind.cores: 1,
    };
    final total = weights.values.reduce((a, b) => a + b);
    var roll = _rng.nextInt(total);
    var kind = ResourceKind.magma;
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll < 0) {
        kind = entry.key;
        break;
      }
    }
    entities.add(
      Entity(
        kind: EntityKind.pickup,
        sprite: kind.sprite,
        resource: kind,
        x: worldWidth + 140,
        y: _laneY(),
        radius: 40,
        payload: switch (kind) {
          ResourceKind.magma => 12,
          ResourceKind.obsidian => 2,
          ResourceKind.alloy => 2,
          ResourceKind.shards => 2,
          ResourceKind.cores => 1,
        },
      ),
    );
  }

  void _spawnVent() {
    entities.add(
      Entity(
        kind: EntityKind.vent,
        sprite: 'obj_core_geyser',
        x: worldWidth + 140,
        y: _laneY(),
        radius: 48,
      ),
    );
  }

  void _spawnColdSeam() {
    entities.add(
      Entity(
        kind: EntityKind.coldSeam,
        sprite: 'fx_ice_burst',
        x: worldWidth + 200,
        y: kWorldHeight * 0.5,
        radius: kWorldHeight * 0.5,
        width: 280 + _rng.nextDouble() * 260,
      ),
    );
  }

  void _spawnBoss() {
    final id = config.level?.bossId ?? 'golem_boss_magmaheart';
    final def = GameData.enemyById[id] ?? GameData.enemies.last;
    final entity = Entity(
      kind: EntityKind.boss,
      sprite: def.id,
      defId: def.id,
      essence: def.essence,
      rarity: Rarity.boss,
      x: worldWidth + 340,
      y: kWorldHeight * 0.5,
      radius: 165,
      hp: def.toughness * (1 + config.regionIndex * 0.18),
      armor: def.armor * 0.72,
      mass: def.mass,
    );
    boss = entity;
    bossPhase = 1;
    bossEnraged = false;
    entities.add(entity);
    phase = RushPhase.boss;
    shake = 16;
    _bossCallout('${def.name} bars the way');
    _notifyHud();
  }

  void _bossCallout(String text) {
    bossCallout = text;
    bossCalloutAt = elapsed;
    _notifyHud();
  }

  // ---------------------------------------------------------------- particles

  void _spawnBurst(double x, double y, int count, Essence? essence) {
    final budget = (count * config.particleScale).round();
    final hue = essence == null ? 0.0 : 1.0;
    for (var i = 0; i < budget; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 90 + _rng.nextDouble() * 420;
      particles.add(
        Particle(
          x,
          y,
          math.cos(angle) * speed,
          math.sin(angle) * speed,
          0.35 + _rng.nextDouble() * 0.55,
          4 + _rng.nextDouble() * 12,
          hue,
        ),
      );
    }
    if (particles.length > 420) {
      particles.removeRange(0, particles.length - 420);
    }
  }

  void _addFloater(double x, double y, String text, int tint) {
    floaters.add(FloatingText(x, y, text, tint));
    if (floaters.length > 18) floaters.removeAt(0);
  }

  void _advanceParticles(double dt) {
    for (final particle in particles) {
      particle.age += dt;
      particle.x += (particle.vx - scrollSpeed * 0.35) * dt;
      particle.y += particle.vy * dt;
      particle.vy += 220 * dt;
      particle.vx *= 1 - dt * 1.6;
    }
    particles.removeWhere((p) => p.age >= p.life);

    for (final floater in floaters) {
      floater.age += dt;
      floater.y -= 46 * dt;
      floater.x -= scrollSpeed * 0.45 * dt;
    }
    floaters.removeWhere((f) => f.age > 0.9);
  }

  /// Safety valve: no matter what spawn/cull imbalance or degenerate physics
  /// value occurs, the number of live entities can never grow without bound and
  /// stall a frame past the Android ANR threshold. Under normal play this never
  /// triggers; it only fires as a last-resort guard.
  void _enforceLimits() {
    const maxEntities = 260;
    if (entities.length <= maxEntities) return;
    var toRemove = entities.length - maxEntities;
    // Drop the earliest-spawned non-boss, non-shard entities first; those are the
    // furthest along the channel and least noticeable to lose.
    entities.removeWhere((e) {
      if (toRemove > 0 && e.kind != EntityKind.boss && e.kind != EntityKind.playerShard) {
        toRemove--;
        return true;
      }
      return false;
    });
  }

  void _checkPhase() {
    if (phase == RushPhase.running && !config.endless && progress >= 1) {
      if (config.isBossLevel && boss == null && bossesFelled == 0) {
        _spawnBoss();
      } else {
        phase = RushPhase.won;
        _notifyHud();
      }
    }
  }

  void _notifyHud() => hudTick.value++;

  // ------------------------------------------------------------------- result

  RunResult buildResult() => RunResult(
    levelIndex: config.level?.globalIndex ?? -1,
    isEndless: config.endless,
    victory: phase == RushPhase.won,
    progress: progress,
    score: score,
    absorbed: absorbed,
    eliteAbsorbed: eliteAbsorbed,
    bossesFelled: bossesFelled,
    obstaclesSmashed: obstaclesSmashed,
    bestCombo: bestCombo,
    distance: distance,
    duration: Duration(milliseconds: (elapsed * 1000).round()),
    flawless: !damageTaken,
    essencesUsed: essencesUsed,
    loot: {
      for (final entry in loot.entries)
        if (entry.value > 0) entry.key: entry.value,
    },
  );

  void dispose() {
    frame.dispose();
    hudTick.dispose();
    overlayTick.dispose();
  }

  bool _overlaps(Entity a, Entity b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final reach = a.radius + b.radius;
    return dx * dx + dy * dy <= reach * reach;
  }
}
