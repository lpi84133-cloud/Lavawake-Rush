import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';

/// Skin gallery. A single large preview stage on top with a swipeable carousel
/// of cards along the bottom, so the screen reads as a showroom.
class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key});

  @override
  State<SkinsScreen> createState() => _SkinsScreenState();
}

class _SkinsScreenState extends State<SkinsScreen> {
  late int _focus = GameData.skins.indexWhere((s) => s.id == context.read<GameState>().selectedSkin);
  final ScrollController _railController = ScrollController();

  static const double _cardWidth = 90;
  static const double _cardStride = _cardWidth + Dim.s;

  @override
  void dispose() {
    _railController.dispose();
    super.dispose();
  }

  void _scrollToFocus(int index) {
    if (!_railController.hasClients) return;
    final viewport = _railController.position.viewportDimension;
    final target = (index * _cardStride) - (viewport - _cardWidth) / 2;
    final max = _railController.position.maxScrollExtent;
    _railController.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final index = _focus < 0 ? 0 : _focus;
    final skin = GameData.skins[index];
    final unlocked = game.unlockedSkins.contains(skin.id);
    final equipped = game.selectedSkin == skin.id;

    return ScreenShell(
      title: 'Skins',
      eyebrow: 'Appearance',
      accent: skin.tint,
      headerTrailing: Chip2(
        label: '${game.unlockedSkins.length} / ${GameData.skins.length} UNLOCKED',
        icon: Icons.lock_open_rounded,
        color: skin.tint,
        selected: true,
        dense: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: GlassPanel(
              padding: const EdgeInsets.all(Dim.l),
              accent: skin.tint,
              child: Row(
                children: [
                  Expanded(
                    flex: 45,
                    child: Center(
                      child:
                          SpriteTile(
                                name: skin.sprite,
                                size: 190,
                                locked: !unlocked,
                                glow: unlocked ? skin.tint : null,
                                glowStrength: 0.34,
                              )
                              .animate(key: ValueKey(skin.id))
                              .fadeIn(duration: 300.ms)
                              .scaleXY(begin: 0.85, curve: Curves.easeOutBack)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(begin: -6, end: 6, duration: 3000.ms, curve: Curves.easeInOut),
                    ),
                  ),
                  const SizedBox(width: Dim.l),
                  Expanded(
                    flex: 55,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            RarityTag(rarity: skin.rarity),
                            const SizedBox(width: Dim.s),
                            if (equipped)
                              Chip2(
                                label: 'EQUIPPED',
                                icon: Icons.check_rounded,
                                color: Palette.success,
                                selected: true,
                                dense: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: Dim.s),
                        Text(skin.name, style: AppText.hero.copyWith(fontSize: 30, color: skin.tint)),
                        const SizedBox(height: Dim.s),
                        Text(
                          unlocked
                              ? 'Ready to wear. The flow keeps its own colour whatever it swallows.'
                              : 'Locked. ${skin.unlockHint}',
                          style: AppText.body16,
                        ),
                        if (!unlocked) ...[
                          const SizedBox(height: Dim.m),
                          _UnlockProgress(skinId: skin.id, tint: skin.tint, game: game),
                        ],
                        const SizedBox(height: Dim.l),
                        Row(
                          children: [
                            LavaButton(
                              label: equipped
                                  ? 'Currently equipped'
                                  : unlocked
                                  ? 'Equip this skin'
                                  : 'Locked',
                              icon: unlocked ? Icons.check_circle_outline_rounded : Icons.lock_outline_rounded,
                              accent: skin.tint,
                              tone: unlocked && !equipped ? ButtonTone.primary : ButtonTone.ghost,
                              onPressed: unlocked && !equipped
                                  ? () {
                                      context.read<GameState>().selectSkin(skin.id);
                                      context.read<AudioService>().confirm();
                                    }
                                  : null,
                            ),
                            const SizedBox(width: Dim.m),
                            Expanded(
                              child: Text(
                                skin.unlockHint,
                                style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Dim.m),
          SizedBox(
            height: 116,
            child: ListView.separated(
              controller: _railController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: GameData.skins.length,
              separatorBuilder: (_, _) => const SizedBox(width: Dim.s),
              itemBuilder: (context, i) => SizedBox(
                width: 90,
                child: _SkinCard(
                  skin: GameData.skins[i],
                  unlocked: game.unlockedSkins.contains(GameData.skins[i].id),
                  equipped: game.selectedSkin == GameData.skins[i].id,
                  focused: i == index,
                  onTap: () {
                    context.read<AudioService>().tap();
                    setState(() => _focus = i);
                    _scrollToFocus(i);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A progress bar + numeric counter shown under a locked skin's description.
/// For boolean conditions (flawless run) it shows a simple "not yet" pill.
class _UnlockProgress extends StatelessWidget {
  const _UnlockProgress({required this.skinId, required this.tint, required this.game});

  final String skinId;
  final Color tint;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final progress = game.skinProgress(skinId);

    if (progress == null) {
      return Row(
        children: [
          Icon(Icons.radio_button_unchecked_rounded, size: 12, color: Palette.textMuted),
          const SizedBox(width: 6),
          Text('Not yet achieved', style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted)),
        ],
      );
    }

    final (current, max) = progress;
    final ratio = (current / max).clamp(0.0, 1.0);
    final isDone = current >= max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: MeterBar(value: ratio, height: 5, color: isDone ? Palette.success : tint)),
            const SizedBox(width: Dim.s),
            Text(
              '$current / $max',
              style: AppText.eyebrow.copyWith(
                fontSize: 9.5,
                color: isDone ? Palette.success : tint,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 280.ms);
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.equipped,
    required this.focused,
    required this.onTap,
  });

  final SkinDef skin;
  final bool unlocked;
  final bool equipped;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlatPanel(
      padding: const EdgeInsets.all(7),
      accent: skin.tint,
      selected: focused,
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: SpriteTile(
              name: skin.sprite,
              size: 60,
              locked: !unlocked,
              glow: focused && unlocked ? skin.tint : null,
              glowStrength: 0.22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            skin.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(
              fontSize: 10,
              color: focused ? skin.tint : Palette.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Icon(
            equipped
                ? Icons.check_circle_rounded
                : unlocked
                ? Icons.circle_outlined
                : Icons.lock_rounded,
            size: 10,
            color: equipped ? Palette.success : Palette.textMuted,
          ),
        ],
      ),
    );
  }
}
