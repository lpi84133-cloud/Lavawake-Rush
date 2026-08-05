import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
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

/// Daily objectives. Four oversized cards in a 2x2 arrangement, each built around
/// a circular progress ring rather than a bar, which keeps this screen visually
/// separate from the bar-heavy economy screens.
class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameState>().refreshDailyQuestsIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final quests = game.quests;
    final ready = quests.where((q) => q.complete && !q.claimed).length;
    final done = quests.where((q) => q.claimed).length;

    return ScreenShell(
      title: 'Daily Tasks',
      eyebrow: 'Resets at midnight',
      accent: Palette.success,
      headerTrailing: Row(
        children: [
          Chip2(
            label: '$done / ${quests.length} CLAIMED',
            icon: Icons.inventory_2_outlined,
            color: Palette.success,
            selected: true,
            dense: true,
          ),
          if (ready > 0) ...[
            const SizedBox(width: 6),
            Chip2(
              label: '$ready READY',
              icon: Icons.redeem_rounded,
              color: Palette.ember,
              selected: true,
              dense: true,
            ),
          ],
        ],
      ),
      footer: FlatPanel(
        padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: Palette.textMuted),
            const SizedBox(width: Dim.s),
            Expanded(
              child: Text(
                'Objectives are generated from the calendar day on this device, so they work with no '
                'connection and survive a restart. Progress counts from every campaign and rush run.',
                style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
              ),
            ),
            Text('DAY ${game.questDay}', style: AppText.eyebrow.copyWith(fontSize: 9)),
          ],
        ),
      ),
      body: quests.isEmpty
          ? const EmptyHint(
              icon: Icons.hourglass_empty_rounded,
              title: 'No objectives yet',
              message: 'Come back in a moment while today\'s tasks are drawn.',
            )
          : GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 2,
              mainAxisSpacing: Dim.m,
              crossAxisSpacing: Dim.m,
              childAspectRatio: 2.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < quests.length; i++)
                  _QuestCard(quest: quests[i], index: i, onClaim: () => _claim(quests[i])),
              ],
            ),
    );
  }

  void _claim(QuestProgress quest) {
    final audio = context.read<AudioService>();
    if (context.read<GameState>().claimQuest(quest)) {
      audio.reward();
    } else {
      audio.error();
    }
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.index, required this.onClaim});

  final QuestProgress quest;
  final int index;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final accent = quest.claimed
        ? Palette.textMuted
        : quest.complete
        ? Palette.success
        : quest.def.rewardKind.color;

    return GlassPanel(
          padding: const EdgeInsets.all(Dim.m),
          accent: accent,
          selected: quest.complete && !quest.claimed,
          child: Row(
            children: [
              CircularPercentIndicator(
                radius: 40,
                lineWidth: 6,
                percent: quest.ratio,
                animation: true,
                animationDuration: 720,
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                progressColor: accent,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(quest.ratio * 100).round()}',
                      style: AppText.numeric.copyWith(fontSize: 19, color: accent),
                    ),
                    Text('PERCENT', style: AppText.eyebrow.copyWith(fontSize: 6.5)),
                  ],
                ),
              ),
              const SizedBox(width: Dim.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      quest.def.title,
                      maxLines: 2,
                      style: AppText.subtitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${quest.progress} of ${quest.def.target}',
                      style: AppText.body14.copyWith(fontSize: 11.5, color: Palette.textMuted),
                    ),
                    const SizedBox(height: Dim.s),
                    Row(
                      children: [
                        SpriteTile(name: quest.def.rewardKind.sprite, size: 22),
                        const SizedBox(width: 5),
                        Text(
                          '+${quest.def.reward}',
                          style: AppText.label.copyWith(fontSize: 12, color: quest.def.rewardKind.color),
                        ),
                        const Spacer(),
                        if (quest.claimed)
                          Row(
                            children: [
                              const Icon(Icons.check_rounded, size: 13, color: Palette.textMuted),
                              const SizedBox(width: 4),
                              Text('Claimed', style: AppText.eyebrow.copyWith(fontSize: 9)),
                            ],
                          )
                        else
                          LavaButton(
                            label: quest.complete ? 'Claim' : 'In progress',
                            icon: quest.complete ? Icons.redeem_rounded : Icons.timelapse_rounded,
                            compact: true,
                            accent: accent,
                            tone: quest.complete ? ButtonTone.primary : ButtonTone.ghost,
                            onPressed: quest.complete ? onClaim : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (index * 70).ms, duration: 300.ms)
        .slideY(begin: 0.12, curve: Curves.easeOutCubic);
  }
}
