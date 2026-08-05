import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../../data/models.dart';
import '../design/app_theme.dart';
import '../design/palette.dart';
import 'glass_panel.dart';

/// A sliced sprite with an optional coloured glow behind it.
class SpriteTile extends StatelessWidget {
  const SpriteTile({
    super.key,
    required this.name,
    this.size = 64,
    this.glow,
    this.glowStrength = 0.30,
    this.locked = false,
    this.alignment = Alignment.center,
  });

  final String name;
  final double size;
  final Color? glow;
  final double glowStrength;
  final bool locked;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      Art.sprite(name),
      width: size,
      height: size,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
    );

    if (locked) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.24, 0.24, 0.24, 0, 6, //
          0.24, 0.24, 0.24, 0, 6, //
          0.24, 0.24, 0.24, 0, 10, //
          0, 0, 0, 1, 0, //
        ]),
        child: image,
      );
    }

    if (glow == null) return image;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: glow!.withValues(alpha: glowStrength), blurRadius: size * 0.42, spreadRadius: -size * 0.1),
        ],
      ),
      child: image,
    );
  }
}

/// Thin horizontal meter with an optional label and value read-out.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    this.color = Palette.lava,
    this.height = 6,
    this.background,
    this.showTrackGlow = true,
  });

  final double value;
  final Color color;
  final double height;
  final Color? background;
  final bool showTrackGlow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: background ?? Colors.white.withValues(alpha: 0.07)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: Dim.normal,
              curve: Curves.easeOutCubic,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
                boxShadow: showTrackGlow
                    ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8)]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label + meter + trailing value, used in the many stat lists.
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.label,
    required this.value,
    required this.ratio,
    this.color = Palette.lava,
    this.icon,
  });

  final String label;
  final String value;
  final double ratio;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 6)],
            Expanded(child: Text(label, style: AppText.body14.copyWith(fontSize: 12.5))),
            Text(value, style: AppText.label.copyWith(color: color, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        MeterBar(value: ratio, color: color, height: 5),
      ],
    );
  }
}

/// Compact resource read-out; the wallet strip at the top of economy screens.
class ResourcePill extends StatelessWidget {
  const ResourcePill({super.key, required this.kind, required this.amount, this.dense = false});

  final ResourceKind kind;
  final int amount;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 5 : 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Palette.surfaceRaised.withValues(alpha: 0.72),
        border: Border.all(color: kind.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: dense ? 12 : 14, color: kind.color),
          SizedBox(width: dense ? 5 : 7),
          Text(
            _format(amount),
            style: AppText.label.copyWith(fontSize: dense ? 11 : 12.5, color: Palette.textPrimary),
          ),
        ],
      ),
    );
  }

  static String _format(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }
}

String formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}k';
  return '$value';
}

String formatDistance(double metres) {
  if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(2)} km';
  return '${metres.round()} m';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

/// Three-star rating shown for campaign levels.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.filled, this.size = 13, this.total = 3});

  final int filled;
  final double size;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 2),
            child: Icon(
              i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < filled ? Palette.ember : Palette.textMuted.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}

/// Player avatar: the chosen photo when there is one, otherwise the selected
/// lava skin sprite.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.imagePath,
    required this.fallbackSprite,
    this.size = 64,
    this.accent = Palette.lava,
    this.ring = true,
  });

  final String? imagePath;
  final String fallbackSprite;
  final double size;
  final Color accent;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Palette.surfaceHigh,
        border: ring ? Border.all(color: accent.withValues(alpha: 0.55), width: 1.5) : null,
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: size * 0.28)],
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.file(File(path), fit: BoxFit.cover, width: size, height: size)
            : Padding(
                padding: EdgeInsets.all(size * 0.12),
                child: SpriteTile(name: fallbackSprite, size: size * 0.76),
              ),
      ),
    );
  }
}

/// Placeholder shown where a list or grid has nothing to display yet.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: Dim.l, vertical: Dim.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: Palette.textMuted),
              const SizedBox(height: Dim.m),
              Text(title, style: AppText.subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(message, style: AppText.body14, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rarity tag used in the bestiary and the skin gallery.
class RarityTag extends StatelessWidget {
  const RarityTag({super.key, required this.rarity});

  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: rarity.color.withValues(alpha: 0.16),
        border: Border.all(color: rarity.color.withValues(alpha: 0.42)),
      ),
      child: Text(
        rarity.label.toUpperCase(),
        style: AppText.eyebrow.copyWith(color: rarity.color, fontSize: 9, letterSpacing: 1.1),
      ),
    );
  }
}
