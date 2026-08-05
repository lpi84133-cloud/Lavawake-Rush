import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/common.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/game_data.dart';
import '../data/models.dart';

/// Forms Codex. Explains the material-fusion system that drives the run: which
/// two essences combine into which hybrid, and what each one changes. It reads
/// as a recipe book, distinct from the grid-heavy collection screens.
class FormsCodexScreen extends StatelessWidget {
  const FormsCodexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenShell(
      title: 'Forms Codex',
      eyebrow: 'Fusion recipes',
      accent: Palette.ember,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlatPanel(
            padding: const EdgeInsets.symmetric(horizontal: Dim.m, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.merge_type_rounded, size: 14, color: Palette.ember),
                const SizedBox(width: Dim.s),
                Expanded(
                  child: Text(
                    'Hold two materials at once and the flow fuses into a hybrid form mid-run. Each form '
                    'trades one strength for one weakness - the whole build is in the mix you keep hot.',
                    style: AppText.body14.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dim.m),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Dim.s,
                crossAxisSpacing: Dim.s,
                childAspectRatio: 3.1,
              ),
              itemCount: GameData.forms.length,
              itemBuilder: (context, index) => _FormCard(form: GameData.forms[index], index: index),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.form, required this.index});

  final FormDef form;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isFinal = form.recipe.length >= 5;
    final isBase = form.recipe.isEmpty;
    final accent = isFinal
        ? Palette.lava
        : isBase
        ? Palette.stone
        : form.recipe.first.color;

    return GlassPanel(
          padding: const EdgeInsets.all(Dim.m),
          accent: accent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SpriteTile(name: form.sprite, size: 56, glow: accent, glowStrength: 0.2),
              const SizedBox(width: Dim.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            form.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.subtitle.copyWith(fontSize: 15),
                          ),
                        ),
                        if (isFinal)
                          Chip2(label: 'FINAL', color: Palette.lava, selected: true, dense: true)
                        else if (isBase)
                          Chip2(label: 'BASE', color: Palette.stone, selected: true, dense: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (form.recipe.isEmpty)
                      Text('Always available', style: AppText.eyebrow.copyWith(fontSize: 8.5))
                    else
                      Row(
                        children: [
                          for (var i = 0; i < form.recipe.length; i++) ...[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                child: Icon(Icons.add_rounded, size: 10, color: Palette.textMuted),
                              ),
                            Icon(form.recipe[i].icon, size: 12, color: form.recipe[i].color),
                          ],
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      form.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14.copyWith(fontSize: 10.5, color: Palette.textMuted),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.add_rounded, size: 11, color: Palette.success),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            form.strength,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body14.copyWith(fontSize: 10, color: Palette.success),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.remove_rounded, size: 11, color: Palette.danger),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            form.weakness,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body14.copyWith(fontSize: 10, color: Palette.danger),
                          ),
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
        .fadeIn(delay: (index * 45).ms, duration: 280.ms)
        .slideY(begin: 0.12, curve: Curves.easeOutCubic);
  }
}
