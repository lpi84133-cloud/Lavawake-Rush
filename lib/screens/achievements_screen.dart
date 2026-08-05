import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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

/// Achievements. A tier summary band across the top, a filter row, then a
/// staggered grid of medal cards.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  AchievementTier? _tier;
  bool _onlyLocked = false;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final all = GameData.achievements;
    final visible = all.where((def) {
      if (_tier != null && def.tier != _tier) return false;
      if (_onlyLocked && game.isAchievementUnlocked(def)) return false;
      return true;
    }).toList();
    final unlocked = all.where(game.isAchievementUnlocked).length;

    return ScreenShell(
      title: 'Achievements',
      eyebrow: 'Long-term goals',
      accent: Palette.warning,
      headerTrailing: Row(
        children: [
          Text(
            '$unlocked',
            style: AppText.numeric.copyWith(fontSize: 22, color: Palette.warning),
          ),
          Text(
            ' / ${all.length}',
            style: AppText.label.copyWith(fontSize: 12, color: Palette.textMuted),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final tier in AchievementTier.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: tier == AchievementTier.molten ? 0 : Dim.s),
                    child: _TierTile(
                      tier: tier,
                      unlocked: all.where((d) => d.tier == tier && game.isAchievementUnlocked(d)).length,
                      total: all.where((d) => d.tier == tier).length,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Dim.m),
          Row(
            children: [
              Chip2(
                label: 'ALL',
                selected: _tier == null,
                color: Palette.warning,
                dense: true,
                onTap: () => _setTier(null),
              ),
              for (final tier in AchievementTier.values)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Chip2(
                    label: tier.label.toUpperCase(),
                    selected: _tier == tier,
                    color: tier.color,
                    dense: true,
                    onTap: () => _setTier(tier),
                  ),
                ),
              const Spacer(),
              Chip2(
                label: 'HIDE COMPLETED',
                icon: _onlyLocked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                selected: _onlyLocked,
                color: Palette.frost,
                dense: true,
                onTap: () {
                  context.read<AudioService>().toggle();
                  setState(() => _onlyLocked = !_onlyLocked);
                },
              ),
            ],
          ),
          const SizedBox(height: Dim.m),
          Expanded(
            child: visible.isEmpty
                ? const EmptyHint(
                    icon: Icons.emoji_events_outlined,
                    title: 'Nothing left here',
                    message: 'Every achievement in this filter is already unlocked.',
                  )
                : AnimationLimiter(
                    key: ValueKey('${_tier?.name}-$_onlyLocked'),
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: Dim.s,
                        crossAxisSpacing: Dim.s,
                        childAspectRatio: 2.9,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final def = visible[index];
                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          columnCount: 3,
                          duration: const Duration(milliseconds: 320),
                          child: ScaleAnimation(
                            scale: 0.94,
                            child: FadeInAnimation(
                              child: _AchievementCard(
                                def: def,
                                progress: game.achievementProgress(def),
                                unlocked: game.isAchievementUnlocked(def),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _setTier(AchievementTier? tier) {
    context.read<AudioService>().tap();
    setState(() => _tier = tier);
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({required this.tier, required this.unlocked, required this.total});

  final AchievementTier tier;
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    return FlatPanel(
      padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 10),
      accent: tier.color,
      selected: unlocked == total,
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, size: 17, color: tier.color),
          const SizedBox(width: Dim.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.label.toUpperCase(), style: AppText.eyebrow.copyWith(color: tier.color, fontSize: 9)),
                const SizedBox(height: 4),
                MeterBar(value: total == 0 ? 0 : unlocked / total, color: tier.color, height: 4),
              ],
            ),
          ),
          const SizedBox(width: Dim.s),
          Text('$unlocked/$total', style: AppText.label.copyWith(fontSize: 11.5)),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: -0.2, curve: Curves.easeOutCubic);
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.def, required this.progress, required this.unlocked});

  final AchievementDef def;
  final int progress;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final ratio = (progress / def.target).clamp(0.0, 1.0);
    final accent = unlocked ? def.tier.color : Palette.textMuted;

    return FlatPanel(
      padding: const EdgeInsets.all(10),
      accent: accent,
      selected: unlocked,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: unlocked ? 0.18 : 0.07),
              border: Border.all(color: accent.withValues(alpha: unlocked ? 0.55 : 0.2)),
              boxShadow: unlocked
                  ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: -4)]
                  : null,
            ),
            child: Icon(unlocked ? def.icon : Icons.lock_outline_rounded, size: 17, color: accent),
          ),
          const SizedBox(width: Dim.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  def.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  def.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14.copyWith(fontSize: 10.5, color: Palette.textMuted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: MeterBar(value: ratio, color: accent, height: 4, showTrackGlow: false)),
                    const SizedBox(width: 6),
                    Text(
                      unlocked ? 'DONE' : '$progress/${def.target}',
                      style: AppText.eyebrow.copyWith(fontSize: 8.5, color: accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
