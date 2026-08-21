import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/nav.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/asset_catalog.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../data/volcanic_events.dart';
import '../game/sprite_cache.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import 'gameplay_screen.dart';

/// The weekly event hub: what is live, how long it lasts, what it changes, and
/// where the player stands. Runs launched from here carry the event's
/// modifiers; nothing else in the game is affected by whichever event is up.
class VolcanicEventScreen extends StatefulWidget {
  const VolcanicEventScreen({super.key});

  @override
  State<VolcanicEventScreen> createState() => _VolcanicEventScreenState();
}

class _VolcanicEventScreenState extends State<VolcanicEventScreen> {
  Timer? _tick;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameState>().refreshEventIfNeeded();
    });
    // One second is enough for a countdown that is usually measured in days.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _warmUp();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _warmUp() async {
    // A missing backdrop must not leave the button stuck on "Preparing"; the
    // run can still start, it just decodes that sprite on demand.
    try {
      await SpriteCache.instance.load(GameData.regions.last.background);
    } on Object {
      // Ignored on purpose — loadAll below already tolerates bad assets.
    }
    await SpriteCache.instance.loadAll(GameData.sceneryPaths(), targetHeight: 320);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final event = game.activeEvent;

    return ScreenShell(
      title: event.name,
      eyebrow: 'Weekly event',
      accent: event.accent,
      backgroundIntensity: 1.2,
      headerTrailing: _Countdown(remaining: game.eventRemaining, accent: event.accent),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Below roughly a tablet width the two columns would each be too
          // narrow to read, so the screen falls back to a single scroll.
          if (constraints.maxWidth < 720) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Briefing(
                    event: event,
                    game: game,
                    ready: _ready,
                    onStart: _start,
                    shrinkWrap: true,
                  ),
                  const SizedBox(height: Dim.m),
                  _Objectives(game: game, event: event, shrinkWrap: true),
                  const SizedBox(height: Dim.m),
                  _Standings(game: game, event: event, shrinkWrap: true),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 53,
                child: _Briefing(event: event, game: game, ready: _ready, onStart: _start),
              ),
              const SizedBox(width: Dim.m),
              Expanded(
                flex: 47,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 52, child: _Objectives(game: game, event: event)),
                    const SizedBox(height: Dim.m),
                    Expanded(flex: 48, child: _Standings(game: game, event: event)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _start(VolcanicEventDef event) {
    context.read<AudioService>().play(Sfx.levelStart);
    Navigator.of(context).pushReplacement(
      fadeThrough(GameplayScreen(endless: true, event: event)),
    );
  }
}

/// Time left in the week, shown in the header.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining, required this.accent});

  final Duration remaining;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Chip2(
      label: 'ENDS IN ${VolcanicCalendar.formatRemaining(remaining)}',
      icon: Icons.timer_outlined,
      color: accent,
      selected: true,
      dense: true,
    );
  }
}

/// Left column: what the event is, what it changes, and the way in.
class _Briefing extends StatelessWidget {
  const _Briefing({
    required this.event,
    required this.game,
    required this.ready,
    required this.onStart,
    this.shrinkWrap = false,
  });

  final VolcanicEventDef event;
  final GameState game;
  final bool ready;
  final void Function(VolcanicEventDef event) onStart;

