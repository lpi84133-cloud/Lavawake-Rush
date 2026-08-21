import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/nav.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../data/asset_catalog.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../data/mutations.dart';
import '../data/volcanic_events.dart';
import '../game/rush_engine.dart';
import '../game/rush_painter.dart';
import '../game/sprite_cache.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import '../state/settings_state.dart';
import 'results_screen.dart';

/// Hosts one run: the renderer, the input surface, the HUD, and the pause sheet.
class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, this.level, this.endless = false, this.event});

  final LevelDef? level;
  final bool endless;

  /// Set only when the run was started from the weekly event screen. It layers
  /// the event's modifiers on top of the perk board and routes the result to
  /// the event standings instead of the endless record.
  final VolcanicEventDef? event;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> with SingleTickerProviderStateMixin {
  late final RushEngine _engine;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _handledEnd = false;
  ui.Image? _background;

  @override
  void initState() {
    super.initState();
    final game = context.read<GameState>();
    final settings = context.read<SettingsState>();

    _engine = RushEngine(
      RunConfig(
        level: widget.level,
        endless: widget.endless,
        heatBonus: game.bonus(UpgradeTrack.heat),
        massBonus: game.bonus(UpgradeTrack.mass),
        speedBonus: game.bonus(UpgradeTrack.speed),
        absorptionBonus: game.bonus(UpgradeTrack.absorption),
        integrityBonus: game.bonus(UpgradeTrack.integrity),
        surgeBonus: game.bonus(UpgradeTrack.surge),
        shieldBonus: game.bonus(UpgradeTrack.shield),
        harvestBonus: game.bonus(UpgradeTrack.harvest),
        laneControls: settings.controls == ControlScheme.lanes,
        particleScale: settings.quality.particleScale,
        modifiers: game.buildRunModifiers(event: widget.event),
      ),
    );

    _background = SpriteCache.instance.get(_engine.region.background);
    if (_background == null) {
      SpriteCache.instance.load(_engine.region.background).then((image) {
        if (mounted) setState(() => _background = image);
      });
    }

    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    _engine.update(dt);
    if (!_handledEnd && (_engine.phase == RushPhase.won || _engine.phase == RushPhase.lost)) {
      _handledEnd = true;
      _finish();
    }
  }

  Future<void> _finish() async {
    _ticker.stop();
    final victory = _engine.phase == RushPhase.won;
    final result = _engine.buildResult();
    final game = context.read<GameState>();
    final audio = context.read<AudioService>();

    game.beginRunResolution();
    game.recordDiscoveries(_engine.discovered);
    game.applyRunResult(result, event: widget.event);
    audio.play(victory ? Sfx.levelComplete : Sfx.levelFailed);

    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      fadeThrough(ResultsScreen(result: result, level: widget.level, endless: widget.endless)),
    );
  }

  Offset _toWorld(Offset local, Size size) {
    final scale = kWorldHeight / size.height;
    return Offset(local.dx * scale, local.dy * scale);
  }

  void _handleTapDown(TapDownDetails details, Size size, ControlScheme scheme) {
    if (_engine.phase == RushPhase.intro) {
      _engine.begin();
      setState(() {});
      return;
    }
    if (scheme == ControlScheme.lanes) {
      final third = size.height / 3;
      _engine.steerToLane(details.localPosition.dy < third ? 0 : (details.localPosition.dy < third * 2 ? 1 : 2));
    } else {
      _engine.steerTo(_toWorld(details.localPosition, size));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final game = context.read<GameState>();
    final skin = GameData.skinById[game.selectedSkin];
    final tint = skin?.tint ?? Palette.lava;

    return Scaffold(
      backgroundColor: Palette.voidBlack,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _engine.setViewport(size);

          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: RushPainter(engine: _engine, background: _background, playerTint: tint),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _handleTapDown(d, size, settings.controls),
                onPanStart: (d) {
                  if (_engine.phase == RushPhase.intro) _engine.begin();
                  if (settings.controls == ControlScheme.drag) {
                    _engine.steerTo(_toWorld(d.localPosition, size));
                  }
                },
                onPanUpdate: (d) {
                  if (settings.controls == ControlScheme.drag) {
                    _engine.steerTo(_toWorld(d.localPosition, size));
                  } else {
                    _engine.nudge(d.delta.dy * (kWorldHeight / size.height) * 1.6);
                  }
                },
              ),
              _Hud(engine: _engine, tint: tint, leftHanded: settings.leftHanded),
              _BossCallout(engine: _engine),
              if (_engine.phase == RushPhase.intro)
                _IntroOverlay(engine: _engine, onBegin: () => setState(_engine.begin)),
              ValueListenableBuilder<int>(
                valueListenable: _engine.overlayTick,
                builder: (context, _, _) => _engine.awaitingChoice
                    ? _ChoiceOverlay(engine: _engine, tint: tint)
                    : const SizedBox.shrink(),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _engine.hudTick,
                builder: (context, _, _) => _engine.phase == RushPhase.paused
                    ? _PauseOverlay(
                        engine: _engine,
                        onQuit: _abandon,
                        onRestart: _restart,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abandon() {
    context.read<AudioService>().cancel();
    _engine.abandon();
  }

  /// Ends the current run without opening the results screen and mounts a
  /// fresh gameplay screen with the same launch args. The old State's dispose
  /// releases the ticker and the engine, so no simulation ever double-runs.
  void _restart() {
    context.read<AudioService>().confirm();
    _handledEnd = true;
    _ticker.stop();
    Navigator.of(context).pushReplacement(
      fadeThrough(GameplayScreen(
        level: widget.level,
        endless: widget.endless,
        event: widget.event,
      )),
    );
  }
}

// --------------------------------------------------------------------------- HUD

class _Hud extends StatelessWidget {
  const _Hud({required this.engine, required this.tint, required this.leftHanded});

  final RushEngine engine;
  final Color tint;
  final bool leftHanded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: engine.hudTick,
      builder: (context, _, _) {
        final abilities = _AbilityCluster(engine: engine, tint: tint);
        final status = _FormStatus(engine: engine);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: Dim.s),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VitalsPanel(engine: engine),
                    const SizedBox(width: Dim.m),
                    Expanded(child: _ProgressPanel(engine: engine)),
                    const SizedBox(width: Dim.m),
                    _ScorePanel(engine: engine),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: leftHanded
                      ? [abilities, const Spacer(), status]
                      : [status, const Spacer(), abilities],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VitalsPanel extends StatelessWidget {
  const _VitalsPanel({required this.engine});

  final RushEngine engine;

  @override
  Widget build(BuildContext context) {
    return _HudCard(
      width: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MicroStat(
            icon: Icons.shield_moon_rounded,
            label: 'INTEGRITY',
            value: '${engine.integrity.round()}',
            ratio: engine.integrityRatio,
            color: engine.integrityRatio < 0.3 ? Palette.danger : Palette.success,
          ),
          const SizedBox(height: 7),
          _MicroStat(
            icon: Icons.thermostat_rounded,
            label: 'HEAT',
            value: '${(engine.heatRatio * 100).round()}%',
            ratio: engine.heatRatio,
            color: Color.lerp(Palette.frost, Palette.lavaBright, engine.heatRatio)!,
          ),
          const SizedBox(height: 7),
          _MicroStat(
            icon: Icons.fitness_center_rounded,
            label: 'MASS',
            value: engine.mass.toStringAsFixed(2),
            ratio: (engine.mass / 1.9).clamp(0.0, 1.0),
            color: Palette.stone,
          ),
        ],
      ),
    );
  }
}

class _MicroStat extends StatelessWidget {
  const _MicroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(label, style: AppText.eyebrow.copyWith(fontSize: 8.5, letterSpacing: 1.1)),
            ),
            Text(value, style: AppText.label.copyWith(fontSize: 11, color: color)),
          ],
        ),
        const SizedBox(height: 3),
        MeterBar(value: ratio, color: color, height: 4, showTrackGlow: false),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.engine});

  final RushEngine engine;

  @override
  Widget build(BuildContext context) {
    final boss = engine.phase == RushPhase.boss;
    return _HudCard(
      child: Column(
        children: [
          Row(
            children: [
              Text(
                boss ? 'BOSS ENCOUNTER' : (engine.config.endless ? 'ENDLESS RUSH' : 'CHANNEL PROGRESS'),
                style: AppText.eyebrow.copyWith(
                  fontSize: 8.5,
                  color: boss ? Palette.crimson : Palette.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                engine.config.endless
                    ? formatDistance(engine.distance)
                    : '${(engine.progress * 100).round()}%',
                style: AppText.label.copyWith(fontSize: 11, color: Palette.ember),
              ),
            ],
          ),
          const SizedBox(height: 5),
          MeterBar(
            value: boss ? 1 : engine.progress,
            color: boss ? Palette.crimson : (engine.overdrive ? Palette.lava : Palette.ember),
            height: 5,
          ),
          if (engine.overdrive) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flash_on_rounded, size: 10, color: Palette.lava),
                const SizedBox(width: 4),
                Text(
                  'OVERDRIVE x${engine.overdriveStacks}',
                  style: AppText.eyebrow.copyWith(fontSize: 8, color: Palette.lava),
                ),
              ],
            ),
          ] else if (engine.lastAbsorbedName != null && engine.elapsed - engine.lastAbsorbedAt < 1.6) ...[
            const SizedBox(height: 4),
            Text(
              'ABSORBED ${engine.lastAbsorbedName!.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.eyebrow.copyWith(fontSize: 8, color: Palette.lavaBright),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.engine});

  final RushEngine engine;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HudCard(
          width: 122,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('SCORE', style: AppText.eyebrow.copyWith(fontSize: 8.5)),
              Text(
                formatCount(engine.score),
                style: AppText.numeric.copyWith(fontSize: 19),
              ),
              if (engine.combo > 1)
                Text(
                  'COMBO x${engine.combo}',
                  style: AppText.eyebrow.copyWith(fontSize: 8.5, color: Palette.lavaBright),
                ),
            ],
          ),
        ),
        const SizedBox(width: Dim.s),
        CircleAction(
          icon: Icons.pause_rounded,
          size: 38,
          onTap: () {
            context.read<AudioService>().openPanel();
            engine.pause();
          },
        ),
      ],
    );
  }
}

