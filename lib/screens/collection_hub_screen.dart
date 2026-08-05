import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/nav.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/game_data.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'achievements_screen.dart';
import 'bestiary_screen.dart';
import 'forms_codex_screen.dart';
import 'leaderboard_screen.dart';
import 'statistics_screen.dart';

/// Collection & Records hub.
///
/// A single tile in the main menu that opens this screen, which then provides
/// five sub-destinations. This keeps the main menu from looking like a
/// directory listing while still giving everything its own space.
class CollectionHubScreen extends StatelessWidget {
  const CollectionHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final audio = context.read<AudioService>();

    final sections = <_Section>[
      _Section(
        title: 'Achievements',
        subtitle: '${game.unlockedAchievements.length}/${GameData.achievements.length} unlocked',
        icon: Icons.emoji_events_rounded,
        accent: Palette.warning,
        destination: () => const AchievementsScreen(),
      ),
      _Section(
        title: 'Bestiary',
        subtitle: '${game.collectionCount}/${GameData.enemies.length} recorded',
        icon: Icons.pets_rounded,
        accent: Palette.crystal,
        destination: () => const BestiaryScreen(),
      ),
      _Section(
        title: 'Forms Codex',
        subtitle: '${GameData.forms.length} fusion recipes',
        icon: Icons.merge_type_rounded,
        accent: Palette.ember,
        destination: () => const FormsCodexScreen(),
      ),
      _Section(
        title: 'Statistics',
        subtitle: '${game.stats.runs} runs logged',
        icon: Icons.insights_rounded,
        accent: Palette.frost,
        destination: () => const StatisticsScreen(),
      ),
      _Section(
        title: 'Leaderboard',
        subtitle: 'Local standings',
        icon: Icons.leaderboard_rounded,
        accent: Palette.stone,
        destination: () => const LeaderboardScreen(),
      ),
    ];

    return ScreenShell(
      title: 'Collection',
      eyebrow: 'Records & knowledge',
      accent: Palette.crystal,
      body: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 120,
          crossAxisSpacing: Dim.m,
          mainAxisSpacing: Dim.m,
        ),
        itemCount: sections.length,
        itemBuilder: (context, i) => _SectionCard(
          section: sections[i],
          index: i,
          onTap: () {
            audio.tap();
            goTo(context, sections[i].destination());
          },
        ),
      ),
    );
  }
}

class _Section {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.destination,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget Function() destination;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.index, required this.onTap});

  final _Section section;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
          accent: section.accent,
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: Dim.brS,
                  color: section.accent.withValues(alpha: 0.16),
                  border: Border.all(color: section.accent.withValues(alpha: 0.35)),
                ),
                child: Icon(section.icon, size: 24, color: section.accent),
              ),
              const SizedBox(width: Dim.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      section.title,
                      style: AppText.subtitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle,
                      maxLines: 2,
                      style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Palette.textMuted),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (index * 55).ms, duration: 280.ms)
        .slideX(begin: 0.06, curve: Curves.easeOutCubic);
  }
}
