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
import '../state/game_state.dart';

const List<Color> _medals = [Color(0xFFEFC050), Color(0xFFC9CBD4), Color(0xFFC08457)];

/// Local standings. A three-column podium on the left and the remainder of the
/// board as a ranked list on the right.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final board = game.leaderboard;
    final playerRank = board.indexWhere((e) => e.isPlayer) + 1;
    final top = board.take(3).toList();
    final rest = board.skip(3).toList();

    return ScreenShell(
      title: 'Leaderboard',
      eyebrow: 'Stored on this device',
      accent: Palette.ember,
      headerTrailing: Chip2(
        label: 'YOUR RANK #$playerRank',
        icon: Icons.person_rounded,
        color: Palette.ember,
        selected: true,
        dense: true,
      ),
      footer: FlatPanel(
        padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.smartphone_rounded, size: 13, color: Palette.textMuted),
            const SizedBox(width: Dim.s),
            Expanded(
              child: Text(
                'The board is generated locally from your best score and a fixed roster of ${GameData.rivalNames.length} '
                'rival flows, so standings are available with no connection at all.',
                style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
              ),
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 46,
            child: GlassPanel(
              padding: const EdgeInsets.all(Dim.m),
              accent: Palette.ember,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(text: 'Podium', color: Palette.ember),
                  const SizedBox(height: Dim.m),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (top.length > 1)
                          Expanded(child: _Podium(entry: top[1], place: 2, heightFactor: 0.74, game: game)),
                        if (top.isNotEmpty)
                          Expanded(child: _Podium(entry: top[0], place: 1, heightFactor: 1, game: game)),
                        if (top.length > 2)
                          Expanded(child: _Podium(entry: top[2], place: 3, heightFactor: 0.6, game: game)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Dim.m),
          Expanded(
            flex: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(
                  text: 'Standings',
                  trailing: Text(
                    '${board.length} FLOWS',
                    style: AppText.eyebrow.copyWith(fontSize: 9),
                  ),
                ),
                const SizedBox(height: Dim.s),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rest.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final entry = rest[index];
                      return FlatPanel(
                        padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 9),
                        accent: entry.isPlayer ? Palette.lava : null,
                        selected: entry.isPlayer,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text(
                                '${index + 4}',
                                style: AppText.label.copyWith(
                                  fontSize: 12,
                                  color: entry.isPlayer ? Palette.lava : Palette.textMuted,
                                ),
                              ),
                            ),
                            if (entry.isPlayer)
                              PlayerAvatar(
                                imagePath: game.avatarPath,
                                fallbackSprite:
                                    GameData.skinById[game.selectedSkin]?.sprite ?? 'skin_ember',
                                size: 26,
                                ring: false,
                              )
                            else
                              Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Palette.surfaceHigh,
                                ),
                                child: const Icon(
                                  Icons.water_drop_rounded,
                                  size: 12,
                                  color: Palette.textMuted,
                                ),
                              ),
                            const SizedBox(width: Dim.s),
                            Expanded(
                              child: Text(
                                entry.isPlayer ? '${entry.name}  (you)' : entry.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.label.copyWith(fontSize: 12.5),
                              ),
                            ),
                            Text(
                              formatCount(entry.score),
                              style: AppText.label.copyWith(
                                fontSize: 12.5,
                                color: entry.isPlayer ? Palette.ember : Palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (index * 22).ms, duration: 240.ms).slideX(begin: 0.05);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.entry,
    required this.place,
    required this.heightFactor,
    required this.game,
  });

  final LeaderboardEntry entry;
  final int place;
  final double heightFactor;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final medal = _medals[place - 1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (entry.isPlayer)
            PlayerAvatar(
              imagePath: game.avatarPath,
              fallbackSprite: GameData.skinById[game.selectedSkin]?.sprite ?? 'skin_ember',
              size: place == 1 ? 46 : 36,
              accent: medal,
            )
          else
            Container(
              width: place == 1 ? 46 : 36,
              height: place == 1 ? 46 : 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.surfaceHigh,
                border: Border.all(color: medal.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.water_drop_rounded, size: place == 1 ? 20 : 15, color: medal),
            ),
          const SizedBox(height: 6),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(fontSize: place == 1 ? 12.5 : 11),
          ),
          Text(
            formatCount(entry.score),
            style: AppText.label.copyWith(fontSize: 11, color: medal),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [medal.withValues(alpha: 0.42), medal.withValues(alpha: 0.05)],
                  ),
                  border: Border.all(color: medal.withValues(alpha: 0.3)),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '$place',
                      style: AppText.numeric.copyWith(fontSize: place == 1 ? 24 : 18, color: medal),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (place * 90).ms, duration: 340.ms).slideY(begin: 0.14);
  }
}
