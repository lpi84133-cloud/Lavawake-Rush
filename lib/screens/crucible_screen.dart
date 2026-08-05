import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/perks.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import '../state/settings_state.dart';

/// The Crucible: a three-column perk tree spent with points earned from levelling
/// up. Everything here reshapes how a *run* plays, not just flat stats, so it is
/// the meta layer that ties the roguelite drafts together.
class CrucibleScreen extends StatelessWidget {
  const CrucibleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();

    return ScreenShell(
      title: 'The Crucible',
      eyebrow: 'Permanent perks',
      accent: Palette.crimson,
      headerTrailing: Row(
        children: [
          if (game.perkRanksSpent > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip2(
                label: 'RESPEC',
                icon: Icons.restart_alt_rounded,
                color: Palette.frost,
                dense: true,
                onTap: () {
                  context.read<AudioService>().back();
                  game.respecPerks();
                },
              ),
            ),
          _PointsBadge(points: game.perkPoints),
        ],
      ),
      footer: FlatPanel(
        padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, size: 13, color: Palette.ember),
            const SizedBox(width: Dim.s),
            Expanded(
              child: Text(
                'Earn a perk point every time your flow gains a level. Perks stack with the mutations you '
                'draft inside a run, so plan the board around the build you want to chase.',
                style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
              ),
            ),
            Text('${game.perkRanksSpent} SPENT', style: AppText.eyebrow.copyWith(fontSize: 9)),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final column in PerkColumn.values) ...[
            if (column != PerkColumn.flow) const SizedBox(width: Dim.m),
            Expanded(child: _PerkColumnView(column: column, game: game)),
          ],
        ],
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Palette.ember.withValues(alpha: points > 0 ? 0.16 : 0.06),
        border: Border.all(color: Palette.ember.withValues(alpha: points > 0 ? 0.5 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: points > 0 ? Palette.ember : Palette.textMuted),
          const SizedBox(width: 6),
          Text(
            '$points ${points == 1 ? 'POINT' : 'POINTS'}',
            style: AppText.label.copyWith(
              fontSize: 12,
              color: points > 0 ? Palette.ember : Palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerkColumnView extends StatelessWidget {
  const _PerkColumnView({required this.column, required this.game});

  final PerkColumn column;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final perks = kPerks.where((p) => p.column == column).toList()
      ..sort((a, b) => a.tier.compareTo(b.tier));

    return GlassPanel(
      padding: EdgeInsets.zero,
      accent: column.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed column header.
          Padding(
            padding: const EdgeInsets.fromLTRB(Dim.m, Dim.m, Dim.m, Dim.s),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: Dim.brS,
                    color: column.color.withValues(alpha: 0.16),
                    border: Border.all(color: column.color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(column.icon, size: 16, color: column.color),
                ),
                const SizedBox(width: Dim.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(column.label, style: AppText.subtitle.copyWith(fontSize: 15)),
                      Text(
                        column.blurb,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body14.copyWith(fontSize: 10, color: Palette.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable perk list so three tiers never overflow the panel height.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(Dim.m, 0, Dim.m, Dim.m),
              itemCount: perks.length * 2 - 1,
              itemBuilder: (context, i) {
                if (i.isOdd) {
                  final next = perks[(i + 1) ~/ 2];
                  return Center(
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 15,
                      color: game.isPerkUnlocked(next) ? column.color : Palette.textMuted,
                    ),
                  );
                }
                final idx = i ~/ 2;
                return _PerkNode(def: perks[idx], game: game, index: idx);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PerkNode extends StatelessWidget {
  const _PerkNode({required this.def, required this.game, required this.index});

  final PerkDef def;
  final GameState game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final rank = game.perkRank(def.id);
    final unlocked = game.isPerkUnlocked(def);
    final canBuy = game.canBuyPerk(def);
    final maxed = rank >= def.ranks;
    final accent = def.color;

    return FlatPanel(
          padding: const EdgeInsets.all(10),
          accent: accent,
          selected: rank > 0,
          onTap: canBuy
              ? () {
                  final audio = context.read<AudioService>();
                  if (game.buyPerk(def)) {
                    audio.unlock();
                    context.read<SettingsState>().thud();
                  } else {
                    audio.error();
                  }
                }
              : null,
          child: Opacity(
            opacity: unlocked ? 1 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(unlocked ? def.icon : Icons.lock_rounded, size: 15, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        def.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(fontSize: 12.5),
                      ),
                    ),
                    if (canBuy)
                      const Icon(Icons.add_circle_rounded, size: 16, color: Palette.ember)
                    else if (maxed)
                      const Icon(Icons.check_circle_rounded, size: 15, color: Palette.success),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  def.describe(rank),
                  style: AppText.body14.copyWith(fontSize: 10.5, color: Palette.textSecondary),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (var i = 0; i < def.ranks; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == def.ranks - 1 ? 0 : 3),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i < rank ? accent : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (index * 40).ms, duration: 240.ms)
        .slideX(begin: 0.05, curve: Curves.easeOutCubic);
  }
}
