import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/nav.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/asset_catalog.dart';
import '../data/game_data.dart';
import '../game/sprite_cache.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'gameplay_screen.dart';

/// Endless mode. Built as one centred column around a single enormous number, so
/// it feels like a scoreboard rather than a menu.
class RushModeScreen extends StatefulWidget {
  const RushModeScreen({super.key});

  @override
  State<RushModeScreen> createState() => _RushModeScreenState();
}

class _RushModeScreenState extends State<RushModeScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _warmUp();
  }

  Future<void> _warmUp() async {
    await SpriteCache.instance.load(GameData.regions.last.background);
    await SpriteCache.instance.loadAll(GameData.sceneryPaths(), targetHeight: 320);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final skin = GameData.skinById[game.selectedSkin];

    return ScreenShell(
      title: 'Rush Mode',
      eyebrow: 'Endless descent',
      accent: Palette.crimson,
      backgroundIntensity: 1.25,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Text('PERSONAL BEST', style: AppText.eyebrow.copyWith(color: Palette.ember)),
              const SizedBox(height: 2),
              Shimmer.fromColors(
                baseColor: Palette.textPrimary,
                highlightColor: Palette.ember,
                period: const Duration(milliseconds: 2600),
                child: Text(
                  game.endlessBest == 0 ? '- - -' : formatCount(game.endlessBest),
                  style: AppText.hero.copyWith(fontSize: 62, letterSpacing: -2.5),
                ),
              ),
              const SizedBox(height: Dim.m),
              Text(
                'Caldera Prime never ends here. The channel accelerates, every family of creature shows '
                'up, and the run only stops when your integrity does.',
                textAlign: TextAlign.center,
                style: AppText.body16,
              ),
              const SizedBox(height: Dim.l),
              Row(
                children: [
                  Expanded(
                    child: _RuleCard(
                      icon: Icons.speed_rounded,
                      title: 'Escalating pace',
                      body: 'Flow speed climbs steadily for as long as you survive.',
                    ),
                  ),
                  const SizedBox(width: Dim.s),
                  Expanded(
                    child: _RuleCard(
                      icon: Icons.groups_rounded,
                      title: 'Mixed roster',
                      body: 'All five families spawn together from the first minute.',
                    ),
                  ),
                  const SizedBox(width: Dim.s),
                  Expanded(
                    child: _RuleCard(
                      icon: Icons.ac_unit_rounded,
                      title: 'Cold seams',
                      body: 'Rime bands cut the channel and bleed your heat away.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dim.l),
              GlassPanel(
                padding: const EdgeInsets.all(Dim.m),
                accent: skin?.tint ?? Palette.lava,
                child: Row(
                  children: [
                    if (skin != null) SpriteTile(name: skin.sprite, size: 56, glow: skin.tint),
                    const SizedBox(width: Dim.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FLOW: ${(skin?.name ?? 'Ember').toUpperCase()}',
                            style: AppText.eyebrow.copyWith(color: skin?.tint ?? Palette.lava),
                          ),
                          Text(
                            'Level ${game.playerLevel} - ${game.upgradeLevelsBought} upgrade levels active',
                            style: AppText.body14.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    LavaButton(
                      label: _ready ? 'Start endless run' : 'Preparing',
                      icon: _ready ? Icons.play_arrow_rounded : Icons.hourglass_top_rounded,
                      accent: Palette.crimson,
                      onPressed: _ready
                          ? () {
                              context.read<AudioService>().play(Sfx.levelStart);
                              Navigator.of(
                                context,
                              ).pushReplacement(fadeThrough(const GameplayScreen(endless: true)));
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return FlatPanel(
      padding: const EdgeInsets.all(Dim.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Palette.crimson),
          const SizedBox(height: Dim.s),
          Text(title, style: AppText.label.copyWith(fontSize: 12.5)),
          const SizedBox(height: 3),
          Text(body, style: AppText.body14.copyWith(fontSize: 11.5)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.14, curve: Curves.easeOutCubic);
  }
}
