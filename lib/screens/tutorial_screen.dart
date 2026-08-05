import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';

class _Lesson {
  const _Lesson({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    required this.points,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final List<String> points;
}

const List<_Lesson> _lessons = [
  _Lesson(
    title: 'Steer the flow',
    body: 'You are a living river of lava. Drag anywhere to move; there is no run button, the channel '
        'carries you forward on its own.',
    icon: Icons.touch_app_rounded,
    accent: Palette.lava,
    points: [
      'Drag to move freely, or switch to three lanes in settings.',
      'Bigger mass steers slower but smashes heavier things.',
    ],
  ),
  _Lesson(
    title: 'Heat is everything',
    body: 'Hold contact to melt what you touch. But you can only melt armour while your heat is above it '
        '- run cold and you bounce off and take damage.',
    icon: Icons.thermostat_rounded,
    accent: Palette.ember,
    points: [
      'Absorbing fire creatures and hitting vents restores heat.',
      'Cold seams bleed heat fast; cross them straight and quick.',
    ],
  ),
  _Lesson(
    title: 'Fuse a form',
    body: 'Every creature you eat leaves its material behind. Hold two materials at once and the flow fuses '
        'into a hybrid form with its own strength and weakness.',
    icon: Icons.merge_type_rounded,
    accent: Palette.crystal,
    points: [
      'Fire + Crystal makes Prismfire and unlocks ranged shards.',
      'Materials decay over time, so keep feeding to hold a form.',
    ],
  ),
  _Lesson(
    title: 'Abilities and Overdrive',
    body: 'Surge for a burst of speed and invulnerability, Erupt to clear a crowd, Volley to fire shards. '
        'Chain absorbs to trigger Overdrive for bonus score and melt.',
    icon: Icons.bolt_rounded,
    accent: Palette.venom,
    points: [
      'Surge punches through an elite that is too armoured to melt.',
      'Keep your combo alive - it feeds Overdrive and your score.',
    ],
  ),
  _Lesson(
    title: 'Shape your run',
    body: 'Vent chambers stop the run to offer mutations - each a real trade. Forks split the route, and if '
        'you fall into danger the mountain offers a risky pact.',
    icon: Icons.science_rounded,
    accent: Palette.crimson,
    points: [
      'Mutations stack all run; reroll a chamber if nothing fits.',
      'Level up to earn perk points and pre-shape runs in the Crucible.',
    ],
  ),
];

/// How to play. A swipeable primer of five lessons, each a full illustrated
/// panel rather than a dense list.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _lessons.length - 1;

    return ScreenShell(
      title: 'How to Play',
      eyebrow: 'Lesson ${_page + 1} of ${_lessons.length}',
      accent: _lessons[_page].accent,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _lessons.length,
              onPageChanged: (i) {
                context.read<AudioService>().tap();
                setState(() => _page = i);
              },
              itemBuilder: (context, index) => _LessonView(lesson: _lessons[index]),
            ),
          ),
          const SizedBox(height: Dim.m),
          Row(
            children: [
              SmoothPageIndicator(
                controller: _controller,
                count: _lessons.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  expansionFactor: 3,
                  spacing: 5,
                  activeDotColor: _lessons[_page].accent,
                  dotColor: Palette.hairlineStrong,
                ),
              ),
              const Spacer(),
              LavaButton(
                label: last ? 'Got it' : 'Next',
                icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                accent: _lessons[_page].accent,
                onPressed: () {
                  context.read<AudioService>().confirm();
                  if (last) {
                    context.read<GameState>().markTutorialSeen();
                    Navigator.of(context).maybePop();
                  } else {
                    _controller.nextPage(duration: Dim.normal, curve: Curves.easeOutCubic);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonView extends StatelessWidget {
  const _LessonView({required this.lesson});

  final _Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.l),
      accent: lesson.accent,
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [lesson.accent.withValues(alpha: 0.3), lesson.accent.withValues(alpha: 0.04)],
                  ),
                  border: Border.all(color: lesson.accent.withValues(alpha: 0.4)),
                ),
                child: Icon(lesson.icon, size: 60, color: lesson.accent),
              ).animate(key: ValueKey(lesson.title)).fadeIn(duration: 300.ms).scaleXY(begin: 0.85, curve: Curves.easeOutBack),
            ),
          ),
          const SizedBox(width: Dim.l),
          Expanded(
            flex: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(lesson.title, style: AppText.hero.copyWith(fontSize: 32, color: lesson.accent)),
                const SizedBox(height: Dim.s),
                Text(lesson.body, style: AppText.body16),
                const SizedBox(height: Dim.m),
                for (final point in lesson.points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.chevron_right_rounded, size: 16, color: lesson.accent),
                        const SizedBox(width: 5),
                        Expanded(child: Text(point, style: AppText.body14.copyWith(fontSize: 12.5))),
                      ],
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
