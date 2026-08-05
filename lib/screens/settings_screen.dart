import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/buttons.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../state/audio_service.dart';
import '../state/game_state.dart';
import '../state/settings_state.dart';

/// Settings. Two columns: audio and feel on the left, gameplay and data on the
/// right, so the long list never scrolls in landscape.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return ScreenShell(
      title: 'Settings',
      eyebrow: 'Tune the experience',
      accent: Palette.frost,
      headerTrailing: Chip2(
        label: 'RESTORE DEFAULTS',
        icon: Icons.restart_alt_rounded,
        color: Palette.frost,
        dense: true,
        onTap: () {
          context.read<AudioService>().back();
          settings.restoreDefaults();
        },
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(right: 4),
              children: [
                _Group(
                  title: 'Audio',
                  icon: Icons.graphic_eq_rounded,
                  accent: Palette.ember,
                  children: [
                    _SliderRow(
                      label: 'Music',
                      value: settings.music,
                      icon: Icons.music_note_rounded,
                      onChanged: (v) => settings.music = v,
                    ),
                    _SliderRow(
                      label: 'Sound effects',
                      value: settings.sfx,
                      icon: Icons.volume_up_rounded,
                      onChanged: (v) {
                        settings.sfx = v;
                        context.read<AudioService>().tap();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Dim.m),
                _Group(
                  title: 'Feel',
                  icon: Icons.vibration_rounded,
                  accent: Palette.venom,
                  children: [
                    _ToggleRow(
                      label: 'Haptics',
                      subtitle: 'Vibrate on impacts and pickups.',
                      value: settings.haptics,
                      onChanged: (v) => settings.haptics = v,
                    ),
                    _ToggleRow(
                      label: 'Screen shake',
                      subtitle: 'Camera kicks on big hits.',
                      value: settings.screenShake,
                      onChanged: (v) => settings.screenShake = v,
                    ),
                    _ToggleRow(
                      label: 'Show tips',
                      subtitle: 'Surface hints on the loading and brief screens.',
                      value: settings.showTips,
                      onChanged: (v) => settings.showTips = v,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Dim.m),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(right: 4),
              children: [
                _Group(
                  title: 'Controls',
                  icon: Icons.gamepad_rounded,
                  accent: Palette.crystal,
                  children: [
                    for (final scheme in ControlScheme.values)
                      _RadioRow(
                        label: scheme.label,
                        subtitle: scheme.blurb,
                        selected: settings.controls == scheme,
                        onTap: () {
                          settings.controls = scheme;
                          context.read<AudioService>().toggle();
                        },
                      ),
                    _ToggleRow(
                      label: 'Left-handed HUD',
                      subtitle: 'Move the ability cluster to the left.',
                      value: settings.leftHanded,
                      onChanged: (v) => settings.leftHanded = v,
                    ),
                  ],
                ),
                const SizedBox(height: Dim.m),
                _Group(
                  title: 'Graphics',
                  icon: Icons.auto_awesome_rounded,
                  accent: Palette.lava,
                  children: [
                    for (final q in GraphicsQuality.values)
                      _RadioRow(
                        label: q.label,
                        subtitle: q.blurb,
                        selected: settings.quality == q,
                        onTap: () {
                          settings.quality = q;
                          context.read<AudioService>().toggle();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: Dim.m),
                const _DangerZone(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.icon, required this.accent, required this.children});

  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: Dim.s),
              Text(title.toUpperCase(), style: AppText.eyebrow.copyWith(color: accent, letterSpacing: 1.6)),
            ],
          ),
          const SizedBox(height: Dim.s),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: Dim.m, color: Palette.hairline),
            children[i],
          ],
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value, required this.icon, required this.onChanged});

  final String label;
  final double value;
  final IconData icon;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Palette.textSecondary),
        const SizedBox(width: Dim.s),
        SizedBox(width: 96, child: Text(label, style: AppText.body14.copyWith(fontSize: 12.5))),
        Expanded(
          child: Slider(value: value, onChanged: onChanged),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '${(value * 100).round()}',
            textAlign: TextAlign.end,
            style: AppText.label.copyWith(fontSize: 12, color: Palette.ember),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.label.copyWith(fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.body14.copyWith(fontSize: 10.5, color: Palette.textMuted)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.subtitle, required this.selected, required this.onTap});

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            size: 17,
            color: selected ? Palette.lava : Palette.textMuted,
          ),
          const SizedBox(width: Dim.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.label.copyWith(fontSize: 12.5, color: selected ? Palette.textPrimary : Palette.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.body14.copyWith(fontSize: 10.5, color: Palette.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: Palette.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 15, color: Palette.danger),
              const SizedBox(width: Dim.s),
              Text('DATA', style: AppText.eyebrow.copyWith(color: Palette.danger, letterSpacing: 1.6)),
            ],
          ),
          const SizedBox(height: Dim.s),
          Text(
            'All progress is stored only on this device. Version ${AppConfig.version}.',
            style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted),
          ),
          const SizedBox(height: Dim.m),
          LavaButton(
            label: 'Reset all progress',
            icon: Icons.delete_forever_rounded,
            tone: ButtonTone.danger,
            expand: true,
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    context.read<AudioService>().openPanel();
    showDialog<void>(
      context: context,
      barrierColor: Palette.voidBlack.withValues(alpha: 0.7),
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassPanel(
            padding: const EdgeInsets.all(Dim.l),
            accent: Palette.danger,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Reset everything?', style: AppText.title.copyWith(fontSize: 20)),
                const SizedBox(height: Dim.s),
                Text(
                  'This wipes your profile, progress, perks and unlocks. It cannot be undone.',
                  style: AppText.body14,
                ),
                const SizedBox(height: Dim.l),
                Row(
                  children: [
                    Expanded(
                      child: LavaButton(
                        label: 'Cancel',
                        tone: ButtonTone.ghost,
                        expand: true,
                        onPressed: () {
                          context.read<AudioService>().cancel();
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: Dim.m),
                    Expanded(
                      child: LavaButton(
                        label: 'Reset',
                        icon: Icons.delete_forever_rounded,
                        tone: ButtonTone.danger,
                        expand: true,
                        onPressed: () {
                          context.read<GameState>().resetProgress();
                          context.read<AudioService>().confirm();
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