  /// Set when the column is already inside a scroll view, where its height is
  /// unbounded so it must wrap its content instead of claiming the space.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    // A landscape phone leaves barely 290 logical pixels for the body, which is
    // less than the briefing needs. The prose scrolls and the call to action
    // stays pinned, rather than the whole column overflowing.
    final column = shrinkWrap
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._briefing(),
              const SizedBox(height: Dim.s),
              _launchPanel(),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  children: _briefing(),
                ),
              ),
              const SizedBox(height: Dim.s),
              _launchPanel(),
            ],
          );

    return column
        .animate()
        .fadeIn(duration: 320.ms)
        .slideX(begin: -0.04, curve: Curves.easeOutCubic);
  }

  List<Widget> _briefing() {
    return [
        GlassPanel(
          padding: const EdgeInsets.all(Dim.m),
          accent: event.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: event.accent.withValues(alpha: 0.16),
                      border: Border.all(color: event.accent.withValues(alpha: 0.32)),
                    ),
                    child: Icon(event.icon, size: 20, color: event.accent),
                  ),
                  const SizedBox(width: Dim.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LIVE NOW', style: AppText.eyebrow.copyWith(color: event.accent)),
                        const SizedBox(height: 2),
                        Text(
                          event.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.subtitle.copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dim.m),
              Text(event.description, style: AppText.body14.copyWith(fontSize: 12.5)),
            ],
          ),
        ),
        const SizedBox(height: Dim.m),
        for (final rule in event.rules) ...[
          _RuleRow(rule: rule, accent: event.accent),
          const SizedBox(height: 6),
        ],
      ];
  }

  /// The score, the standing and the way in. Laid out as a column so a long
  /// event name or a six-figure score can never squeeze the button off the
  /// edge of a narrow left-hand pane.
  Widget _launchPanel() {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: event.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _Readout(
                  label: 'BEST THIS WEEK',
                  value: game.eventBest == 0 ? '- - -' : formatCount(game.eventBest),
                  tint: event.accent,
                ),
              ),
              Expanded(
                child: _Readout(
                  label: 'RANK',
                  value: game.eventBest == 0 ? '-' : '#${game.eventRank}',
                ),
              ),
              Expanded(
                child: _Readout(
                  label: 'RUNS',
                  value: '${game.eventRuns}',
                ),
              ),
            ],
          ),
          const SizedBox(height: Dim.s),
          LavaButton(
            label: ready ? 'Enter the event' : 'Preparing',
            icon: ready ? Icons.play_arrow_rounded : Icons.hourglass_top_rounded,
            accent: event.accent,
            expand: true,
            onPressed: ready ? () => onStart(event) : null,
          ),
          const SizedBox(height: 6),
          Text(
            'Next week: ${game.nextEvent.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.eyebrow.copyWith(fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.value, this.tint});

  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.eyebrow.copyWith(fontSize: 8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.numeric.copyWith(fontSize: 21, color: tint),
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.accent});

  final EventRule rule;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return FlatPanel(
      padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 9),
      child: Row(
        children: [
          Icon(rule.icon, size: 15, color: accent),
          const SizedBox(width: Dim.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.title, style: AppText.label.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  rule.body,
                  style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Right column, top half: the objectives that only this event advances.
class _Objectives extends StatelessWidget {
  const _Objectives({required this.game, required this.event, this.shrinkWrap = false});

  final GameState game;
  final VolcanicEventDef event;
  final bool shrinkWrap;

  /// Inside a scroll view the section must wrap its content; in the two-column
  /// layout it has to claim the height it was given.
  Widget _fill(Widget child) => shrinkWrap ? child : Expanded(child: child);

  @override
  Widget build(BuildContext context) {
    final board = game.eventQuests;
    final ready = game.eventQuestsReady;

    final list = ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: board.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _EventQuestCard(
        quest: board[index],
        accent: event.accent,
        index: index,
        onClaim: () {
          final audio = context.read<AudioService>();
          if (game.claimEventQuest(board[index])) {
            audio.reward();
          } else {
            audio.error();
          }
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        SectionLabel(
          text: 'Event objectives',
          color: event.accent,
          trailing: ready > 0
              ? Text(
                  '$ready READY',
                  style: AppText.eyebrow.copyWith(fontSize: 8.5, color: Palette.ember),
                )
              : null,
        ),
        const SizedBox(height: Dim.s),
        if (board.isEmpty)
          // Only ever on screen for the frame before the board is rolled, but
          // the pane can be shorter than the hint so it has to be able to
          // scroll rather than overflow.
          _fill(
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: shrinkWrap ? 0 : 120),
                child: const EmptyHint(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'Drawing objectives',
                  message: 'This week\'s tasks appear in a moment.',
                ),
              ),
            ),
          )
        else
          _fill(list),
      ],
    );
  }
}

