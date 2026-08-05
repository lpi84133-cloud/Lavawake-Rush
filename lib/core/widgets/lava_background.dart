import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design/palette.dart';

/// Slow-moving volcanic backdrop shared by every menu screen.
///
/// Three cheap layers: a vertical wash, a set of drifting heat blooms, and a
/// sparse ember field. The clock is a [ValueNotifier] fed straight into the
/// painter's `repaint` channel, so animating it never rebuilds the widget tree.
class LavaBackground extends StatefulWidget {
  const LavaBackground({
    super.key,
    this.accent = Palette.lava,
    this.intensity = 1,
    this.embers = 22,
    this.child,
  });

  final Color accent;
  final double intensity;
  final int embers;
  final Widget? child;

  @override
  State<LavaBackground> createState() => _LavaBackgroundState();
}

class _LavaBackgroundState extends State<LavaBackground> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final List<_Ember> _embers;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _embers = List.generate(widget.embers, (_) => _Ember.random(rng));
    _ticker = createTicker((elapsed) => _clock.value = elapsed.inMilliseconds / 1000)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LavaPainter(
          clock: _clock,
          accent: widget.accent,
          intensity: widget.intensity,
          embers: _embers,
        ),
        child: widget.child,
      ),
    );
  }
}

class _Ember {
  _Ember({required this.x, required this.speed, required this.size, required this.phase, required this.drift});

  factory _Ember.random(math.Random rng) => _Ember(
    x: rng.nextDouble(),
    speed: 0.012 + rng.nextDouble() * 0.05,
    size: 0.8 + rng.nextDouble() * 2.4,
    phase: rng.nextDouble() * math.pi * 2,
    drift: (rng.nextDouble() - 0.5) * 0.06,
  );

  final double x;
  final double speed;
  final double size;
  final double phase;
  final double drift;
}

class _LavaPainter extends CustomPainter {
  _LavaPainter({
    required this.clock,
    required this.accent,
    required this.intensity,
    required this.embers,
  }) : super(repaint: clock);

  final ValueNotifier<double> clock;
  final Color accent;
  final double intensity;
  final List<_Ember> embers;

  // The full-screen base gradient never changes, so its shader is built once per
  // size instead of every frame.
  Shader? _bgShader;
  Size? _bgSize;

  @override
  void paint(Canvas canvas, Size size) {
    final time = clock.value;
    final rect = Offset.zero & size;

    if (_bgShader == null || _bgSize != size) {
      _bgSize = size;
      _bgShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: Palette.shellGradient,
      ).createShader(rect);
    }
    canvas.drawRect(rect, Paint()..shader = _bgShader);

    // Heat blooms: a few very large, very soft radial gradients that breathe.
    final blooms = [
      _Bloom(0.14, 0.86, 0.62, accent, 0.16),
      _Bloom(0.82, 0.08, 0.50, Palette.crimson, 0.12),
      _Bloom(0.52, 1.06, 0.78, Palette.deepLava, 0.20),
    ];
    for (var i = 0; i < blooms.length; i++) {
      final bloom = blooms[i];
      final pulse = 0.86 + 0.14 * math.sin(time * 0.35 + i * 1.9);
      final center = Offset(
        size.width * (bloom.x + 0.012 * math.sin(time * 0.18 + i)),
        size.height * (bloom.y + 0.010 * math.cos(time * 0.21 + i)),
      );
      final radius = size.shortestSide * bloom.radius * pulse;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              bloom.color.withValues(alpha: bloom.alpha * intensity),
              bloom.color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // A single faint crack line adds structure without visual noise.
    final crack = Path()..moveTo(0, size.height * 0.72);
    for (var x = 0.0; x <= size.width; x += size.width / 8) {
      final wobble = math.sin(x / size.width * 5 + time * 0.4) * size.height * 0.028;
      crack.lineTo(x, size.height * 0.72 + wobble);
    }
    canvas.drawPath(
      crack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = accent.withValues(alpha: 0.10 * intensity),
    );

    // Plain filled circles instead of blurred ones: a per-ember blur mask is
    // needlessly expensive for specks this small and this faint.
    final emberPaint = Paint();
    for (final ember in embers) {
      final progress = (time * ember.speed + ember.phase / 6) % 1.0;
      final y = size.height * (1.06 - progress * 1.12);
      final x = size.width * (ember.x + ember.drift * math.sin(time * 0.6 + ember.phase));
      final fade = math.sin(progress * math.pi).clamp(0.0, 1.0);
      emberPaint.color = Palette.ember.withValues(alpha: 0.5 * fade * intensity);
      canvas.drawCircle(Offset(x, y), ember.size, emberPaint);
    }
  }

  @override
  bool shouldRepaint(_LavaPainter old) => old.accent != accent || old.intensity != intensity;
}

class _Bloom {
  const _Bloom(this.x, this.y, this.radius, this.color, this.alpha);

  final double x;
  final double y;
  final double radius;
  final Color color;
  final double alpha;
}
