import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/audio_service.dart';
import '../design/app_theme.dart';
import '../design/palette.dart';
import 'buttons.dart';
import 'lava_background.dart';

/// Landscape chrome shared by every non-gameplay screen: the animated backdrop,
/// a slim header with a back affordance, and a safe-area padded body.
///
/// Individual screens are deliberately free to lay their body out however they
/// like; only the frame is shared.
class ScreenShell extends StatelessWidget {
  const ScreenShell({
    super.key,
    required this.title,
    required this.body,
    this.eyebrow,
    this.accent = Palette.lava,
    this.actions = const [],
    this.showBack = true,
    this.backgroundIntensity = 1,
    this.headerTrailing,
    this.footer,
  });

  final String title;
  final String? eyebrow;
  final Widget body;
  final Color accent;
  final List<Widget> actions;
  final bool showBack;
  final double backgroundIntensity;
  final Widget? headerTrailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.ink,
      body: LavaBackground(
        accent: accent,
        intensity: backgroundIntensity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Dim.l, Dim.m, Dim.l, Dim.m),
            child: Column(
              children: [
                _Header(
                  title: title,
                  eyebrow: eyebrow,
                  accent: accent,
                  actions: actions,
                  showBack: showBack,
                  trailing: headerTrailing,
                ),
                const SizedBox(height: Dim.m),
                Expanded(child: body),
                if (footer != null) ...[const SizedBox(height: Dim.s), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.eyebrow,
    required this.accent,
    required this.actions,
    required this.showBack,
    required this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Color accent;
  final List<Widget> actions;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack) ...[
          CircleAction(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () {
              context.read<AudioService>().back();
              Navigator.of(context).maybePop();
            },
          ),
          const SizedBox(width: Dim.m),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (eyebrow != null)
                Text(eyebrow!.toUpperCase(), style: AppText.eyebrow.copyWith(color: accent)),
              if (eyebrow != null) const SizedBox(height: 3),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title.copyWith(fontSize: 21),
              ),
            ],
          ),
        ),
        ?trailing,
        for (final action in actions) ...[const SizedBox(width: Dim.s), action],
      ],
    ).animate().fadeIn(duration: 260.ms).slideY(begin: -0.18, curve: Curves.easeOutCubic);
  }
}

/// Small titled divider used inside screen bodies.
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text.toUpperCase(), style: AppText.eyebrow.copyWith(color: color ?? Palette.textMuted)),
        const SizedBox(width: Dim.s),
        Expanded(
          child: Container(
            height: 1,
            color: (color ?? Palette.textMuted).withValues(alpha: 0.18),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Dim.s), trailing!],
      ],
    );
  }
}
