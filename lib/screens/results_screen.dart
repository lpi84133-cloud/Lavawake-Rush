import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/nav.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/lava_background.dart';
import '../core/widgets/screen_shell.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'crucible_screen.dart';
import 'gameplay_screen.dart';
import 'level_brief_screen.dart';
import 'main_menu_screen.dart';

/// End-of-run report. A single tall verdict plate on the left, a dense
/// performance table on the right, and the run's loot along the bottom.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.result, required this.level, required this.endless});

  final RunResult result;
  final LevelDef? level;
  final bool endless;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 1400));
    if (widget.result.victory) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final game = context.watch<GameState>();
    final victory = result.victory;
    final accent = victory ? Palette.success : Palette.danger;
    final stars = widget.level == null ? 0 : (game.levelStars[widget.level!.globalIndex] ?? 0);
    final nextIndex = widget.level == null ? null : widget.level!.globalIndex + 1;
    final hasNext = nextIndex != null && nextIndex < GameData.levelCount;

    return Scaffold(
      backgroundColor: Palette.ink,
      body: Stack(
        children: [
          LavaBackground(
            accent: accent,
            intensity: victory ? 1.2 : 0.7,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Dim.l),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 40,
                      child: _VerdictPlate(
                        result: result,
                        stars: stars,
                        accent: accent,
                        endless: widget.endless,
                        best: game.endlessBest,
                      ),
                    ),
                    const SizedBox(width: Dim.m),
                    Expanded(
                      flex: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _PerformanceGrid(result: result)),
                          const SizedBox(height: Dim.m),
                          _LootStrip(result: result),
                          if (game.perkPoints > 0) ...[
                            const SizedBox(height: Dim.m),
                            _CruciblePrompt(points: game.perkPoints),
                          ],
                          const SizedBox(height: Dim.m),
                          Row(
                            children: [
                              Expanded(
                                child: LavaButton(
                                  label: 'Menu',
                                  icon: Icons.home_rounded,
                                  tone: ButtonTone.ghost,
                                  expand: true,
                                  onPressed: () {
                                    context.read<AudioService>().back();
                                    Navigator.of(context).pushAndRemoveUntil(
                                      fadeThrough(const MainMenuScreen()),
                                      (route) => false,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: Dim.s),
                              Expanded(
                                child: LavaButton(
                                  label: 'Run again',
                                  icon: Icons.refresh_rounded,
                                  tone: ButtonTone.ghost,
                                  expand: true,
                                  onPressed: () {
                                    context.read<AudioService>().confirm();
                                    Navigator.of(context).pushReplacement(
                                      fadeThrough(
                                        GameplayScreen(level: widget.level, endless: widget.endless),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (victory && hasNext) ...[
                                const SizedBox(width: Dim.s),
                                Expanded(
                                  child: LavaButton(
                                    label: 'Next level',
                                    icon: Icons.arrow_forward_rounded,
                                    expand: true,
                                    accent: accent,
                                    onPressed: () {
                                      context.read<AudioService>().confirm();
                                      Navigator.of(context).pushReplacement(
                                        fadeThrough(LevelBriefScreen(level: GameData.levelAt(nextIndex))),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.04,
              numberOfParticles: 14,
              maxBlastForce: 18,
              minBlastForce: 6,
              gravity: 0.28,
              colors: const [Palette.lava, Palette.ember, Palette.crimson, Palette.metal],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictPlate extends StatelessWidget {
  const _VerdictPlate({
    required this.result,
    required this.stars,
    required this.accent,
    required this.endless,
    required this.best,
  });

  final RunResult result;
  final int stars;
  final Color accent;
  final bool endless;
  final int best;

  @override
  Widget build(BuildContext context) {
    final victory = result.victory;
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.l),
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            endless ? 'RUSH COMPLETE' : (victory ? 'CHANNEL CLEARED' : 'FLOW EXTINGUISHED'),
            style: AppText.eyebrow.copyWith(color: accent),
          ),
          const SizedBox(height: Dim.s),
          Text(
            victory ? 'Victory' : 'Defeat',
            style: AppText.hero.copyWith(fontSize: 42, color: victory ? Palette.textPrimary : Palette.danger),
          ),
          const SizedBox(height: 4),
          Text(
            victory
                ? 'The flow held its heat and took the whole channel.'
                : 'Structural integrity gave out before the channel ended.',
            style: AppText.body14,
          ),
          if (!endless) ...[
            const SizedBox(height: Dim.l),
            StarRow(filled: stars, size: 28),
          ],
          const Spacer(),
          Text('FINAL SCORE', style: AppText.eyebrow),
          Text(
            formatCount(result.score),
            style: AppText.hero.copyWith(fontSize: 44, color: accent),
          ).animate().fadeIn(duration: 420.ms).scaleXY(begin: 0.82, curve: Curves.easeOutBack),
          if (endless) ...[
            const SizedBox(height: 4),
            Text(
              result.score >= best ? 'New personal best' : 'Personal best ${formatCount(best)}',
              style: AppText.body14.copyWith(
                fontSize: 12,
                color: result.score >= best ? Palette.ember : Palette.textMuted,
              ),
            ),
          ],
          const SizedBox(height: Dim.m),
          Row(
            children: [
              Expanded(
                child: MeterBar(value: result.progress, color: accent, height: 5),
              ),
              const SizedBox(width: Dim.s),
              Text(
                '${(result.progress * 100).round()}%',
                style: AppText.label.copyWith(fontSize: 12, color: accent),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 340.ms).slideX(begin: -0.05, curve: Curves.easeOutCubic);
  }
}

class _PerformanceGrid extends StatelessWidget {
  const _PerformanceGrid({required this.result});

  final RunResult result;

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String, Color)>[
      (Icons.blur_circular_rounded, 'Absorbed', '${result.absorbed}', Palette.lava),
      (Icons.military_tech_rounded, 'Elites', '${result.eliteAbsorbed}', Palette.crystal),
      (Icons.construction_rounded, 'Smashed', '${result.obstaclesSmashed}', Palette.stone),
      (Icons.link_rounded, 'Best combo', '${result.bestCombo}', Palette.ember),
      (Icons.straighten_rounded, 'Distance', formatDistance(result.distance), Palette.frost),
      (Icons.timer_outlined, 'Duration', formatDuration(result.duration), Palette.metal),
      (Icons.whatshot_rounded, 'Bosses', '${result.bossesFelled}', Palette.crimson),
      (
        result.flawless ? Icons.verified_rounded : Icons.healing_rounded,
        'Damage',
        result.flawless ? 'None' : 'Taken',
        result.flawless ? Palette.success : Palette.danger,
      ),
    ];

    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            text: 'Run breakdown',
            trailing: Row(
              children: [
                for (final essence in result.essencesUsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(essence.icon, size: 12, color: essence.color),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Dim.m),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: Dim.s,
              crossAxisSpacing: Dim.s,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < entries.length; i++)
                  FlatPanel(
                        padding: const EdgeInsets.all(9),
                        accent: entries[i].$4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(entries[i].$1, size: 14, color: entries[i].$4),
                            Text(
                              entries[i].$3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.numeric.copyWith(fontSize: 17),
                            ),
                            Text(
                              entries[i].$2.toUpperCase(),
                              style: AppText.eyebrow.copyWith(fontSize: 8),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(delay: (i * 45).ms, duration: 280.ms)
                      .slideY(begin: 0.2, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LootStrip extends StatelessWidget {
  const _LootStrip({required this.result});

  final RunResult result;

  @override
  Widget build(BuildContext context) {
    if (result.loot.isEmpty) {
      return FlatPanel(
        padding: const EdgeInsets.all(Dim.m),
        child: Row(
          children: [
            const Icon(Icons.inbox_rounded, size: 14, color: Palette.textMuted),
            const SizedBox(width: Dim.s),
            Text('No resources harvested this run.', style: AppText.body14.copyWith(fontSize: 12)),
          ],
        ),
      );
    }

    return FlatPanel(
      padding: const EdgeInsets.all(Dim.m),
      child: Row(
        children: [
          Text('HARVEST', style: AppText.eyebrow.copyWith(color: Palette.ember)),
          const SizedBox(width: Dim.m),
          Expanded(
            child: Wrap(
              spacing: Dim.s,
              runSpacing: 6,
              children: [
                for (final entry in result.loot.entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpriteTile(name: entry.key.sprite, size: 24),
                      const SizedBox(width: 5),
                      Text(
                        '+${entry.value}',
                        style: AppText.label.copyWith(fontSize: 12, color: entry.key.color),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        entry.key.label,
                        style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 240.ms, duration: 300.ms);
  }
}

/// Nudge to spend freshly-earned perk points in the Crucible without leaving the
/// results flow.
class _CruciblePrompt extends StatelessWidget {
  const _CruciblePrompt({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: Palette.ember,
      onTap: () {
        context.read<AudioService>().confirm();
        Navigator.of(context).push(fadeThrough(const CrucibleScreen()));
      },
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: Dim.brS,
              color: Palette.ember.withValues(alpha: 0.16),
              border: Border.all(color: Palette.ember.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Palette.ember),
          ),
          const SizedBox(width: Dim.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You levelled up',
                  style: AppText.label.copyWith(fontSize: 13, color: Palette.ember),
                ),
                Text(
                  '$points perk ${points == 1 ? 'point' : 'points'} ready to spend in the Crucible.',
                  style: AppText.body14.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Palette.ember),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 320.ms).slideY(begin: 0.1);
  }
}
