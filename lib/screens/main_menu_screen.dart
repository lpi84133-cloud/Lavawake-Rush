import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/nav.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/lava_background.dart';
import '../data/asset_catalog.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'about_screen.dart';
import 'campaign_map_screen.dart';
import 'collection_hub_screen.dart';
import 'crucible_screen.dart';
import 'forge_screen.dart';
import 'level_brief_screen.dart';
import 'profile_screen.dart';
import 'quests_screen.dart';
import 'rush_mode_screen.dart';
import 'settings_screen.dart';
import 'skins_screen.dart';
import 'tutorial_screen.dart';
import 'upgrades_screen.dart';
import 'web_page_screen.dart';

/// The hub. Deliberately asymmetric: a tall branding column on the left, a dense
/// destination grid on the right, and a thin utility rail underneath.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final audio = context.read<AudioService>();
    final unclaimed = game.quests.where((q) => q.complete && !q.claimed).length;

    return Scaffold(
      backgroundColor: Palette.ink,
      body: LavaBackground(
        embers: 26,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Dim.l, Dim.s, Dim.l, Dim.m),
            child: Column(
              children: [
                _TopStrip(game: game),
                const SizedBox(height: Dim.m),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 39, child: _BrandColumn(game: game)),
                      const SizedBox(width: Dim.l),
                      Expanded(
                        flex: 61,
                        child: _DestinationGrid(unclaimedQuests: unclaimed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Dim.m),
                _UtilityRail(audio: audio),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopStrip extends StatelessWidget {
  const _TopStrip({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            context.read<AudioService>().tap();
            goTo(context, const ProfileScreen());
          },
          child: Row(
            children: [
              PlayerAvatar(
                imagePath: game.avatarPath,
                fallbackSprite: GameData.skinById[game.selectedSkin]?.sprite ?? 'skin_ember',
                size: 44,
              ),
              const SizedBox(width: Dim.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(game.playerName, style: AppText.label.copyWith(fontSize: 13)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'LV ${game.playerLevel}',
                        style: AppText.eyebrow.copyWith(color: Palette.ember, letterSpacing: 1),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 64,
                        child: MeterBar(value: game.levelProgress, height: 3, color: Palette.ember),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        for (final kind in ResourceKind.values)
          Padding(
            padding: const EdgeInsets.only(left: Dim.s),
            child: ResourcePill(kind: kind, amount: game.resources[kind]!, dense: true),
          ),
      ],
    ).animate().fadeIn(duration: 320.ms).slideY(begin: -0.3, curve: Curves.easeOutCubic);
  }
}

class _BrandColumn extends StatelessWidget {
  const _BrandColumn({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final next = GameData.levelAt(game.furthestLevel);
    final region = GameData.regions[next.regionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(Art.wordmark, fit: BoxFit.contain)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -5, end: 5, duration: 3400.ms, curve: Curves.easeInOut),
          ),
        ),
        Text(
          AppConfig.tagline,
          style: AppText.body14.copyWith(fontSize: 12.5, color: Palette.textMuted),
        ),
        const SizedBox(height: Dim.m),
        GlassPanel(
          padding: const EdgeInsets.all(Dim.m),
          accent: region.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('UP NEXT', style: AppText.eyebrow.copyWith(color: region.accent)),
                  const Spacer(),
                  Text(
                    'LEVEL ${next.globalIndex + 1} / ${GameData.levelCount}',
                    style: AppText.eyebrow,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                next.isBoss ? next.name : '${region.name.split(' ').first} - ${next.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.subtitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: Dim.m),
              Row(
                children: [
                  Expanded(
                    child: LavaButton(
                      label: game.levelsCleared == 0 ? 'Start the descent' : 'Continue',
                      icon: Icons.play_arrow_rounded,
                      expand: true,
                      onPressed: () {
                        context.read<AudioService>().confirm();
                        goTo(context, LevelBriefScreen(level: next));
                      },
                    ),
                  ),
                  const SizedBox(width: Dim.s),
                  CircleAction(
                    icon: Icons.map_outlined,
                    tooltip: 'Region map',
                    size: 50,
                    onTap: () {
                      context.read<AudioService>().tap();
                      goTo(context, const CampaignMapScreen());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 380.ms).slideX(begin: -0.06, curve: Curves.easeOutCubic);
  }
}

class _DestinationGrid extends StatelessWidget {
  const _DestinationGrid({required this.unclaimedQuests});

  final int unclaimedQuests;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tiles = <_Destination>[
      _Destination(
        'Campaign',
        '${game.levelsCleared}/${GameData.levelCount} cleared',
        Icons.terrain_rounded,
        Palette.lava,
        () => const CampaignMapScreen(),
      ),
      _Destination(
        'Rush Mode',
        game.endlessBest > 0 ? 'Best ${formatCount(game.endlessBest)}' : 'Endless run',
        Icons.speed_rounded,
        Palette.crimson,
        () => const RushModeScreen(),
      ),
      _Destination(
        'Evolution Lab',
        '${game.upgradeLevelsBought}/64 levels',
        Icons.science_rounded,
        Palette.frost,
        () => const UpgradesScreen(),
      ),
      _Destination(
        'The Crucible',
        game.perkPoints > 0 ? '${game.perkPoints} points ready' : 'Perk board',
        Icons.auto_awesome_rounded,
        Palette.crimson,
        () => const CrucibleScreen(),
        badge: game.perkPoints > 0 ? '${game.perkPoints}' : null,
      ),
      _Destination(
        'Forge',
        'Convert resources',
        Icons.hardware_rounded,
        Palette.metal,
        () => const ForgeScreen(),
      ),
      _Destination(
        'Skins',
        '${game.unlockedSkins.length}/${GameData.skins.length} unlocked',
        Icons.palette_rounded,
        Palette.venom,
        () => const SkinsScreen(),
      ),
      _Destination(
        'Daily Tasks',
        unclaimedQuests > 0 ? '$unclaimedQuests ready to claim' : 'Resets each day',
        Icons.task_alt_rounded,
        Palette.success,
        () => const QuestsScreen(),
        badge: unclaimedQuests > 0 ? '$unclaimedQuests' : null,
      ),
      _Destination(
        'Collection',
        'Records, Bestiary & Codex',
        Icons.collections_bookmark_rounded,
        Palette.crystal,
        () => const CollectionHubScreen(),
      ),
      _Destination(
        'Profile',
        game.playerTitle,
        Icons.account_circle_rounded,
        Palette.lavaBright,
        () => const ProfileScreen(),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 700 ? 4 : 3;
        final rows = (tiles.length / columns).ceil();
        // Always divide the available height equally so nothing ever scrolls.
        final available = constraints.maxHeight - (rows - 1) * Dim.s;
        final tileHeight = (available / rows).floorToDouble().clamp(64.0, 200.0);

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: tileHeight,
            crossAxisSpacing: Dim.s,
            mainAxisSpacing: Dim.s,
          ),
          itemBuilder: (context, i) => _MenuTile(destination: tiles[i], index: i),
        );
      },
    );
  }
}

class _Destination {
  const _Destination(this.title, this.subtitle, this.icon, this.accent, this.build, {this.badge});

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget Function() build;
  final String? badge;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.destination, required this.index});

  final _Destination destination;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 7),
          radius: Dim.radiusM,
          accent: destination.accent,
          onTap: () {
            context.read<AudioService>().tap();
            goTo(context, destination.build());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: destination.accent.withValues(alpha: 0.16),
                      border: Border.all(color: destination.accent.withValues(alpha: 0.28)),
                    ),
                    child: Icon(destination.icon, size: 14, color: destination.accent),
                  ),
                  const Spacer(),
                  if (destination.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Palette.lava,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        destination.badge!,
                        style: AppText.eyebrow.copyWith(color: Colors.white, letterSpacing: 0, fontSize: 9),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                destination.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.subtitle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                destination.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body14.copyWith(fontSize: 10.5, color: Palette.textMuted),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (40 + index * 26).ms, duration: 300.ms)
        .scaleXY(begin: 0.94, curve: Curves.easeOutBack);
  }
}

class _UtilityRail extends StatelessWidget {
  const _UtilityRail({required this.audio});

  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Widget)>[
      (Icons.school_rounded, 'How to play', const TutorialScreen()),
      (Icons.settings_rounded, 'Settings', const SettingsScreen()),
      (Icons.info_outline_rounded, 'About', const AboutScreen()),
      (Icons.privacy_tip_outlined, 'Privacy Policy', const WebPageScreen(document: WebDocument.privacy)),
      (Icons.support_agent_rounded, 'Support', const WebPageScreen(document: WebDocument.support)),
    ];

    return Row(
      children: [
        Text(
          'v${AppConfig.version}  ${AppConfig.bundleId}',
          style: AppText.eyebrow.copyWith(letterSpacing: 0.8, fontSize: 9.5),
        ),
        const Spacer(),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: Dim.s),
            child: _RailButton(
              icon: item.$1,
              label: item.$2,
              onTap: () {
                audio.tap();
                goTo(context, item.$3);
              },
            ),
          ),
      ],
    ).animate().fadeIn(delay: 360.ms, duration: 320.ms);
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: Palette.surfaceRaised.withValues(alpha: 0.6),
          border: Border.all(color: Palette.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: Palette.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppText.label.copyWith(fontSize: 11, color: Palette.textSecondary)),
          ],
        ),
      ),
    );
  }
}
