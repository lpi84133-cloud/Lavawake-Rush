import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/palette.dart';

/// Frosted, hairline-bordered container used for nearly every grouping in the
/// app. `accent` tints the border and adds a soft inner glow.
///
/// Performance note: this deliberately does **not** use a real `BackdropFilter`
/// blur. Dozens of these appear on a single screen and a live backdrop blur per
/// panel is one of the most expensive things you can ask a mobile GPU to do. A
/// near-opaque translucent fill over the dark backdrop reads almost identically
/// while costing nothing, keeping menus at a steady frame rate.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Dim.m),
    this.radius = Dim.radiusL,
    this.accent,
    this.opacity = 0.42,
    this.borderWidth = 1,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accent;
  final double opacity;
  final double borderWidth;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? Palette.lava;
    final border = selected ? tint.withValues(alpha: 0.75) : Palette.hairline;
    final shape = BorderRadius.circular(radius);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.surfaceRaised.withValues(alpha: (opacity + 0.46).clamp(0.0, 1.0)),
            Palette.surface.withValues(alpha: (opacity + 0.40).clamp(0.0, 1.0)),
          ],
        ),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: selected
            ? [BoxShadow(color: tint.withValues(alpha: 0.22), blurRadius: 26, spreadRadius: -6)]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    content = ClipRRect(borderRadius: shape, child: content);

    if (onTap != null) {
      content = _PressableWrap(onTap: onTap!, radius: shape, child: content);
    }
    return content;
  }
}

class _PressableWrap extends StatefulWidget {
  const _PressableWrap({required this.child, required this.onTap, required this.radius});

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius radius;

  @override
  State<_PressableWrap> createState() => _PressableWrapState();
}

class _PressableWrapState extends State<_PressableWrap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: Dim.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A solid, non-blurred surface. Cheaper than [GlassPanel] and used where many
/// instances appear at once, such as long lists.
class FlatPanel extends StatelessWidget {
  const FlatPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Dim.m),
    this.radius = Dim.radiusM,
    this.accent,
    this.selected = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? Palette.lava;
    final shape = BorderRadius.circular(radius);
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: selected ? tint.withValues(alpha: 0.12) : Palette.surfaceRaised.withValues(alpha: 0.66),
        border: Border.all(color: selected ? tint.withValues(alpha: 0.6) : Palette.hairline),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return panel;
    return _PressableWrap(onTap: onTap!, radius: shape, child: panel);
  }
}
