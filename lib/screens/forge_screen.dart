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

/// One conversion the forge can perform.
class _Recipe {
  const _Recipe({
    required this.from,
    required this.to,
    required this.cost,
    required this.yield_,
    required this.name,
    required this.note,
  });

  final ResourceKind from;
  final ResourceKind to;
  final int cost;
  final int yield_;
  final String name;
  final String note;
}

const List<_Recipe> _recipes = [
  _Recipe(
    from: ResourceKind.magma,
    to: ResourceKind.obsidian,
    cost: 240,
    yield_: 10,
    name: 'Quench',
    note: 'Chill raw magma against a cold seam until it sets into obsidian.',
  ),
  _Recipe(
    from: ResourceKind.magma,
    to: ResourceKind.alloy,
    cost: 320,
    yield_: 9,
    name: 'Smelt',
    note: 'Run magma through the old forgeworks to draw out metal alloy.',
  ),
  _Recipe(
    from: ResourceKind.obsidian,
    to: ResourceKind.shards,
    cost: 18,
    yield_: 7,
    name: 'Cleave',
    note: 'Split obsidian along its grain to recover crystal shards.',
  ),
  _Recipe(
    from: ResourceKind.alloy,
    to: ResourceKind.obsidian,
    cost: 14,
    yield_: 11,
    name: 'Temper',
    note: 'Fold alloy back into glass plating.',
  ),
  _Recipe(
    from: ResourceKind.shards,
    to: ResourceKind.cores,
    cost: 26,
    yield_: 1,
    name: 'Condense',
    note: 'Compress a heap of shards into a single ancient core.',
  ),
  _Recipe(
    from: ResourceKind.cores,
    to: ResourceKind.magma,
    cost: 1,
    yield_: 520,
    name: 'Unmake',
    note: 'Break a core apart for a large return of raw magma energy.',
  ),
];

/// The forge. Built as a workbench: recipe presets down the left, and one large
/// symmetric conversion plate in the middle that animates when it fires.
class ForgeScreen extends StatefulWidget {
  const ForgeScreen({super.key});

  @override
  State<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends State<ForgeScreen> {
  int _selected = 0;
  int _batches = 1;
  int _fireKey = 0;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final recipe = _recipes[_selected];
    final owned = game.resources[recipe.from]!;
    final maxBatches = (owned / recipe.cost).floor().clamp(0, 20);
    final batches = _batches.clamp(1, maxBatches == 0 ? 1 : maxBatches);
    final canForge = maxBatches >= batches && batches >= 1 && owned >= recipe.cost * batches;

    return ScreenShell(
      title: 'Forge',
      eyebrow: 'Resource conversion',
      accent: Palette.metal,
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
          SizedBox(
            width: 214,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(text: 'Recipes', color: Palette.metal),
                const SizedBox(height: Dim.s),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _recipes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _recipes[index];
                      return FlatPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        accent: item.to.color,
                        selected: index == _selected,
                        onTap: () {
                          context.read<AudioService>().tap();
                          setState(() {
                            _selected = index;
                            _batches = 1;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(item.from.icon, size: 13, color: item.from.color),
                            const Icon(Icons.chevron_right_rounded, size: 14, color: Palette.textMuted),
                            Icon(item.to.icon, size: 13, color: item.to.color),
                            const SizedBox(width: Dim.s),
                            Expanded(
                              child: Text(
                                item.name,
                                style: AppText.label.copyWith(
                                  fontSize: 12,
                                  color: index == _selected ? item.to.color : Palette.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (index * 30).ms, duration: 240.ms);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dim.l),
          Expanded(
            child: GlassPanel(
              padding: const EdgeInsets.all(Dim.l),
              accent: recipe.to.color,
              child: Column(
                children: [
                  Text(recipe.name.toUpperCase(), style: AppText.eyebrow.copyWith(color: recipe.to.color)),
                  const SizedBox(height: 4),
                  Text(recipe.note, textAlign: TextAlign.center, style: AppText.body14),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _Plate(
                          kind: recipe.from,
                          amount: recipe.cost * batches,
                          caption: 'CONSUMES',
                          owned: owned,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Dim.m),
                        child:
                            Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 22,
                                      color: recipe.to.color,
                                    ),
                                    const SizedBox(height: 2),
                                    Icon(Icons.east_rounded, size: 26, color: recipe.to.color),
                                  ],
                                )
                                .animate(key: ValueKey(_fireKey), onPlay: (c) => c.forward())
                                .shimmer(duration: 700.ms, color: Palette.ember)
                                .scaleXY(begin: 1, end: 1.12, duration: 220.ms)
                                .then()
                                .scaleXY(begin: 1, end: 0.893, duration: 220.ms),
                      ),
                      Expanded(
                        child: _Plate(
                          kind: recipe.to,
                          amount: recipe.yield_ * batches,
                          caption: 'PRODUCES',
                          owned: game.resources[recipe.to]!,
                          positive: true,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text('BATCHES', style: AppText.eyebrow),
                      const SizedBox(width: Dim.m),
                      CircleAction(
                        icon: Icons.remove_rounded,
                        size: 34,
                        onTap: batches > 1
                            ? () {
                                context.read<AudioService>().tap();
                                setState(() => _batches = batches - 1);
                              }
                            : null,
                      ),
                      SizedBox(
                        width: 52,
                        child: Text(
                          '$batches',
                          textAlign: TextAlign.center,
                          style: AppText.numeric.copyWith(fontSize: 22),
                        ),
                      ),
                      CircleAction(
                        icon: Icons.add_rounded,
                        size: 34,
                        onTap: batches < maxBatches
                            ? () {
                                context.read<AudioService>().tap();
                                setState(() => _batches = batches + 1);
                              }
                            : null,
                      ),
                      const SizedBox(width: Dim.m),
                      Text(
                        maxBatches == 0
                            ? 'Not enough ${recipe.from.label.toLowerCase()}'
                            : 'up to $maxBatches',
                        style: AppText.body14.copyWith(
                          fontSize: 11,
                          color: maxBatches == 0 ? Palette.danger : Palette.textMuted,
                        ),
                      ),
                      const Spacer(),
                      LavaButton(
                        label: 'Fire the forge',
                        icon: Icons.bolt_rounded,
                        accent: recipe.to.color,
                        onPressed: canForge ? () => _forge(recipe, batches) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _forge(_Recipe recipe, int batches) {
    final game = context.read<GameState>();
    final audio = context.read<AudioService>();
    if (game.forge(recipe.from, recipe.to, recipe.cost * batches, recipe.yield_ * batches)) {
      audio.reward();
      context.read<SettingsState>().thud();
      setState(() {
        _fireKey++;
        _batches = 1;
      });
    } else {
      audio.error();
    }
  }
}

class _Plate extends StatelessWidget {
  const _Plate({
    required this.kind,
    required this.amount,
    required this.caption,
    required this.owned,
    this.positive = false,
  });

  final ResourceKind kind;
  final int amount;
  final String caption;
  final int owned;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return FlatPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: kind.color,
      child: Column(
        children: [
          Text(caption, style: AppText.eyebrow.copyWith(fontSize: 9)),
          const SizedBox(height: Dim.s),
          SpriteTile(name: kind.sprite, size: 58, glow: kind.color, glowStrength: 0.2),
          const SizedBox(height: Dim.s),
          Text(
            '${positive ? '+' : '-'}$amount',
            style: AppText.numeric.copyWith(
              fontSize: 24,
              color: positive ? Palette.success : Palette.lavaBright,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kind.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text('holding $owned', style: AppText.eyebrow.copyWith(fontSize: 8.5)),
        ],
      ),
    );
  }
}
