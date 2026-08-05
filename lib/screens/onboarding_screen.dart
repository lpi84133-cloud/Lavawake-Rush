import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../core/app_config.dart';
import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/avatar_picker_sheet.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/lava_background.dart';
import '../data/asset_catalog.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'main_menu_screen.dart';

/// First-run flow: introduce the premise, collect a name and avatar, then hand
/// over to the hub. Laid out as a full-bleed horizontal pager so it reads
/// differently from every other screen in the game.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  final TextEditingController _name = TextEditingController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _name.text = context.read<GameState>().playerName;
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    final audio = context.read<AudioService>();
    if (_index < 2) {
      audio.tap();
      _pages.nextPage(duration: Dim.normal, curve: Curves.easeOutCubic);
      return;
    }
    final game = context.read<GameState>();
    game.setProfile(name: _name.text);
    game.completeOnboarding();
    audio.confirm();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Dim.slow,
        pageBuilder: (_, _, _) => const MainMenuScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();

    return Scaffold(
      backgroundColor: Palette.ink,
      body: LavaBackground(
        embers: 30,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _WelcomePage(),
                    _IdentityPage(name: _name, game: game),
                    const _PrimerPage(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Dim.xl, 0, Dim.xl, Dim.m),
                child: Row(
                  children: [
                    SmoothPageIndicator(
                      controller: _pages,
                      count: 3,
                      effect: const ExpandingDotsEffect(
                        dotHeight: 5,
                        dotWidth: 5,
                        expansionFactor: 5,
                        spacing: 6,
                        activeDotColor: Palette.lava,
                        dotColor: Palette.hairlineStrong,
                      ),
                    ),
                    const Spacer(),
                    if (_index < 2)
                      LavaButton(
                        label: 'Skip',
                        tone: ButtonTone.ghost,
                        compact: true,
                        onPressed: () {
                          context.read<AudioService>().tap();
                          _pages.animateToPage(2, duration: Dim.normal, curve: Curves.easeOutCubic);
                        },
                      ),
                    const SizedBox(width: Dim.m),
                    LavaButton(
                      label: _index < 2 ? 'Continue' : 'Enter the volcano',
                      icon: _index < 2 ? Icons.arrow_forward_rounded : Icons.play_arrow_rounded,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dim.xl, vertical: Dim.m),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WELCOME', style: AppText.eyebrow.copyWith(color: Palette.lava)),
                const SizedBox(height: Dim.s),
                Text(AppConfig.appName, style: AppText.hero.copyWith(fontSize: 38)),
                const SizedBox(height: Dim.m),
                Text(
                  'You are a living flow of lava, woken in the deep of an ancient volcano. You have no '
                  'weapons. You melt what stands in your way and take its material for yourself.',
                  style: AppText.body16,
                ),
                const SizedBox(height: Dim.l),
                Wrap(
                  spacing: Dim.s,
                  runSpacing: Dim.s,
                  children: [
                    for (final essence in Essence.values)
                      Chip2(label: essence.label, icon: essence.icon, color: essence.color, selected: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Dim.xl),
          Expanded(
            flex: 4,
            child: Center(
              child: Image.asset(Art.wordmark, fit: BoxFit.contain)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.97, end: 1.03, duration: 2600.ms, curve: Curves.easeInOut),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 420.ms);
  }
}

class _IdentityPage extends StatelessWidget {
  const _IdentityPage({required this.name, required this.game});

  final TextEditingController name;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dim.xl, vertical: Dim.m),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: GlassPanel(
            padding: const EdgeInsets.all(Dim.l),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerAvatar(
                      imagePath: game.avatarPath,
                      fallbackSprite: GameData.skinById[game.selectedSkin]?.sprite ?? 'skin_ember',
                      size: 108,
                    ),
                    const SizedBox(height: Dim.m),
                    LavaButton(
                      label: game.avatarPath == null ? 'Add photo' : 'Change',
                      icon: Icons.add_a_photo_rounded,
                      tone: ButtonTone.ghost,
                      compact: true,
                      onPressed: () => showAvatarPicker(context),
                    ),
                  ],
                ),
                const SizedBox(width: Dim.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('WHO IS FLOWING', style: AppText.eyebrow.copyWith(color: Palette.ember)),
                      const SizedBox(height: Dim.s),
                      Text('Name your flow', style: AppText.title),
                      const SizedBox(height: 6),
                      Text(
                        'This is the name on your leaderboard entry. Everything is stored on this device '
                        'and never leaves it.',
                        style: AppText.body14,
                      ),
                      const SizedBox(height: Dim.l),
                      _NameField(controller: name),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 16,
      textCapitalization: TextCapitalization.words,
      style: AppText.subtitle.copyWith(fontSize: 19),
      cursorColor: Palette.lava,
      decoration: InputDecoration(
        counterStyle: AppText.eyebrow,
        hintText: 'Lavawake',
        hintStyle: AppText.subtitle.copyWith(fontSize: 19, color: Palette.textMuted),
        filled: true,
        fillColor: Palette.surfaceHigh.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: Dim.m),
        enabledBorder: OutlineInputBorder(
          borderRadius: Dim.brM,
          borderSide: const BorderSide(color: Palette.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Dim.brM,
          borderSide: BorderSide(color: Palette.lava.withValues(alpha: 0.7), width: 1.4),
        ),
      ),
    );
  }
}

class _PrimerPage extends StatelessWidget {
  const _PrimerPage();

  static const List<(IconData, String, String)> _beats = [
    (Icons.thermostat_rounded, 'Stay hot', 'Heat decides what you can melt. Below the armour rating you bounce off.'),
    (Icons.blur_circular_rounded, 'Absorb', 'Hold contact to melt a creature down and take its material.'),
    (Icons.merge_type_rounded, 'Combine', 'Two materials at once forge a hybrid form with its own trade-offs.'),
    (Icons.bolt_rounded, 'Rush', 'Surge, erupt and volley to punch through what will not melt fast enough.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dim.xl, vertical: Dim.m),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE LOOP', style: AppText.eyebrow.copyWith(color: Palette.lava)),
          const SizedBox(height: Dim.s),
          Text('Four things to remember', style: AppText.title),
          const SizedBox(height: Dim.l),
          Row(
            children: [
              for (var i = 0; i < _beats.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _beats.length - 1 ? 0 : Dim.m),
                    child:
                        FlatPanel(
                              padding: const EdgeInsets.all(Dim.m),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Palette.lava.withValues(alpha: 0.14),
                                    ),
                                    child: Icon(_beats[i].$1, size: 16, color: Palette.lava),
                                  ),
                                  const SizedBox(height: Dim.m),
                                  Text(_beats[i].$2, style: AppText.subtitle.copyWith(fontSize: 15)),
                                  const SizedBox(height: 6),
                                  Text(_beats[i].$3, style: AppText.body14.copyWith(fontSize: 12.5)),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(delay: (i * 90).ms, duration: 340.ms)
                            .slideY(begin: 0.12, curve: Curves.easeOutCubic),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
