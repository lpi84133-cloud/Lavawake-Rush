import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/avatar_picker_sheet.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';

/// Profile. One tall identity card on the left holding the photo, name field and
/// level ring; a mosaic of milestone tiles on the right.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(
    text: context.read<GameState>().playerName,
  );
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commitName() {
    final value = _name.text.trim();
    if (value.isEmpty) {
      _name.text = context.read<GameState>().playerName;
      return;
    }
    context.read<GameState>().setProfile(name: value);
    context.read<AudioService>().confirm();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final skin = GameData.skinById[game.selectedSkin];

    return ScreenShell(
      title: 'Profile',
      eyebrow: game.playerTitle,
      accent: skin?.tint ?? Palette.lava,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 38, child: _IdentityCard(game: game, name: _name, focus: _focus, onCommit: _commitName)),
          const SizedBox(width: Dim.m),
          Expanded(flex: 62, child: _Mosaic(game: game)),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.game,
    required this.name,
    required this.focus,
    required this.onCommit,
  });

  final GameState game;
  final TextEditingController name;
  final FocusNode focus;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final skin = GameData.skinById[game.selectedSkin];
    final accent = skin?.tint ?? Palette.lava;

    return GlassPanel(
      padding: const EdgeInsets.all(Dim.l),
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircularPercentIndicator(
                  radius: 56,
                  lineWidth: 5,
                  percent: game.levelProgress,
                  animation: true,
                  animationDuration: 800,
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  progressColor: Palette.ember,
                  center: PlayerAvatar(
                    imagePath: game.avatarPath,
                    fallbackSprite: skin?.sprite ?? 'skin_ember',
                    size: 92,
                    accent: accent,
                    ring: false,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: CircleAction(
                    icon: Icons.photo_camera_rounded,
                    size: 36,
                    filled: true,
                    accent: accent,
                    tooltip: 'Change photo',
                    onTap: () => showAvatarPicker(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dim.m),
          TextField(
            controller: name,
            focusNode: focus,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            maxLength: 16,
            style: AppText.title.copyWith(fontSize: 22),
            cursorColor: accent,
            onSubmitted: (_) => onCommit(),
            onTapOutside: (_) => onCommit(),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: Palette.surfaceHigh.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: Dim.m),
              hintText: 'Your name',
              hintStyle: AppText.title.copyWith(fontSize: 22, color: Palette.textMuted),
              border: OutlineInputBorder(borderRadius: Dim.brS, borderSide: const BorderSide(color: Palette.hairline)),
              enabledBorder: OutlineInputBorder(
                borderRadius: Dim.brS,
                borderSide: const BorderSide(color: Palette.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: Dim.brS,
                borderSide: BorderSide(color: accent.withValues(alpha: 0.6)),
              ),
              suffixIcon: Icon(Icons.edit_rounded, size: 15, color: accent),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Shimmer.fromColors(
              baseColor: Palette.textSecondary,
              highlightColor: accent,
              period: const Duration(milliseconds: 3200),
              child: Text(game.playerTitle.toUpperCase(), style: AppText.eyebrow),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FlatPanel(
                  padding: const EdgeInsets.all(Dim.s),
                  child: Column(
                    children: [
                      Text('LEVEL', style: AppText.eyebrow.copyWith(fontSize: 8.5)),
                      const SizedBox(height: 3),
                      Text('${game.playerLevel}', style: AppText.numeric.copyWith(fontSize: 22)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Dim.s),
              Expanded(
                child: FlatPanel(
                  padding: const EdgeInsets.all(Dim.s),
                  child: Column(
                    children: [
                      Text('XP', style: AppText.eyebrow.copyWith(fontSize: 8.5)),
                      const SizedBox(height: 3),
                      Text(formatCount(game.xp), style: AppText.numeric.copyWith(fontSize: 22)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Dim.s),
              Expanded(
                child: FlatPanel(
                  padding: const EdgeInsets.all(Dim.s),
                  child: Column(
                    children: [
                      Text('NEXT', style: AppText.eyebrow.copyWith(fontSize: 8.5)),
                      const SizedBox(height: 3),
                      Text(
                        '${(game.levelProgress * 100).round()}%',
                        style: AppText.numeric.copyWith(fontSize: 22, color: Palette.ember),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideX(begin: -0.05, curve: Curves.easeOutCubic);
  }
}

class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String, IconData, Color)>[
      ('Levels cleared', '${game.levelsCleared} / ${GameData.levelCount}', Icons.flag_rounded, Palette.lava),
      ('Bosses felled', '${game.bossesFelled()} / 6', Icons.gpp_bad_rounded, Palette.crimson),
      ('Bestiary', '${game.collectionCount} / ${GameData.enemies.length}', Icons.pets_rounded, Palette.crystal),
      ('Skins', '${game.unlockedSkins.length} / ${GameData.skins.length}', Icons.palette_rounded, Palette.venom),
      (
        'Achievements',
        '${game.unlockedAchievements.length} / ${GameData.achievements.length}',
        Icons.emoji_events_rounded,
        Palette.warning,
      ),
      ('Upgrade levels', '${game.upgradeLevelsBought} / 64', Icons.tune_rounded, Palette.frost),
      ('Rush best', formatCount(game.endlessBest), Icons.speed_rounded, Palette.ember),
      ('Best combo', '${game.stats.bestCombo}', Icons.link_rounded, Palette.metal),
      ('Flawless runs', '${game.stats.flawlessRuns}', Icons.verified_rounded, Palette.success),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 3,
            mainAxisSpacing: Dim.s,
            crossAxisSpacing: Dim.s,
            childAspectRatio: 2.2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < tiles.length; i++)
                FlatPanel(
                      padding: const EdgeInsets.all(Dim.m),
                      accent: tiles[i].$4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(tiles[i].$3, size: 13, color: tiles[i].$4),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  tiles[i].$1.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.eyebrow.copyWith(fontSize: 8),
                                ),
                              ),
                            ],
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(tiles[i].$2, style: AppText.numeric.copyWith(fontSize: 20)),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: (i * 32).ms, duration: 280.ms)
                    .scaleXY(begin: 0.95, curve: Curves.easeOutBack),
            ],
          ),
        ),
        const SizedBox(height: Dim.s),
        FlatPanel(
          padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 13, color: Palette.textMuted),
              const SizedBox(width: Dim.s),
              Expanded(
                child: Text(
                  'Your name, photo and every number here stay on this device. Nothing is uploaded.',
                  style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
                ),
              ),
              for (final kind in ResourceKind.values)
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: ResourcePill(kind: kind, amount: game.resources[kind]!, dense: true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
