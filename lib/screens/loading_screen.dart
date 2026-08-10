import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../conduit/flow_router.dart';
import '../conduit/pages/basalt_portal.dart';
import '../conduit/pages/dead_air_page.dart';
import '../conduit/pages/ember_consent_page.dart';
import '../core/app_config.dart';
import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../data/asset_catalog.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../game/sprite_cache.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'main_menu_screen.dart';
import 'onboarding_screen.dart';

/// Boot screen shown on first launch.
///
/// It is the only screen allowed in portrait: the artwork exists in both
/// orientations, and the rest of the game is landscape-only. The bar starts
/// completely empty, advances in visible stages as real work finishes, and is
/// guaranteed to read exactly 100% before the app navigates away.
///
/// The first third of the bar covers deciding where this launch goes; the
/// game's own warm-up only runs once that answer is "the game", so nothing
/// heavy is paid for on a launch that never opens it.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  /// Displayed fill, eased toward [_target] so the bar never jumps.
  double _shown = 0;
  double _target = 0;
  bool _finished = false;
  bool _navigated = false;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final DateTime _started = DateTime.now();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (_shown >= _target) return;
    // Ease toward the target but keep a floor on the speed, so the bar is always
    // visibly moving instead of appearing stuck just short of a stage boundary.
    final eased = (_target - _shown) * dt * 4.2;
    final minimum = dt * 0.035;
    final next = (_shown + (eased > minimum ? eased : minimum)).clamp(0.0, _target);
    setState(() => _shown = next);
  }

  Future<void> _boot() async {
    final destination = await _route();
    if (!mounted) return;

    if (destination.offline) {
      await _goOffline();
      return;
    }

    final address = destination.address;
    if (address != null) {
      await _finishBar();
      await _openPortal(address, fromNotification: destination.fromNotification);
      return;
    }

    await _warmGame();
  }

  /// A dead end that takes several seconds to admit it reads as a hang, so the
  /// bar is abandoned where it stands. The artwork is warmed first — handing
  /// over to an unloaded image paints a black frame that looks like a crash.
  Future<void> _goOffline() async {
    final landscape = MediaQuery.sizeOf(context).width >= MediaQuery.sizeOf(context).height;
    try {
      await precacheImage(
        AssetImage(landscape ? DeadAirPage.landscapeArt : DeadAirPage.portraitArt),
        context,
      );
    } on Object {
      // Better a late-loading image than no way out of this screen.
    }

    final seen = DateTime.now().difference(_started);
    const floor = Duration(milliseconds: 700);
    if (seen < floor) await Future<void>.delayed(floor - seen);
    if (!mounted) return;

    _leaveFor((_) => DeadAirPage(retryBuilder: (_) => const LoadingScreen()));
  }

  /// Runs the routing pipeline while the bar covers its first third. The bar
  /// eases toward the target continuously, so it keeps moving even though this
  /// step reports no intermediate progress of its own.
  Future<DriftDestination> _route() async {
    _setTarget(0.34);
    try {
      return await flowRouter.decide();
    } on Object {
      // An unexpected failure here must still land the user somewhere.
      return const DriftDestination.native();
    }
  }

  Future<void> _openPortal(String address, {required bool fromNotification}) async {
    final allowed = await flowRouter.vault.inviteAllowed();
    final undecided = await flowRouter.signals.undecided();
    if (!mounted) return;

    Widget portal(BuildContext _) => BasaltPortal(
      address: address,
      fromNotification: fromNotification,
      rebootBuilder: (_) => const LoadingScreen(),
    );

    if (!allowed || !undecided) {
      _leaveFor(portal);
      return;
    }

    final landscape = MediaQuery.sizeOf(context).width >= MediaQuery.sizeOf(context).height;
    try {
      await precacheImage(
        AssetImage(
          landscape ? EmberConsentPage.landscapeArt : EmberConsentPage.portraitArt,
        ),
        context,
      );
    } on Object {
      // Not worth skipping the invitation over.
    }
    if (!mounted) return;

    _leaveFor(
      (_) => EmberConsentPage(
        nextBuilder: portal,
        onAccept: () async {
          final granted = await flowRouter.signals.askPermission();
          if (!granted) await flowRouter.vault.markInviteRefused();
        },
        onSkip: flowRouter.vault.snoozeInvite,
      ),
    );
  }

  void _leaveFor(WidgetBuilder builder) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Closes the bar on a full hundred and holds it there for a beat, so the
  /// number and the fill land together before anything moves.
  Future<void> _finishBar() async {
    _setTarget(1);
    final start = DateTime.now();
    while (_shown < 0.999 && DateTime.now().difference(start).inMilliseconds < 900) {
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
    if (!mounted) return;
    setState(() {
      _shown = 1;
      _target = 1;
      _finished = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 385));
  }

  Future<void> _warmGame() async {
    final deadline = DateTime.now().add(AppConfig.maxBootDuration);
    final game = context.read<GameState>();
    final audio = context.read<AudioService>();

    Duration budget(Duration wanted) {
      final left = deadline.difference(DateTime.now());
      return left < wanted ? (left.isNegative ? Duration.zero : left) : wanted;
    }

    /// Runs one stage: performs its work with a hard time budget, then holds the
    /// bar long enough for the step to be perceptible.
    Future<void> stage(double end, Duration maxWork, Duration dwell, Future<void> Function() work) async {
      _target = end;
      try {
        await work().timeout(budget(maxWork));
      } on Object {
        // A slow or failing warm-up must never block the boot sequence.
      }
      final wait = budget(dwell);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (!mounted) return;
      setState(() {});
    }

    await stage(0.44, const Duration(milliseconds: 900), const Duration(milliseconds: 320), () async {
      game.refreshDailyQuestsIfNeeded();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });

    await stage(0.55, const Duration(milliseconds: 1400), const Duration(milliseconds: 260), () async {
      await audio.warmUp();
      unawaited(audio.loop(Sfx.loadingLoop));
    });

    await stage(0.71, const Duration(milliseconds: 2600), const Duration(milliseconds: 220), () async {
      await SpriteCache.instance.loadAll(
        [
          ...Art.playerStages.map(Art.sprite),
          ...GameData.skins.map((s) => Art.sprite(s.sprite)),
          ...ResourceKind.values.map((r) => Art.sprite(r.sprite)),
        ],
        targetHeight: 320,
        onProgress: (p) => _setTarget(0.55 + p * 0.16),
      );
    });

    await stage(0.87, const Duration(milliseconds: 3000), const Duration(milliseconds: 200), () async {
      await SpriteCache.instance.loadAll(
        [
          ...GameData.enemies.map((e) => Art.sprite(e.sprite)),
          ...Art.obstacles.map(Art.sprite),
        ],
        targetHeight: 320,
        onProgress: (p) => _setTarget(0.71 + p * 0.16),
      );
    });

    await stage(0.95, const Duration(milliseconds: 2200), const Duration(milliseconds: 180), () async {
      await SpriteCache.instance.loadAll(
        Art.effects.map(Art.sprite),
        targetHeight: 260,
        onProgress: (p) => _setTarget(0.87 + p * 0.08),
      );
      if (!mounted) return;
      await precacheImage(const AssetImage(Art.wordmark), context);
    });

    await _finishBar();
    if (!mounted) return;
    await _enterGame();
  }

  void _setTarget(double value) {
    if (!mounted) return;
    if (value > _target) setState(() => _target = value.clamp(0.0, 1.0));
  }

  Future<void> _enterGame() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    // Everything past the loader is landscape only.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;

    final game = context.read<GameState>();
    final audio = context.read<AudioService>();
    await audio.stopLoop();
    unawaited(audio.loop(Sfx.menuAmbient));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 620),
        pageBuilder: (_, _, _) =>
            game.onboardingDone ? const MainMenuScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width >= size.height;
    final percent = _finished ? 100 : (_shown * 100).floor().clamp(0, 99);

    return Scaffold(
      backgroundColor: Palette.voidBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            landscape ? Art.loadingLandscape : Art.loadingPortrait,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
          ),
          // A soft scrim keeps the label and digits legible over bright artwork.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Palette.voidBlack.withValues(alpha: landscape ? 0.30 : 0.16),
                  Palette.voidBlack.withValues(alpha: landscape ? 0.86 : 0.72),
                ],
                stops: const [0.35, 0.68, 1],
              ),
            ),
          ),
          SafeArea(
            child: landscape
                ? _LandscapeLoader(progress: _shown, percent: percent, width: size.width)
                : _PortraitLoader(progress: _shown, percent: percent, width: size.width),
          ),
        ],
      ),
    );
  }
}

