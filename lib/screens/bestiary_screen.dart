import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/game_data.dart';
import '../data/models.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';

/// Collection screen, laid out as a three-pane master-detail: family rail on the
/// left, a grid of creatures in the middle, and a full dossier on the right.
class BestiaryScreen extends StatefulWidget {
  const BestiaryScreen({super.key});

  @override
  State<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends State<BestiaryScreen> {
  String _family = GameData.familyPrefixes.first;
  late EnemyDef _selected = GameData.family(_family).first;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final roster = GameData.family(_family);

    return ScreenShell(
      title: 'Bestiary',
      eyebrow: 'Material collection',
      accent: Palette.crystal,
      headerTrailing: Row(
        children: [
          SizedBox(
            width: 120,
            child: MeterBar(value: game.collectionRatio, color: Palette.crystal, height: 5),
          ),
          const SizedBox(width: Dim.s),
          Text(
            '${game.collectionCount}/${GameData.enemies.length}',
            style: AppText.label.copyWith(fontSize: 12, color: Palette.crystal),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 148, child: _FamilyRail(current: _family, onPick: _pickFamily, game: game)),
          const SizedBox(width: Dim.m),
          Expanded(
            flex: 5,
            child: _CreatureGrid(
              roster: roster,
              selected: _selected,
              discovered: game.discovered,
              onPick: (def) {
                context.read<AudioService>().tap();
                setState(() => _selected = def);
              },
            ),
          ),
          const SizedBox(width: Dim.m),
          Expanded(
            flex: 4,
            child: _Dossier(def: _selected, known: game.discovered.contains(_selected.id)),
          ),
        ],
      ),
    );
  }

  void _pickFamily(String prefix) {
    context.read<AudioService>().tap();
    setState(() {
      _family = prefix;
      _selected = GameData.family(prefix).first;
    });
  }
}

class _FamilyRail extends StatelessWidget {
  const _FamilyRail({required this.current, required this.onPick, required this.game});

  final String current;
  final ValueChanged<String> onPick;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final prefix in GameData.familyPrefixes)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Dim.s),
              child: _FamilyButton(
                prefix: prefix,
                selected: prefix == current,
                found: GameData.family(prefix).where((e) => game.discovered.contains(e.id)).length,
                total: GameData.family(prefix).length,
                onTap: () => onPick(prefix),
              ),
            ),
          ),
      ],
    );
  }
}

class _FamilyButton extends StatelessWidget {
  const _FamilyButton({
    required this.prefix,
    required this.selected,
    required this.found,
    required this.total,
    required this.onTap,
  });

  final String prefix;
  final bool selected;
  final int found;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sample = GameData.family(prefix).first;
    final accent = sample.essence.color;

    return FlatPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      accent: accent,
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          SpriteTile(name: sample.sprite, size: 30),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  GameData.familyLabel(prefix),
                  maxLines: 2,
                  style: AppText.label.copyWith(
                    fontSize: 10.5,
                    color: selected ? accent : Palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text('$found/$total', style: AppText.eyebrow.copyWith(fontSize: 8.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatureGrid extends StatelessWidget {
  const _CreatureGrid({
    required this.roster,
    required this.selected,
    required this.discovered,
    required this.onPick,
  });

  final List<EnemyDef> roster;
  final EnemyDef selected;
  final Set<String> discovered;
  final ValueChanged<EnemyDef> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: Dim.s,
        crossAxisSpacing: Dim.s,
        childAspectRatio: 0.88,
      ),
      itemCount: roster.length,
      itemBuilder: (context, index) {
        final def = roster[index];
        final known = discovered.contains(def.id);
        return FlatPanel(
              padding: const EdgeInsets.all(7),
              accent: def.essence.color,
              selected: def.id == selected.id,
              onTap: () => onPick(def),
              child: Column(
                children: [
                  Expanded(
                    child: SpriteTile(
                      name: def.sprite,
                      size: 100,
                      locked: !known,
                      glow: known ? def.essence.color : null,
                      glowStrength: 0.18,
                    ),
                  ),
                  Text(
                    known ? def.name : '???',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppText.label.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 3),
                  RarityTag(rarity: def.rarity),
                ],
              ),
            )
            .animate()
            .fadeIn(delay: (index * 28).ms, duration: 260.ms)
            .scaleXY(begin: 0.92, curve: Curves.easeOutBack);
      },
    );
  }
}

class _Dossier extends StatelessWidget {
  const _Dossier({required this.def, required this.known});

  final EnemyDef def;
  final bool known;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: def.essence.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.essence.label.toUpperCase(), style: AppText.eyebrow.copyWith(color: def.essence.color)),
                    const SizedBox(height: 2),
                    Text(
                      known ? def.name : 'Unrecorded',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title.copyWith(fontSize: 19),
                    ),
                  ],
                ),
              ),
              RarityTag(rarity: def.rarity),
            ],
          ),
          const SizedBox(height: Dim.s),
          Expanded(
            child: Center(
              child: SpriteTile(
                name: def.sprite,
                size: 150,
                locked: !known,
                glow: known ? def.essence.color : null,
              ).animate(key: ValueKey(def.id)).fadeIn(duration: 280.ms).scaleXY(begin: 0.9),
            ),
          ),
          const SizedBox(height: Dim.s),
          StatRow(
            label: 'Armour rating',
            value: '${(def.armor * 100).round()}%',
            ratio: def.armor,
            color: def.essence.color,
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 7),
          StatRow(
            label: 'Toughness',
            value: def.toughness.toStringAsFixed(1),
            ratio: def.toughness / 16,
            color: Palette.stone,
            icon: Icons.fitness_center_rounded,
          ),
          const SizedBox(height: 7),
          StatRow(
            label: 'Mass yield',
            value: '+${(def.mass * 100).round()}',
            ratio: def.mass / 0.36,
            color: Palette.ember,
            icon: Icons.scale_rounded,
          ),
          const SizedBox(height: Dim.m),
          Container(
            padding: const EdgeInsets.all(Dim.s),
            decoration: BoxDecoration(
              borderRadius: Dim.brS,
              color: Palette.surfaceHigh.withValues(alpha: 0.5),
              border: Border.all(color: Palette.hairline),
            ),
            child: Text(
              known ? def.lore : 'Absorb one of these to record its dossier.',
              style: AppText.body14.copyWith(fontSize: 11.5),
            ),
          ),
          const SizedBox(height: Dim.s),
          Row(
            children: [
              Chip2(
                label: 'THREAT ${def.threat}',
                icon: Icons.warning_amber_rounded,
                dense: true,
                color: Palette.warning,
                selected: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  def.essence.perk,
                  maxLines: 2,
                  style: AppText.body14.copyWith(fontSize: 10.5, color: Palette.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