class _FormStatus extends StatelessWidget {
  const _FormStatus({required this.engine});

  final RushEngine engine;

  @override
  Widget build(BuildContext context) {
    final form = engine.activeForm;
    return _HudCard(
      width: 208,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.merge_type_rounded, size: 12, color: Palette.ember),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  form.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.eyebrow.copyWith(fontSize: 9, color: Palette.ember, letterSpacing: 1.3),
                ),
              ),
              if (engine.revivesLeft > 0) ...[
                const Icon(Icons.favorite_rounded, size: 10, color: Palette.success),
                const SizedBox(width: 2),
                Text('${engine.revivesLeft}', style: AppText.eyebrow.copyWith(fontSize: 8.5, color: Palette.success)),
                const SizedBox(width: 6),
              ],
              if (engine.takenMutations.isNotEmpty) ...[
                const Icon(Icons.science_rounded, size: 10, color: Palette.crystal),
                const SizedBox(width: 2),
                Text(
                  '${engine.takenMutations.length}',
                  style: AppText.eyebrow.copyWith(fontSize: 8.5, color: Palette.crystal),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (final essence in Essence.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      children: [
                        MeterBar(
                          value: engine.essences.charge[essence]!,
                          color: essence.color,
                          height: 3,
                          showTrackGlow: false,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          essence.shortLabel,
                          style: AppText.eyebrow.copyWith(
                            fontSize: 7.5,
                            letterSpacing: 0.4,
                            color: engine.essences.charge[essence]! > 0.16
                                ? essence.color
                                : Palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbilityCluster extends StatelessWidget {
  const _AbilityCluster({required this.engine, required this.tint});

  final RushEngine engine;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsState>();

    return Row(
      children: [
        _AbilityButton(
          icon: Icons.diamond_rounded,
          label: 'VOLLEY',
          charge: engine.essences.charge[Essence.crystal]!.clamp(0.0, 1.0),
          ready: engine.canVolley,
          accent: Palette.crystal,
          onTap: () {
            if (engine.volley()) settings.tick();
          },
        ),
        const SizedBox(width: Dim.s),
        _AbilityButton(
          icon: Icons.blur_on_rounded,
          label: 'ERUPT',
          charge: engine.eruptCharge,
          ready: engine.canErupt,
          accent: Palette.ember,
          onTap: () {
            if (engine.erupt()) settings.thud();
          },
        ),
        const SizedBox(width: Dim.s),
        _AbilityButton(
          icon: Icons.bolt_rounded,
          label: 'SURGE',
          charge: engine.surgeCooldown <= 0
              ? 1
              : 1 - (engine.surgeCooldown / engine.surgeCooldownLength).clamp(0.0, 1.0),
          ready: engine.canSurge,
          accent: tint,
          large: true,
          onTap: () {
            if (engine.surge()) settings.thud();
          },
        ),
      ],
    );
  }
}

class _AbilityButton extends StatelessWidget {
  const _AbilityButton({
    required this.icon,
    required this.label,
    required this.charge,
    required this.ready,
    required this.accent,
    required this.onTap,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final double charge;
  final bool ready;
  final Color accent;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 68.0 : 54.0;
    return GestureDetector(
      onTap: ready ? onTap : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _ChargeRingPainter(
                charge: charge,
                color: ready ? accent : Palette.textMuted,
                ready: ready,
              ),
            ),
            Container(
              width: size - 12,
              height: size - 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready
                    ? accent.withValues(alpha: 0.18)
                    : Palette.surface.withValues(alpha: 0.72),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: large ? 22 : 17, color: ready ? accent : Palette.textMuted),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: AppText.eyebrow.copyWith(
                      fontSize: large ? 8 : 7,
                      letterSpacing: 0.6,
                      color: ready ? accent : Palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargeRingPainter extends CustomPainter {
  const _ChargeRingPainter({required this.charge, required this.color, required this.ready});

  final double charge;
  final Color color;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 3,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * charge.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: ready ? 1 : 0.5),
    );
  }

  @override
  bool shouldRepaint(_ChargeRingPainter old) =>
      old.charge != charge || old.color != color || old.ready != ready;
}

class _HudCard extends StatelessWidget {
  const _HudCard({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: Dim.brS,
        color: Palette.voidBlack.withValues(alpha: 0.55),
        border: Border.all(color: Palette.hairline),
      ),
      child: child,
    );
  }
}

// ----------------------------------------------------------------------- overlays

class _IntroOverlay extends StatelessWidget {
  const _IntroOverlay({required this.engine, required this.onBegin});

  final RushEngine engine;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final level = engine.config.level;
    return Positioned.fill(
      child: GestureDetector(
        onTap: onBegin,
        child: ColoredBox(
          color: Palette.voidBlack.withValues(alpha: 0.66),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dim.l),
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: Dim.l, vertical: Dim.m),
                  accent: engine.region.accent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        engine.config.endless ? 'ENDLESS RUSH' : engine.region.name.toUpperCase(),
                        style: AppText.eyebrow.copyWith(color: engine.region.accent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        level?.name ?? 'Caldera Prime',
                        style: AppText.title.copyWith(fontSize: 26),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Dim.m),
                      Text(
                        'Drag anywhere to steer the flow. Hold contact to melt what you touch.',
                        textAlign: TextAlign.center,
                        style: AppText.body14,
                      ),
                      const SizedBox(height: Dim.l),
                      LavaButton(label: 'Tap to begin', icon: Icons.touch_app_rounded, onPressed: onBegin),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.engine,
    required this.onQuit,
    required this.onRestart,
  });

  final RushEngine engine;
  final VoidCallback onQuit;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: Palette.voidBlack.withValues(alpha: 0.62),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassPanel(
                padding: const EdgeInsets.all(Dim.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pause_circle_outline_rounded, size: 18, color: Palette.lava),
                        const SizedBox(width: Dim.s),
                        Text('Paused', style: AppText.title.copyWith(fontSize: 20)),
                        const Spacer(),
                        Text(
                          '${(engine.progress * 100).round()}% - ${formatCount(engine.score)} pts',
                          style: AppText.eyebrow,
                        ),
                      ],
                    ),
                    const SizedBox(height: Dim.m),
                    Row(
                      children: [
                        Expanded(
                          child: _PauseStat(
                            label: 'Absorbed',
                            value: '${engine.absorbed}',
                            icon: Icons.blur_circular_rounded,
                          ),
                        ),
                        Expanded(
                          child: _PauseStat(
                            label: 'Smashed',
                            value: '${engine.obstaclesSmashed}',
                            icon: Icons.construction_rounded,
                          ),
                        ),
                        Expanded(
                          child: _PauseStat(
                            label: 'Best combo',
                            value: '${engine.bestCombo}',
                            icon: Icons.link_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dim.l),
                    Row(
                      children: [
                        Expanded(
                          child: LavaButton(
                            label: 'Resume',
                            icon: Icons.play_arrow_rounded,
                            expand: true,
                            onPressed: () {
                              context.read<AudioService>().closePanel();
                              engine.resume();
                            },
                          ),
                        ),
                        const SizedBox(width: Dim.s),
                        Expanded(
                          child: LavaButton(
                            label: 'Restart',
                            icon: Icons.refresh_rounded,
                            tone: ButtonTone.ghost,
                            expand: true,
                            onPressed: onRestart,
                          ),
                        ),
                        const SizedBox(width: Dim.s),
                        Expanded(
                          child: LavaButton(
                            label: 'Abandon',
                            icon: Icons.exit_to_app_rounded,
                            tone: ButtonTone.danger,
                            expand: true,
                            onPressed: onQuit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseStat extends StatelessWidget {
  const _PauseStat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Palette.textMuted),
        const SizedBox(height: 5),
        Text(value, style: AppText.numeric.copyWith(fontSize: 20)),
        Text(label.toUpperCase(), style: AppText.eyebrow.copyWith(fontSize: 8.5)),
      ],
    );
  }
}

// ------------------------------------------------------------- boss callouts

/// Big transient banner announcing a boss arrival or a phase change. Reads from
/// the HUD tick so it costs nothing while nothing is happening.
class _BossCallout extends StatelessWidget {
  const _BossCallout({required this.engine});

  final RushEngine engine;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: engine.hudTick,
      builder: (context, _, _) {
        final text = engine.bossCallout;
        final age = engine.elapsed - engine.bossCalloutAt;
        if (text == null || age > 2.4) return const SizedBox.shrink();
        return IgnorePointer(
          child: Align(
            alignment: const Alignment(0, -0.42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('BOSS', style: AppText.eyebrow.copyWith(color: Palette.crimson, letterSpacing: 4)),
                const SizedBox(height: 4),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppText.title.copyWith(fontSize: 26, color: Palette.textPrimary),
                ),
              ],
            )
                .animate(key: ValueKey(engine.bossCalloutAt))
                .fadeIn(duration: 220.ms)
                .slideY(begin: -0.3, curve: Curves.easeOutBack)
                .then(delay: 1400.ms)
                .fadeOut(duration: 500.ms),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------- choice overlay

/// The shared overlay for every mid-run decision: mutation draft, route fork and
/// rift pact. Freezes the run behind a blur and offers two or three cards.
class _ChoiceOverlay extends StatelessWidget {
  const _ChoiceOverlay({required this.engine, required this.tint});

  final RushEngine engine;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioService>();
    final settings = context.read<SettingsState>();
    final choices = engine.pendingChoices;
    final accent = engine.choiceIsPact ? Palette.crimson : tint;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: ColoredBox(
          color: Palette.voidBlack.withValues(alpha: 0.68),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Dim.l),
              child: Column(
                children: [
                  Column(
                    children: [
                      Text(
                        engine.choiceTitle.toUpperCase(),
                        style: AppText.eyebrow.copyWith(color: accent, letterSpacing: 3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        engine.choicePrompt,
                        textAlign: TextAlign.center,
                        style: AppText.subtitle.copyWith(fontSize: 16),
                      ),
                    ],
                  ).animate().fadeIn(duration: 240.ms).slideY(begin: -0.3, curve: Curves.easeOutCubic),
                  const SizedBox(height: Dim.m),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < choices.length; i++) ...[
                          if (i > 0) const SizedBox(width: Dim.m),
                          Expanded(
                            child: _ChoiceCard(
                              choice: choices[i],
                              index: i,
                              onPick: () {
                                audio.confirm();
                                settings.thud();
                                engine.choose(choices[i].id);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Dim.m),
                  if (engine.phase == RushPhase.chamber)
                    LavaButton(
                      label: engine.rerollsLeft > 0 ? 'Reroll (${engine.rerollsLeft})' : 'No rerolls left',
                      icon: Icons.casino_rounded,
                      tone: ButtonTone.ghost,
                      accent: accent,
                      onPressed: engine.rerollsLeft > 0
                          ? () {
                              audio.tap();
                              engine.reroll();
                            }
                          : null,
                    )
                  else
                    Text(
                      'This choice is permanent for the rest of the run.',
                      style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.choice, required this.index, required this.onPick});

  final RunChoice choice;
  final int index;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final accent = choice.branch.color;
    return GlassPanel(
          padding: const EdgeInsets.all(Dim.m),
          accent: accent,
          onTap: onPick,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: Dim.brS,
                      color: accent.withValues(alpha: 0.16),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Icon(choice.mutation?.icon ?? choice.branch.icon, size: 20, color: accent),
                  ),
                  const SizedBox(width: Dim.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(choice.subtitle.toUpperCase(), style: AppText.eyebrow.copyWith(color: accent, fontSize: 8.5)),
                        const SizedBox(height: 2),
                        Text(
                          choice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dim.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.add_rounded, size: 14, color: Palette.success),
                  const SizedBox(width: 6),
                  Expanded(child: Text(choice.gain, style: AppText.body14.copyWith(fontSize: 12.5))),
                ],
              ),
              if (choice.cost.isNotEmpty) ...[
                const SizedBox(height: Dim.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.remove_rounded, size: 14, color: Palette.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        choice.cost,
                        style: AppText.body14.copyWith(fontSize: 12.5, color: Palette.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              LavaButton(
                label: 'Choose',
                icon: Icons.check_rounded,
                expand: true,
                accent: accent,
                onPressed: onPick,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (index * 90).ms, duration: 280.ms)
        .slideY(begin: 0.14, curve: Curves.easeOutCubic);
  }
}
