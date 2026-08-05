import 'package:flutter/material.dart';

/// The single source of colour truth for the whole game.
///
/// The palette is deliberately narrow: near-black volcanic neutrals carry the
/// layout, one warm accent drives everything interactive, and the elemental
/// hues are reserved for content that actually represents that element.
class Palette {
  const Palette._();

  // Neutrals -----------------------------------------------------------------
  static const Color voidBlack = Color(0xFF070506);
  static const Color ink = Color(0xFF0B0709);
  static const Color surface = Color(0xFF130E12);
  static const Color surfaceRaised = Color(0xFF1B141A);
  static const Color surfaceHigh = Color(0xFF241B22);
  static const Color hairline = Color(0x1FFFFFFF);
  static const Color hairlineStrong = Color(0x33FFFFFF);

  // Text ---------------------------------------------------------------------
  static const Color textPrimary = Color(0xFFF7F2F5);
  static const Color textSecondary = Color(0xFFB6ABB4);
  static const Color textMuted = Color(0xFF7C7280);

  // Accent -------------------------------------------------------------------
  static const Color lava = Color(0xFFFF5A1F);
  static const Color lavaBright = Color(0xFFFF8A3D);
  static const Color ember = Color(0xFFFFB020);
  static const Color crimson = Color(0xFFE83A1E);
  static const Color deepLava = Color(0xFF8A1F09);

  // Elements -----------------------------------------------------------------
  static const Color stone = Color(0xFF9A8F87);
  static const Color metal = Color(0xFFE0BE7C);
  static const Color fire = Color(0xFFFF7A18);
  static const Color crystal = Color(0xFFB06CF5);
  static const Color frost = Color(0xFF48BEF5);
  static const Color obsidian = Color(0xFF7A6C9B);
  static const Color venom = Color(0xFF4ADE80);

  // Semantic -----------------------------------------------------------------
  static const Color success = Color(0xFF3DD68C);
  static const Color warning = Color(0xFFFFC53D);
  static const Color danger = Color(0xFFFF4D4D);

  static const List<Color> lavaGradient = [Color(0xFFFFC13D), Color(0xFFFF6A1F), Color(0xFFE02E12)];
  static const List<Color> emberGradient = [Color(0xFFFFD070), Color(0xFFFF8A2B)];

  /// Vertical wash used behind every screen so the app reads as one surface.
  static const List<Color> shellGradient = [
    Color(0xFF120C10),
    Color(0xFF0A0709),
    Color(0xFF060405),
  ];

  static Color glowOf(Color base) => base.withValues(alpha: 0.35);
}