/// Landscape layout: a narrower bar pinned to the bottom of the screen with the
/// label above it and the percentage below it, all centred.
class _LandscapeLoader extends StatelessWidget {
  const _LandscapeLoader({required this.progress, required this.percent, required this.width});

  final double progress;
  final int percent;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: SizedBox(
          width: (width * 0.44).clamp(220.0, 460.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _LoadingLabel(fontSize: 13),
              const SizedBox(height: 8),
              _ProgressTrack(progress: progress, height: 7),
              const SizedBox(height: 7),
              _PercentReadout(percent: percent, fontSize: 15),
            ],
          ),
        ),
      ),
    );
  }
}

/// Portrait layout: a wider bar sitting in the lower third of the artwork.
class _PortraitLoader extends StatelessWidget {
  const _PortraitLoader({required this.progress, required this.percent, required this.width});

  final double progress;
  final int percent;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.74),
      child: SizedBox(
        width: (width * 0.74).clamp(240.0, 520.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LoadingLabel(fontSize: 16),
            const SizedBox(height: 14),
            _ProgressTrack(progress: progress, height: 11),
            const SizedBox(height: 12),
            _PercentReadout(percent: percent, fontSize: 20),
          ],
        ),
      ),
    );
  }
}

/// "Loading" with dots that cycle through one, two and three.
class _LoadingLabel extends StatefulWidget {
  const _LoadingLabel({required this.fontSize});

  final double fontSize;

  @override
  State<_LoadingLabel> createState() => _LoadingLabelState();
}

class _LoadingLabelState extends State<_LoadingLabel> {
  late final Timer _timer;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (mounted) setState(() => _dots = _dots % 3 + 1);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Loading'),
          // The invisible remainder keeps the label from shifting as dots cycle.
          TextSpan(text: '.' * _dots),
          TextSpan(text: '.' * (3 - _dots), style: const TextStyle(color: Colors.transparent)),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppText.display,
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.2,
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2))],
      ),
    );
  }
}

class _PercentReadout extends StatelessWidget {
  const _PercentReadout({required this.percent, required this.fontSize});

  final int percent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$percent%',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppText.display,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2))],
      ),
    );
  }
}

/// The bar itself: empty at rest, filling strictly left to right.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height);
    final fill = progress.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final fillWidth = constraints.maxWidth * fill;
            return Stack(
              children: [
                if (fillWidth > 0)
                  Container(
                    width: fillWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: const LinearGradient(colors: Palette.lavaGradient),
                    ),
                  ),
                if (fillWidth > 0)
                  Positioned(
                    left: fillWidth - height * 1.2,
                    top: 0,
                    bottom: 0,
                    width: height * 2.4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        boxShadow: [
                          BoxShadow(
                            color: Palette.lava.withValues(alpha: 0.9),
                            blurRadius: height * 2.5,
                            spreadRadius: height * 0.4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
