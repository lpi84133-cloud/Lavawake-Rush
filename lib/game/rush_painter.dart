import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/design/palette.dart';
import '../data/asset_catalog.dart';
import '../data/models.dart';
import 'rush_engine.dart';
import 'sprite_cache.dart';

/// Draws the whole run: parallax backdrop, entities, the player flow, particles
/// and floating score text. Reads engine state directly and repaints from the
/// engine's frame notifier, so no widget rebuilds happen during play.
class RushPainter extends CustomPainter {
  RushPainter({required this.engine, required this.background, required this.playerTint})
    : super(repaint: engine.frame);

  final RushEngine engine;
  final ui.Image? background;
  final Color playerTint;

  static final Paint _plain = Paint()..filterQuality = FilterQuality.medium;

  // Full-screen gradient shaders depend only on the viewport size, so they are
  // built once and reused every frame rather than rebuilt 60 times a second.
  Shader? _sideShader;
  Shader? _vignetteShader;
  Size? _shaderSize;

  void _ensureShaders(Size size) {
    if (_shaderSize == size && _sideShader != null) return;
    _shaderSize = size;
    final rect = Offset.zero & size;
    _sideShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Palette.voidBlack.withValues(alpha: 0.55),
        Palette.voidBlack.withValues(alpha: 0.10),
        Palette.voidBlack.withValues(alpha: 0.40),
      ],
      stops: const [0, 0.45, 1],
    ).createShader(rect);
    _vignetteShader = RadialGradient(
      radius: 0.92,
      colors: [Colors.transparent, Palette.voidBlack.withValues(alpha: 0.55)],
      stops: const [0.62, 1],
    ).createShader(rect);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _ensureShaders(size);
    final scale = size.height / kWorldHeight;
    canvas.save();

    if (engine.shake > 0.2) {
      final shake = engine.shake;
      canvas.translate(
        math.sin(engine.elapsed * 63) * shake,
        math.cos(engine.elapsed * 71) * shake * 0.7,
      );
    }

    _paintBackdrop(canvas, size);
    canvas.save();
    canvas.scale(scale);

    _paintColdSeams(canvas);
    _paintEntities(canvas);
    _paintParticles(canvas);
    _paintPlayer(canvas);
    _paintFloaters(canvas);

    canvas.restore();
    canvas.restore();

    if (engine.hitFlash > 0.01) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Palette.danger.withValues(alpha: 0.22 * engine.hitFlash),
      );
    }

    _paintVignette(canvas, size);
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Palette.voidBlack);

    final image = background;
    if (image == null) return;

    // Static cover-fill: scale the image so it fills the viewport while
    // maintaining aspect ratio (cover). No scrolling = no visible seams.
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final scaleX = size.width / imgW;
    final scaleY = size.height / imgH;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final drawW = imgW * scale;
    final drawH = imgH * scale;
    final dstLeft = (size.width - drawW) / 2;
    final dstTop = (size.height - drawH) / 2;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(dstLeft, dstTop, drawW, drawH),
      Paint()..filterQuality = FilterQuality.low,
    );

    canvas.drawRect(rect, Paint()..shader = _sideShader);
  }

  void _paintColdSeams(Canvas canvas) {
    for (final entity in engine.entities) {
      if (entity.kind != EntityKind.coldSeam || entity.dead) continue;
      final rect = Rect.fromLTWH(entity.x, 0, entity.width, kWorldHeight);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Palette.frost.withValues(alpha: 0.05),
              Palette.frost.withValues(alpha: 0.24),
              Palette.frost.withValues(alpha: 0.05),
            ],
          ).createShader(rect),
      );
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.frost.withValues(alpha: 0.42);
      canvas.drawLine(Offset(entity.x, 0), Offset(entity.x, kWorldHeight), edge);
      canvas.drawLine(
        Offset(entity.x + entity.width, 0),
        Offset(entity.x + entity.width, kWorldHeight),
        edge,
      );
    }
  }

  void _paintEntities(Canvas canvas) {
    for (final entity in engine.entities) {
      if (entity.dead || entity.kind == EntityKind.coldSeam) continue;
      final image = SpriteCache.instance.get(Art.sprite(entity.sprite));
      final tint = entity.essence?.color ?? Palette.ember;

      if (entity.kind == EntityKind.pickup || entity.kind == EntityKind.vent) {
        _glow(canvas, entity.x, entity.y, entity.radius * 1.5, tint, 0.24);
      } else if (entity.kind == EntityKind.boss) {
        _glow(canvas, entity.x, entity.y, entity.radius * 1.5, tint, 0.34);
      }

      if (image != null) {
        final aspect = image.width / image.height;
        final height = entity.radius * 2.35;
        final width = height * aspect;
        final dst = Rect.fromCenter(
          center: Offset(entity.x, entity.y),
          width: width,
          height: height,
        );
        final paint = Paint()..filterQuality = FilterQuality.medium;
        if (entity.flash > 0.02) {
          paint.colorFilter = ColorFilter.mode(
            Colors.white.withValues(alpha: 0.55 * entity.flash),
            BlendMode.srcATop,
          );
        }
        if (entity.kind == EntityKind.enemy && entity.meltRatio > 0) {
          paint.color = Colors.white.withValues(alpha: 1 - entity.meltRatio * 0.45);
        }
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          dst,
          paint,
        );
      } else {
        canvas.drawCircle(
          Offset(entity.x, entity.y),
          entity.radius,
          Paint()..color = tint.withValues(alpha: 0.55),
        );
      }

      if (entity.kind == EntityKind.enemy && entity.meltRatio > 0.02) {
        _meltRing(canvas, entity);
      }
      if (entity.kind == EntityKind.boss) {
        _bossBar(canvas, entity);
      }
    }
  }

  void _meltRing(Canvas canvas, Entity entity) {
    final rect = Rect.fromCircle(
      center: Offset(entity.x, entity.y),
      radius: entity.radius * 1.16,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * entity.meltRatio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = Palette.lavaBright,
    );
  }

  void _bossBar(Canvas canvas, Entity entity) {
    final width = entity.radius * 2.2;
    final top = entity.y - entity.radius * 1.45;
    final left = entity.x - width / 2;
    final track = RRect.fromLTRBR(left, top, left + width, top + 16, const Radius.circular(8));
    canvas.drawRRect(track, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(
      RRect.fromLTRBR(left, top, left + width * entity.hpRatio, top + 16, const Radius.circular(8)),
      Paint()..color = Palette.crimson,
    );
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _paintParticles(Canvas canvas) {
    // No per-particle blur mask: with up to a few hundred live particles that is
    // the single most expensive thing the run can draw. Plain additive-looking
    // circles read the same in motion at a fraction of the cost.
    final paint = Paint();
    for (final particle in engine.particles) {
      final fade = 1 - particle.t;
      paint.color = Color.lerp(
        Palette.ember,
        playerTint,
        particle.hue,
      )!.withValues(alpha: 0.66 * fade);
      canvas.drawCircle(Offset(particle.x, particle.y), particle.size * (0.4 + fade * 0.8), paint);
    }
  }

  void _paintPlayer(Canvas canvas) {
    final radius = engine.playerRadius;
    final centre = Offset(engine.playerX, engine.playerY);
    final pulse = 1 + math.sin(engine.elapsed * 7) * 0.02;

    _glow(canvas, centre.dx, centre.dy, radius * 2.1, playerTint, engine.surging ? 0.55 : 0.34);

    if (engine.surging) {
      final trail = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [playerTint.withValues(alpha: 0.5), playerTint.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(centre.dx - radius * 5, centre.dy - radius, radius * 5, radius * 2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centre.dx - radius * 5, centre.dy - radius * 0.62, radius * 5, radius * 1.24),
          Radius.circular(radius),
        ),
        trail,
      );
    }

    final image = SpriteCache.instance.get(Art.sprite(engine.playerSprite));
    if (image != null) {
      final aspect = image.width / image.height;
      final height = radius * 2.5 * pulse;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: centre, width: height * aspect, height: height),
        _plain,
      );
    } else {
      canvas.drawCircle(centre, radius, Paint()..color = playerTint);
    }

    // Heat ring doubles as an at-a-glance read on whether armour can be melted.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius * 1.28),
      -math.pi / 2,
      math.pi * 2 * engine.heatRatio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(Palette.frost, Palette.lavaBright, engine.heatRatio)!.withValues(alpha: 0.85),
    );

    // Graze aura: a faint pulsing ring when an enemy is inside graze range.
    // Gives the player a readable cue to push even closer for the bonus.
    if (!engine.surging) {
      for (final entity in engine.entities) {
        if (entity.dead || entity.grazed) continue;
        if (entity.kind != EntityKind.enemy) continue;
        final edx = entity.x - engine.playerX;
        final edy = entity.y - engine.playerY;
        final baseReach = entity.radius + radius;
        final grazeReach = baseReach * 1.72;
        final d2 = edx * edx + edy * edy;
        if (d2 > baseReach * baseReach && d2 <= grazeReach * grazeReach) {
          final nearness = 1 - (math.sqrt(d2) - baseReach) / (grazeReach - baseReach);
          final pulse2 = 0.5 + 0.5 * math.sin(engine.elapsed * 14);
          canvas.drawCircle(
            centre,
            radius * (1.55 + pulse2 * 0.18),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFFFFE650).withValues(alpha: nearness * 0.55 * pulse2),
          );
          break;
        }
      }
    }
  }

  void _paintFloaters(Canvas canvas) {
    for (final floater in engine.floaters) {
      final fade = (1 - floater.age / 0.9).clamp(0.0, 1.0);
      final painter = TextPainter(
        text: TextSpan(
          text: floater.text,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: Color(floater.tint).withValues(alpha: fade),
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(floater.x - painter.width / 2, floater.y - painter.height / 2));
    }
  }

  void _glow(Canvas canvas, double x, double y, double radius, Color color, double alpha) {
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius)),
    );
  }

  void _paintVignette(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = _vignetteShader);
  }

  @override
  bool shouldRepaint(RushPainter old) =>
      old.background != background || old.playerTint != playerTint || old.engine != engine;
}
