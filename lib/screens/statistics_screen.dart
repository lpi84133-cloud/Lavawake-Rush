import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/models.dart';
import '../state/game_state.dart';

const List<String> _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Statistics. A dashboard: KPI band and a score trend on the left, weekly play
/// time and material usage on the right.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final stats = game.stats;
    final winRate = stats.runs == 0 ? 0.0 : stats.victories / stats.runs;

    return ScreenShell(
      title: 'Statistics',
      eyebrow: 'Lifetime record',
      accent: Palette.obsidian,
      headerTrailing: Text(
        '${stats.runs} RUNS - ${formatDuration(Duration(seconds: stats.playSeconds))} PLAYED',
        style: AppText.eyebrow.copyWith(fontSize: 9.5),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Kpi(
                      label: 'Total score',
                      value: formatCount(stats.totalScore),
                      icon: Icons.stacked_line_chart_rounded,
                      accent: Palette.lava,
                    ),
                    const SizedBox(width: Dim.s),
                    _Kpi(
                      label: 'Win rate',
                      value: '${(winRate * 100).round()}%',
                      icon: Icons.emoji_events_outlined,
                      accent: Palette.success,
                    ),
                    const SizedBox(width: Dim.s),
                    _Kpi(
                      label: 'Absorbed',
                      value: formatCount(stats.absorbed),
                      icon: Icons.blur_circular_rounded,
                      accent: Palette.crystal,
                    ),
                    const SizedBox(width: Dim.s),
                    _Kpi(
                      label: 'Distance',
                      value: formatDistance(stats.distance),
                      icon: Icons.straighten_rounded,
                      accent: Palette.frost,
                    ),
                  ],
                ),
                const SizedBox(height: Dim.m),
                Expanded(child: _ScoreTrend(scores: game.recentScores)),
              ],
            ),
          ),
          const SizedBox(width: Dim.m),
          Expanded(
            flex: 42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 45, child: _WeeklyBars(minutes: game.weeklyMinutes)),
                const SizedBox(height: Dim.m),
                Expanded(flex: 55, child: _MaterialUsage(game: game)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon, required this.accent});

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child:
          FlatPanel(
            padding: const EdgeInsets.all(Dim.m),
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 13, color: accent),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.eyebrow.copyWith(fontSize: 8.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: AppText.numeric.copyWith(fontSize: 22)),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.18, curve: Curves.easeOutCubic),
    );
  }
}

class _ScoreTrend extends StatelessWidget {
  const _ScoreTrend({required this.scores});

  final List<int> scores;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(text: 'Score trend', color: Palette.lava),
            const Expanded(
              child: Center(
                child: Text('Finish a run to start the trend line.', style: AppText.body14),
              ),
            ),
          ],
        ),
      );
    }

    final maxScore = scores.reduce(math.max).toDouble();
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(Dim.m, Dim.m, Dim.m, Dim.s),
      accent: Palette.lava,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            text: 'Last ${scores.length} runs',
            color: Palette.lava,
            trailing: Text(
              'PEAK ${formatCount(maxScore.round())}',
              style: AppText.eyebrow.copyWith(fontSize: 9, color: Palette.ember),
            ),
          ),
          const SizedBox(height: Dim.m),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxScore * 1.18 + 10,
                minX: 0,
                maxX: (scores.length - 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxScore * 1.18 + 10) / 3,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.white.withValues(alpha: 0.06), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index != 0 && index != scores.length - 1) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          index == 0 ? 'oldest' : 'latest',
                          style: AppText.eyebrow.copyWith(fontSize: 8),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < scores.length; i++) FlSpot(i.toDouble(), scores[i].toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.28,
                    barWidth: 2.4,
                    color: Palette.lavaBright,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 2.6,
                        color: Palette.ember,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Palette.lava.withValues(alpha: 0.34),
                          Palette.lava.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms, duration: 340.ms);
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.minutes});

  final List<int> minutes;

  @override
  Widget build(BuildContext context) {
    final peak = minutes.isEmpty ? 0 : minutes.reduce(math.max);
    final today = DateTime.now().weekday - 1;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(Dim.m, Dim.m, Dim.m, Dim.s),
      accent: Palette.frost,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            text: 'Minutes this week',
            color: Palette.frost,
            trailing: Text(
              '${minutes.fold(0, (a, b) => a + b)} MIN',
              style: AppText.eyebrow.copyWith(fontSize: 9, color: Palette.frost),
            ),
          ),
          const SizedBox(height: Dim.s),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: (peak == 0 ? 10 : peak * 1.25).toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: const BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 16,
                      getTitlesWidget: (value, meta) {
                        final index = value.round().clamp(0, 6);
                        return Text(
                          _weekdayLabels[index],
                          style: AppText.eyebrow.copyWith(
                            fontSize: 9,
                            color: index == today ? Palette.frost : Palette.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < minutes.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: minutes[i].toDouble(),
                          width: 13,
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: i == today
                                ? [Palette.frost.withValues(alpha: 0.5), Palette.frost]
                                : [
                                    Palette.obsidian.withValues(alpha: 0.4),
                                    Palette.obsidian.withValues(alpha: 0.9),
                                  ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms, duration: 320.ms);
  }
}

class _MaterialUsage extends StatelessWidget {
  const _MaterialUsage({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final use = game.stats.essenceUse;
    final peak = use.values.isEmpty ? 0 : use.values.reduce(math.max);

    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: Palette.crystal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(text: 'Material affinity', color: Palette.crystal),
          const SizedBox(height: Dim.s),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final essence in Essence.values)
                  StatRow(
                    label: essence.label,
                    value: '${use[essence] ?? 0} runs',
                    ratio: peak == 0 ? 0 : (use[essence] ?? 0) / peak,
                    color: essence.color,
                    icon: essence.icon,
                  ),
              ],
            ),
          ),
          const SizedBox(height: Dim.s),
          FlatPanel(
            padding: const EdgeInsets.all(Dim.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final kind in ResourceKind.values)
                  Column(
                    children: [
                      Icon(kind.icon, size: 12, color: kind.color),
                      const SizedBox(height: 4),
                      Text(
                        formatCount(game.stats.earned[kind] ?? 0),
                        style: AppText.label.copyWith(fontSize: 11),
                      ),
                      Text('EARNED', style: AppText.eyebrow.copyWith(fontSize: 7)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 240.ms, duration: 320.ms);
  }
}
