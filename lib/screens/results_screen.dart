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
  late final RunReward _reward;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 1400));
    // Snapshot once: the results screen owns the bonus payload for this run.
    _reward = context.read<GameState>().lastRunReward;
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
                padding: const EdgeInsets.fromLTRB(Dim.l, Dim.m, Dim.l, Dim.m),
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
          if (!_reward.isEmpty)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: Dim.s),
                  child: _RewardBanner(reward: _reward),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A transient top-of-screen banner that celebrates freshly-unlocked
/// achievements and a first perfect clear, then slides away on its own so it
/// never covers the run breakdown for long.
class _RewardBanner extends StatefulWidget {
  const _RewardBanner({required this.reward});

  final RunReward reward;

  @override
  State<_RewardBanner> createState() => _RewardBannerState();
}

class _RewardBannerState extends State<_RewardBanner> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    Future.delayed(const Duration(milliseconds: 5200), () {
      if (mounted) setState(() => _shown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
        offset: _shown ? Offset.zero : const Offset(0, -0.7),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 460),
          opacity: _shown ? 1 : 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: Dim.s),
              accent: Palette.warning,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.redeem_rounded, size: 14, color: Palette.warning),
                      const SizedBox(width: 6),
                      Text('REWARDS EARNED', style: AppText.eyebrow.copyWith(color: Palette.warning)),
                    ],
                  ),
                  for (final def in reward.achievements) ...[
                    const SizedBox(height: 7),
                    _AchievementRow(def: def),
                  ],
                  if (reward.hasChest) ...[
                    const SizedBox(height: 7),
                    _ChestRow(chest: reward.chest),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.def});

  final AchievementDef def;

  @override
  Widget build(BuildContext context) {
    final color = def.tier.color;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: Dim.brS,
            color: color.withValues(alpha: 0.16),
            border: Border.all(color: color.withValues(alpha: 0.42)),
          ),
          child: Icon(def.icon, size: 16, color: color),
        ),
        const SizedBox(width: Dim.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                def.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(fontSize: 12),
              ),
              Text(
                'Achievement · ${def.tier.label}',
                style: AppText.eyebrow.copyWith(fontSize: 7.5, color: Palette.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: Dim.s),
        Text(
          def.tier.rewardLabel,
          style: AppText.label.copyWith(fontSize: 11.5, color: color),
        ),
      ],
    );
  }
}

class _ChestRow extends StatelessWidget {
  const _ChestRow({required this.chest});

  final Map<ResourceKind, int> chest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: Dim.brS,
            color: Palette.ember.withValues(alpha: 0.16),
            border: Border.all(color: Palette.ember.withValues(alpha: 0.42)),
          ),
          child: const Icon(Icons.card_giftcard_rounded, size: 16, color: Palette.ember),
        ),
        const SizedBox(width: Dim.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Perfect clear',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(fontSize: 12, color: Palette.ember),
              ),
              Text(
                'First three-star chest',
                style: AppText.eyebrow.copyWith(fontSize: 7.5, color: Palette.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: Dim.s),
        for (final entry in chest.entries)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpriteTile(name: entry.key.sprite, size: 18),
                const SizedBox(width: 3),
                Text(
                  '+${entry.value}',
                  style: AppText.label.copyWith(fontSize: 11.5, color: entry.key.color),
                ),
              ],
            ),
          ),
      ],
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
          if (victory)
            Text(
              'The flow held its heat and took the whole channel.',
              style: AppText.body14,
            )
          else
            _DeathRecap(cause: result.deathCause, label: result.deathLabel),
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

/// Post-mortem card on the defeat plate. Names what landed the killing blow
/// and points at the one lever (upgrade / perk / mutation) that would have
/// changed the outcome.
class _DeathRecap extends StatelessWidget {
  const _DeathRecap({required this.cause, required this.label});

  final DeathCause cause;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (cause == DeathCause.none) {
      return Text(
        'Structural integrity gave out before the channel ended.',
        style: AppText.body14,
      );
    }
    final tint = Palette.danger;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Dim.radiusS),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tint.withValues(alpha: 0.36)),
            ),
            child: Icon(_iconFor(cause), size: 18, color: tint),
          ),
          const SizedBox(width: Dim.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAKEN OUT BY',
                  style: AppText.eyebrow.copyWith(fontSize: 9, color: tint),
                ),
                const SizedBox(height: 2),
                Text(
                  _titleFor(cause, label),
                  style: AppText.label.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _hintFor(cause),
                  style: AppText.body14.copyWith(fontSize: 11.5, color: Palette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms, duration: 320.ms).slideY(begin: 0.12, curve: Curves.easeOutCubic);
  }

  static IconData _iconFor(DeathCause c) => switch (c) {
    DeathCause.enemyBody => Icons.pets_rounded,
    DeathCause.obstacle => Icons.construction_rounded,
    DeathCause.bossShot => Icons.flare_rounded,
    DeathCause.bossBody => Icons.warning_amber_rounded,
    DeathCause.heatCollapse => Icons.ac_unit_rounded,
    DeathCause.none => Icons.help_outline_rounded,
  };

  static String _titleFor(DeathCause c, String? label) => switch (c) {
    DeathCause.enemyBody =>
        label == null ? 'An enemy body slam' : 'A $label body slam',
    DeathCause.obstacle =>
        label == null ? 'An obstacle in the channel' : '$label in the channel',
    DeathCause.bossShot =>
        label == null ? 'A boss volley' : "$label's volley",
    DeathCause.bossBody =>
        label == null ? 'A boss slam' : 'Slamming into $label',
    DeathCause.heatCollapse => 'Your core went cold',
    DeathCause.none => 'Structural integrity failed',
  };

  static String _hintFor(DeathCause c) => switch (c) {
    DeathCause.enemyBody =>
      'Heat was below its armour. Lift Core Temperature or draft Obsidian Skin.',
    DeathCause.obstacle =>
      'Not enough mass to shatter it. Grow Mass Density or draft Wrecking Flow.',
    DeathCause.bossShot =>
      'Bank Obsidian Plating and dodge sooner, or surge straight through the volley.',
    DeathCause.bossBody =>
      'Erupt or surge before contact. Kindling and Giantslayer stack well here.',
    DeathCause.heatCollapse =>
      'Chase heat vents and raise Core Temperature so the flow keeps melting.',
    DeathCause.none =>
      'Structural integrity gave out before the channel ended.',
  };
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                const crossCount = 4;
                const rowCount = 2;
                const spacing = Dim.s;
                final tileW = (constraints.maxWidth - (crossCount - 1) * spacing) / crossCount;
                final tileH = (constraints.maxHeight - (rowCount - 1) * spacing) / rowCount;
                final ratio = tileW / tileH;
                return GridView.count(
                  crossAxisCount: crossCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: ratio,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      FlatPanel(
                            padding: const EdgeInsets.all(6),
                            accent: entries[i].$4,
                            child: LayoutBuilder(
                              builder: (ctx, tc) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: tc.maxWidth,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(entries[i].$1, size: 12, color: entries[i].$4),
                                      Text(
                                        entries[i].$3,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.numeric.copyWith(fontSize: 15),
                                      ),
                                      Text(
                                        entries[i].$2.toUpperCase(),
                                        style: AppText.eyebrow.copyWith(fontSize: 7.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: (i * 45).ms, duration: 280.ms)
                          .slideY(begin: 0.2, curve: Curves.easeOutCubic),
                  ],
                );
              },
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
      padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: Dim.s),
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
