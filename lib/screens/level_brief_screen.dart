import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/nav.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/asset_catalog.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../game/sprite_cache.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'gameplay_screen.dart';

/// Pre-run briefing. Splits into a cinematic left plate with the launch control
/// and a right column of data panels, so it reads like a mission sheet rather
/// than another card grid.
class LevelBriefScreen extends StatefulWidget {
  const LevelBriefScreen({super.key, required this.level});

  final LevelDef level;

  @override
  State<LevelBriefScreen> createState() => _LevelBriefScreenState();
}

class _LevelBriefScreenState extends State<LevelBriefScreen> {
  bool _ready = false;
  late final String _tip;

  @override
  void initState() {
    super.initState();
    _tip = GameData.tips[widget.level.globalIndex % GameData.tips.length];
    _warmUp();
  }

  /// Decodes exactly what this level needs while the player reads the brief, so
  /// the first second of gameplay never stutters.
  Future<void> _warmUp() async {
    final region = GameData.regions[widget.level.regionIndex];
    await SpriteCache.instance.load(region.background);
    await SpriteCache.instance.loadAll([
      ...GameData.sceneryPaths(),
      ...region.families.expand(GameData.family).map((e) => Art.sprite(e.sprite)),
    ], targetHeight: 320);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final region = GameData.regions[level.regionIndex];
    final game = context.watch<GameState>();
    final roster = region.families
        .expand(GameData.family)
        .where((e) => e.rarity != Rarity.boss)
        .take(6)
        .toList();

    return ScreenShell(
      title: level.name,
      eyebrow: '${region.name} - level ${level.indexInRegion + 1}',
      accent: region.accent,
      headerTrailing: StarRow(filled: game.levelStars[level.globalIndex] ?? 0, size: 15),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 47, child: _HeroPlate(level: level, region: region, ready: _ready)),
          const SizedBox(width: Dim.m),
          Expanded(
            flex: 53,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ResistancePanel(roster: roster, level: level, region: region)),
                const SizedBox(height: Dim.m),
                _RewardPanel(level: level, tip: _tip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPlate extends StatelessWidget {
  const _HeroPlate({required this.level, required this.region, required this.ready});

  final LevelDef level;
  final RegionDef region;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final skin = GameData.skinById[game.selectedSkin];

    return ClipRRect(
      borderRadius: Dim.brL,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(region.background, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Palette.voidBlack.withValues(alpha: 0.25),
                  Palette.voidBlack.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Dim.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip2(
                      label: '${level.distance.round()} M CHANNEL',
                      icon: Icons.straighten_rounded,
                      dense: true,
                      selected: true,
                      color: region.accent,
                    ),
                    const SizedBox(width: 6),
                    Chip2(
                      label: 'DIFFICULTY ${level.difficulty.toStringAsFixed(1)}',
                      icon: Icons.whatshot_rounded,
                      dense: true,
                      selected: true,
                      color: Palette.crimson,
                    ),
                  ],
                ),
                const Spacer(),
                if (skin != null)
                  Row(
                    children: [
                      SpriteTile(name: skin.sprite, size: 62, glow: skin.tint),
                      const SizedBox(width: Dim.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('YOUR FLOW', style: AppText.eyebrow.copyWith(color: skin.tint)),
                            Text(skin.name, style: AppText.subtitle),
                            Text(
                              'Level ${game.playerLevel} - ${game.playerTitle}',
                              style: AppText.body14.copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: Dim.m),
                LavaButton(
                  label: ready ? (level.isBoss ? 'Face the warden' : 'Begin the rush') : 'Preparing the channel',
                  icon: ready ? Icons.play_arrow_rounded : Icons.hourglass_top_rounded,
                  expand: true,
                  accent: region.accent,
                  onPressed: ready
                      ? () {
                          context.read<AudioService>().play(Sfx.levelStart);
                          Navigator.of(context).pushReplacement(fadeThrough(GameplayScreen(level: level)));
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 340.ms).slideX(begin: -0.05, curve: Curves.easeOutCubic);
  }
}

class _ResistancePanel extends StatelessWidget {
  const _ResistancePanel({required this.roster, required this.level, required this.region});

  final List<EnemyDef> roster;
  final LevelDef level;
  final RegionDef region;

  @override
  Widget build(BuildContext context) {
    final boss = level.bossId == null ? null : GameData.enemyById[level.bossId!];

    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: region.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            text: 'Expected resistance',
            color: region.accent,
            trailing: Text('${roster.length} types', style: AppText.eyebrow),
          ),
          const SizedBox(height: Dim.m),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: Dim.s,
              crossAxisSpacing: Dim.s,
              childAspectRatio: 1.42,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < roster.length; i++)
                  FlatPanel(
                        padding: const EdgeInsets.all(8),
                        accent: roster[i].essence.color,
                        child: Row(
                          children: [
                            SpriteTile(name: roster[i].sprite, size: 34),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    roster[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.label.copyWith(fontSize: 10.5),
                                  ),
                                  const SizedBox(height: 4),
                                  MeterBar(
                                    value: roster[i].armor,
                                    color: roster[i].essence.color,
                                    height: 3,
                                    showTrackGlow: false,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'ARMOUR ${(roster[i].armor * 100).round()}%',
                                    style: AppText.eyebrow.copyWith(fontSize: 8, letterSpacing: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(delay: (i * 45).ms, duration: 260.ms)
                      .slideY(begin: 0.16, curve: Curves.easeOutCubic),
              ],
            ),
          ),
          if (boss != null) ...[
            const SizedBox(height: Dim.s),
            FlatPanel(
              padding: const EdgeInsets.all(Dim.s),
              accent: Palette.crimson,
              selected: true,
              child: Row(
                children: [
                  SpriteTile(name: boss.sprite, size: 40, glow: Palette.crimson),
                  const SizedBox(width: Dim.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(boss.name, style: AppText.label.copyWith(fontSize: 12)),
                            const SizedBox(width: 6),
                            const RarityTag(rarity: Rarity.boss),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          boss.lore,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body14.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardPanel extends StatelessWidget {
  const _RewardPanel({required this.level, required this.tip});

  final LevelDef level;
  final String tip;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 0),
              Expanded(child: SectionLabel(text: 'Clear rewards')),
              for (final entry in level.rewards.entries)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ResourcePill(kind: entry.key, amount: entry.value, dense: true),
                ),
            ],
          ),
          const SizedBox(height: Dim.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 14, color: Palette.ember),
              const SizedBox(width: 6),
              Expanded(
                child: Text(tip, style: AppText.body14.copyWith(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
