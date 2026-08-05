import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/models.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import '../state/settings_state.dart';

/// Evolution Lab. A scrolling ledger of upgrade tracks on the left, with a live
/// radar profile of the resulting flow on the right.
class UpgradesScreen extends StatefulWidget {
  const UpgradesScreen({super.key});

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen> {
  UpgradeTrack? _flash;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();

    return ScreenShell(
      title: 'Evolution Lab',
      eyebrow: 'Permanent upgrades',
      accent: Palette.frost,
      headerTrailing: Row(
        children: [
          for (final kind in ResourceKind.values)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ResourcePill(kind: kind, amount: game.resources[kind]!, dense: true),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 62,
            child: ListView.separated(
              padding: const EdgeInsets.only(right: 2, bottom: 2),
              itemCount: UpgradeTrack.values.length,
              separatorBuilder: (_, _) => const SizedBox(height: Dim.s),
              itemBuilder: (context, index) {
                final track = UpgradeTrack.values[index];
                return _TrackRow(
                  track: track,
                  level: game.upgrades[track]!,
                  cost: game.upgradeCost(track),
                  affordable: game.canAffordUpgrade(track),
                  wallet: game.resources[track.currency]!,
                  flashing: _flash == track,
                  onBuy: () => _buy(track),
                ).animate().fadeIn(delay: (index * 34).ms, duration: 260.ms).slideX(begin: -0.04);
              },
            ),
          ),
          const SizedBox(width: Dim.m),
          Expanded(flex: 38, child: _ProfilePanel(game: game)),
        ],
      ),
    );
  }

  void _buy(UpgradeTrack track) {
    final game = context.read<GameState>();
    final audio = context.read<AudioService>();
    if (game.buyUpgrade(track)) {
      audio.unlock();
      context.read<SettingsState>().thud();
      setState(() => _flash = track);
      Future<void>.delayed(const Duration(milliseconds: 520), () {
        if (mounted) setState(() => _flash = null);
      });
    } else {
      audio.error();
    }
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.level,
    required this.cost,
    required this.affordable,
    required this.wallet,
    required this.flashing,
    required this.onBuy,
  });

  final UpgradeTrack track;
  final int level;
  final int cost;
  final bool affordable;
  final int wallet;
  final bool flashing;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final maxed = level >= track.maxLevel;
    final accent = track.currency.color;

    return FlatPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: accent,
      selected: flashing,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: Dim.brS,
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(track.icon, size: 18, color: accent),
          ),
          const SizedBox(width: Dim.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(track.label, style: AppText.label.copyWith(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      maxed ? 'MAX' : 'LV $level / ${track.maxLevel}',
                      style: AppText.eyebrow.copyWith(
                        fontSize: 9,
                        color: maxed ? Palette.ember : Palette.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  track.blurb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (var i = 0; i < track.maxLevel; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == track.maxLevel - 1 ? 0 : 3),
                          child: AnimatedContainer(
                            duration: Dim.normal,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i < level ? accent : Colors.white.withValues(alpha: 0.07),
                              boxShadow: i < level
                                  ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 6)]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Dim.m),
          SizedBox(
            width: 116,
            child: maxed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 17, color: Palette.ember),
                      const SizedBox(height: 3),
                      Text('Fully evolved', style: AppText.eyebrow.copyWith(fontSize: 8.5)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(track.currency.icon, size: 12, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            '$cost',
                            style: AppText.label.copyWith(
                              fontSize: 12,
                              color: affordable ? Palette.textPrimary : Palette.danger,
                            ),
                          ),
                          Text(
                            ' / $wallet',
                            style: AppText.body14.copyWith(fontSize: 10, color: Palette.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LavaButton(
                        label: 'Upgrade',
                        compact: true,
                        expand: true,
                        accent: accent,
                        tone: affordable ? ButtonTone.primary : ButtonTone.ghost,
                        onPressed: affordable ? onBuy : null,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: Palette.frost,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            text: 'Flow profile',
            color: Palette.frost,
            trailing: Text(
              '${game.upgradeLevelsBought} / ${UpgradeTrack.values.length * 8}',
              style: AppText.label.copyWith(fontSize: 11, color: Palette.frost),
            ),
          ),
          const SizedBox(height: Dim.s),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _RadarPainter(
                    values: [
                      for (final track in UpgradeTrack.values)
                        game.upgrades[track]! / track.maxLevel,
                    ],
                    labels: [for (final track in UpgradeTrack.values) _short(track)],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Dim.s),
          FlatPanel(
            padding: const EdgeInsets.all(Dim.s),
            child: Column(
              children: [
                _Delta(label: 'Base heat', value: game.bonus(UpgradeTrack.heat)),
                const SizedBox(height: 5),
                _Delta(label: 'Melt rate', value: game.bonus(UpgradeTrack.absorption)),
                const SizedBox(height: 5),
                _Delta(label: 'Integrity', value: game.bonus(UpgradeTrack.integrity)),
                const SizedBox(height: 5),
                _Delta(label: 'Harvest', value: game.bonus(UpgradeTrack.harvest)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _short(UpgradeTrack track) => switch (track) {
    UpgradeTrack.heat => 'HEAT',
    UpgradeTrack.mass => 'MASS',
    UpgradeTrack.speed => 'SPD',
    UpgradeTrack.absorption => 'ABS',
    UpgradeTrack.integrity => 'INT',
    UpgradeTrack.surge => 'SRG',
    UpgradeTrack.shield => 'SHD',
    UpgradeTrack.harvest => 'HRV',
  };
}

class _Delta extends StatelessWidget {
  const _Delta({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final percent = ((value - 1) * 100).round();
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.body14.copyWith(fontSize: 11.5))),
        Text(
          percent == 0 ? 'base' : '+$percent%',
          style: AppText.label.copyWith(
            fontSize: 11.5,
            color: percent == 0 ? Palette.textMuted : Palette.success,
          ),
        ),
      ],
    );
  }
}

/// Eight-axis radar chart drawn by hand so it can share the exact palette and
/// hairline weights used by the rest of the interface.
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final count = values.length;
    final step = math.pi * 2 / count;

    final web = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.09);

    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final angle = -math.pi / 2 + step * i;
        final r = radius * ring / 4;
        final point = centre + Offset(math.cos(angle) * r, math.sin(angle) * r);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path..close(), web);
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + step * i;
      canvas.drawLine(centre, centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius), web);
    }

    final shape = Path();
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + step * i;
      final r = radius * (0.08 + values[i] * 0.92);
      final point = centre + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        shape.moveTo(point.dx, point.dy);
      } else {
        shape.lineTo(point.dx, point.dy);
      }
    }
    shape.close();

    canvas.drawPath(
      shape,
      Paint()
        ..shader = RadialGradient(
          colors: [Palette.frost.withValues(alpha: 0.42), Palette.lava.withValues(alpha: 0.22)],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Palette.frost.withValues(alpha: 0.85),
    );

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + step * i;
      final r = radius * (0.08 + values[i] * 0.92);
      canvas.drawCircle(
        centre + Offset(math.cos(angle) * r, math.sin(angle) * r),
        2.6,
        Paint()..color = Palette.lavaBright,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: AppText.eyebrow.copyWith(fontSize: 8, letterSpacing: 0.8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelPoint = centre + Offset(math.cos(angle) * (radius + 12), math.sin(angle) * (radius + 12));
      painter.paint(canvas, labelPoint - Offset(painter.width / 2, painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values);

  static bool listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
