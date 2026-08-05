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
import '../data/game_data.dart';
import '../data/models.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'level_brief_screen.dart';

/// Page physics with a gentler, slower spring so regions glide between snaps
/// instead of jumping. Critically damped (ratio 1.0) so there is no overshoot.
class _GlidePagePhysics extends PageScrollPhysics {
  const _GlidePagePhysics({super.parent});

  @override
  _GlidePagePhysics applyTo(ScrollPhysics? ancestor) =>
      _GlidePagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 1.1, stiffness: 78, ratio: 1.0);
}

/// Region browser. A cinematic pager of volcanic regions on top, and the eight
/// level nodes of the focused region strung along a path underneath.
class CampaignMapScreen extends StatefulWidget {
  const CampaignMapScreen({super.key});

  @override
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen> {
  late final PageController _pager;
  late int _region;

  @override
  void initState() {
    super.initState();
    _region = GameData.levelAt(context.read<GameState>().furthestLevel).regionIndex;
    _pager = PageController(viewportFraction: 0.56, initialPage: _region);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final region = GameData.regions[_region];
    final unlocked = game.isRegionUnlocked(_region);

    return ScreenShell(
      title: region.name,
      eyebrow: 'Region ${_region + 1} of ${GameData.regions.length}',
      accent: region.accent,
      headerTrailing: Row(
        children: [
          Chip2(
            label: '${game.regionStars(_region)}/${game.regionMaxStars(_region)}',
            icon: Icons.star_rounded,
            color: Palette.ember,
            selected: true,
          ),
          const SizedBox(width: Dim.s),
          Chip2(
            label: unlocked ? 'OPEN' : 'SEALED',
            icon: unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
            color: unlocked ? Palette.success : Palette.textMuted,
            selected: true,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 58,
            child: PageView.builder(
              controller: _pager,
              physics: const _GlidePagePhysics(parent: BouncingScrollPhysics()),
              itemCount: GameData.regions.length,
              onPageChanged: (index) {
                context.read<AudioService>().tap();
                setState(() => _region = index);
              },
              itemBuilder: (context, index) => _RegionCard(
                region: GameData.regions[index],
                focused: index == _region,
                stars: game.regionStars(index),
                maxStars: game.regionMaxStars(index),
              ),
            ),
          ),
          const SizedBox(height: Dim.m),
          Expanded(
            flex: 42,
            child: _LevelPath(
              key: ValueKey(_region),
              regionIndex: _region,
              game: game,
              accent: region.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.region,
    required this.focused,
    required this.stars,
    required this.maxStars,
  });

  final RegionDef region;
  final bool focused;
  final int stars;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: Dim.normal,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: Dim.s, vertical: focused ? 0 : Dim.m),
      child: ClipRRect(
        borderRadius: Dim.brL,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              region.background,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              // Slight desaturation for untouched regions (stars == 0),
              // but never full lock — all first levels are accessible.
              color: stars == 0 && region.index > 0
                  ? Palette.voidBlack.withValues(alpha: 0.28)
                  : null,
              colorBlendMode: stars == 0 && region.index > 0 ? BlendMode.srcATop : null,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Palette.voidBlack.withValues(alpha: focused ? 0.10 : 0.5),
                    Palette.voidBlack.withValues(alpha: 0.88),
                  ],
                  stops: const [0.3, 1],
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: Dim.brL,
                  border: Border.all(
                    color: focused ? region.accent.withValues(alpha: 0.8) : Palette.hairline,
                    width: focused ? 1.6 : 1,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Dim.m),
              // ClipRect hides any mid-animation overflow so the yellow debug
              // stripe never appears while the card is growing/shrinking.
              child: ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Soft hint for regions the player hasn't touched yet.
                    if (stars == 0 && region.index > 0)
                      Chip2(
                        label: 'FIRST LEVEL FREE',
                        icon: Icons.lock_open_rounded,
                        dense: true,
                        selected: true,
                        color: region.accent,
                      ),
                    const Spacer(),
                    Text(
                      'REGION ${region.index + 1}',
                      style: AppText.eyebrow.copyWith(color: region.accent),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      region.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title.copyWith(fontSize: focused ? 22 : 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      region.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14.copyWith(fontSize: 11.5, color: Palette.textSecondary),
                    ),
                    // AnimatedSize lets the description slot grow/shrink
                    // smoothly instead of popping in at the frame focused flips.
                    AnimatedSize(
                      duration: Dim.normal,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: focused
                          ? AnimatedOpacity(
                              opacity: focused ? 1.0 : 0.0,
                              duration: Dim.normal,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  region.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body14.copyWith(
                                    fontSize: 10.5,
                                    color: Palette.textMuted,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: Dim.s),
                    Row(
                      children: [
                        Expanded(
                          child: MeterBar(
                            value: maxStars == 0 ? 0 : stars / maxStars,
                            color: region.accent,
                            height: 4,
                          ),
                        ),
                        const SizedBox(width: Dim.s),
                        Text(
                          '$stars/$maxStars',
                          style: AppText.eyebrow.copyWith(color: Palette.ember, letterSpacing: 0.6),
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
    );
  }
}

class _LevelPath extends StatelessWidget {
  const _LevelPath({
    super.key,
    required this.regionIndex,
    required this.game,
    required this.accent,
  });

  final int regionIndex;
  final GameState game;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final levels = GameData.levels.where((l) => l.regionIndex == regionIndex).toList();

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: Dim.s),
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(text: 'Level path', color: accent),
          const SizedBox(height: Dim.s),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // The connecting line sits behind the nodes and reads as the
                    // route through the region.
                    Positioned(
                      left: constraints.maxWidth / levels.length / 2,
                      right: constraints.maxWidth / levels.length / 2,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.4),
                              accent.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < levels.length; i++)
                          Expanded(
                            child: _LevelNode(
                              level: levels[i],
                              stars: game.levelStars[levels[i].globalIndex] ?? 0,
                              unlocked: game.isLevelUnlocked(levels[i].globalIndex),
                              accent: accent,
                              index: i,
                            ),
                          ),
                      ],
                    ),
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

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.accent,
    required this.index,
  });

  final LevelDef level;
  final int stars;
  final bool unlocked;
  final Color accent;
  final int index;

  @override
  Widget build(BuildContext context) {
    final diameter = level.isBoss ? 46.0 : 40.0;
    final cleared = stars > 0;

    return GestureDetector(
      onTap: () {
        final audio = context.read<AudioService>();
        if (!unlocked) {
          audio.error();
          return;
        }
        audio.confirm();
        goTo(context, LevelBriefScreen(level: level));
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cleared
                  ? accent.withValues(alpha: 0.22)
                  : unlocked
                  ? Palette.surfaceHigh
                  : Palette.surface.withValues(alpha: 0.7),
              border: Border.all(
                color: unlocked ? accent.withValues(alpha: cleared ? 0.9 : 0.45) : Palette.hairline,
                width: level.isBoss ? 2 : 1.2,
              ),
              boxShadow: cleared
                  ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 16)]
                  : null,
            ),
            child: Center(
              child: !unlocked
                  ? const Icon(Icons.lock_rounded, size: 15, color: Palette.textMuted)
                  : level.isBoss
                  ? Icon(Icons.whatshot_rounded, size: 22, color: accent)
                  : Text(
                      '${level.indexInRegion + 1}',
                      style: AppText.numeric.copyWith(fontSize: 16, color: Palette.textPrimary),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          StarRow(filled: stars, size: 9),
          const SizedBox(height: 2),
          Text(
            level.isBoss ? 'BOSS' : level.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.eyebrow.copyWith(
              fontSize: 8,
              letterSpacing: 0.8,
              color: level.isBoss ? accent : Palette.textMuted,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 45).ms, duration: 280.ms).scaleXY(begin: 0.8, curve: Curves.easeOutBack);
  }
}