class _EventQuestCard extends StatelessWidget {
  const _EventQuestCard({
    required this.quest,
    required this.accent,
    required this.index,
    required this.onClaim,
  });

  final QuestProgress quest;
  final Color accent;
  final int index;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final tint = quest.claimed
        ? Palette.textMuted
        : quest.complete
        ? Palette.success
        : accent;

    return GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 9),
          accent: tint,
          selected: quest.complete && !quest.claimed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quest.def.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SpriteTile(name: quest.def.rewardKind.sprite, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '+${quest.def.reward}',
                    style: AppText.label.copyWith(
                      fontSize: 11.5,
                      color: quest.def.rewardKind.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              MeterBar(value: quest.ratio, height: 4, color: tint),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${quest.progress} / ${quest.def.target}',
                    style: AppText.body14.copyWith(fontSize: 10.5, color: Palette.textMuted),
                  ),
                  const Spacer(),
                  if (quest.claimed)
                    Row(
                      children: [
                        const Icon(Icons.check_rounded, size: 12, color: Palette.textMuted),
                        const SizedBox(width: 3),
                        Text('Claimed', style: AppText.eyebrow.copyWith(fontSize: 8.5)),
                      ],
                    )
                  else
                    LavaButton(
                      label: quest.complete ? 'Claim' : 'In progress',
                      icon: quest.complete ? Icons.redeem_rounded : Icons.timelapse_rounded,
                      compact: true,
                      accent: tint,
                      tone: quest.complete ? ButtonTone.primary : ButtonTone.ghost,
                      onPressed: quest.complete ? onClaim : null,
                    ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (index * 60).ms, duration: 280.ms)
        .slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }
}

/// Right column, bottom half: this week's standings, kept apart from the
/// campaign leaderboard so buffed scores never mix into it.
class _Standings extends StatelessWidget {
  const _Standings({required this.game, required this.event, this.shrinkWrap = false});

  final GameState game;
  final VolcanicEventDef event;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    // The player is always shown, even when their score is far off the top.
    final board = game.eventLeaderboard;
    final playerIndex = board.indexWhere((e) => e.isPlayer);
    final visible = <(int, LeaderboardEntry)>[
      for (var i = 0; i < board.length && i < 5; i++) (i + 1, board[i]),
    ];
    if (playerIndex >= 5) visible.add((playerIndex + 1, board[playerIndex]));

    final list = ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final (place, entry) = visible[index];
        return _StandingRow(place: place, entry: entry, game: game, accent: event.accent);
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        SectionLabel(text: 'Event standings', color: event.accent),
        const SizedBox(height: Dim.s),
        if (shrinkWrap) list else Expanded(child: list),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.place,
    required this.entry,
    required this.game,
    required this.accent,
  });

  final int place;
  final LeaderboardEntry entry;
  final GameState game;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return FlatPanel(
      padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 7),
      accent: entry.isPlayer ? accent : null,
      selected: entry.isPlayer,
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$place',
              style: AppText.label.copyWith(
                fontSize: 11.5,
                color: entry.isPlayer ? accent : Palette.textMuted,
              ),
            ),
          ),
          if (entry.isPlayer)
            PlayerAvatar(
              imagePath: game.avatarPath,
              fallbackSprite: GameData.skinById[game.selectedSkin]?.sprite ?? 'skin_ember',
              size: 22,
              ring: false,
            )
          else
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.surfaceHigh,
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                size: 10,
                color: Palette.textMuted,
              ),
            ),
          const SizedBox(width: Dim.s),
          Expanded(
            child: Text(
              entry.isPlayer ? '${entry.name}  (you)' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(fontSize: 11.5),
            ),
          ),
          Text(
            entry.score == 0 ? '- - -' : formatCount(entry.score),
            style: AppText.label.copyWith(
              fontSize: 11.5,
              color: entry.isPlayer ? accent : Palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
