import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/palette.dart';

enum ButtonTone { primary, ghost, danger }

/// The one button used across the whole app, in three tones.
class LavaButton extends StatefulWidget {
  const LavaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = ButtonTone.primary,
    this.expand = false,
    this.compact = false,
    this.accent,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonTone tone;
  final bool expand;
  final bool compact;
  final Color? accent;
  final Widget? trailing;

  @override
  State<LavaButton> createState() => _LavaButtonState();
}

class _LavaButtonState extends State<LavaButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final accent = widget.accent ?? (widget.tone == ButtonTone.danger ? Palette.danger : Palette.lava);
    final isPrimary = widget.tone == ButtonTone.primary;
    final height = widget.compact ? 40.0 : 50.0;

    final labelColor = !enabled
        ? Palette.textMuted
        : isPrimary
        ? Colors.white
        : accent;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.compact ? 16 : 18, color: labelColor),
          const SizedBox(width: Dim.s),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(
              color: labelColor,
              fontSize: widget.compact ? 12 : 13.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (widget.trailing != null) ...[const SizedBox(width: Dim.s), widget.trailing!],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.965 : 1,
          duration: Dim.fast,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: Dim.fast,
            height: height,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? Dim.m : Dim.l),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: isPrimary && enabled
                  ? LinearGradient(
                      colors: [accent.withValues(alpha: 0.96), accent.withValues(alpha: 0.72)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isPrimary
                  ? (enabled ? null : Palette.surfaceHigh)
                  : accent.withValues(alpha: enabled ? 0.10 : 0.04),
              border: Border.all(
                color: isPrimary
                    ? Colors.transparent
                    : accent.withValues(alpha: enabled ? 0.42 : 0.14),
              ),
              boxShadow: isPrimary && enabled && !_down
                  ? [BoxShadow(color: accent.withValues(alpha: 0.34), blurRadius: 22, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// Circular icon-only control used for navigation and HUD affordances.
class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.accent,
    this.filled = false,
    this.tooltip,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? accent;
  final bool filled;
  final String? tooltip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? Palette.textSecondary;
    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? tint.withValues(alpha: 0.16) : Palette.surfaceRaised.withValues(alpha: 0.7),
          border: Border.all(color: filled ? tint.withValues(alpha: 0.5) : Palette.hairline),
        ),
        child: Icon(icon, size: size * 0.44, color: filled ? tint : Palette.textSecondary),
      ),
    );

    if (badge != null) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Palette.lava,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Palette.ink, width: 1.5),
              ),
              child: Text(
                badge!,
                style: AppText.eyebrow.copyWith(color: Colors.white, fontSize: 9, letterSpacing: 0),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip != null) return Tooltip(message: tooltip!, child: button);
    return button;
  }
}

/// Small pill used for tags, filters and read-only facts.
class Chip2 extends StatelessWidget {
  const Chip2({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Palette.lava;
    final pill = AnimatedContainer(
      duration: Dim.fast,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 11, vertical: dense ? 4 : 6.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: selected ? tint.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: selected ? tint.withValues(alpha: 0.62) : Palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: selected ? tint : Palette.textMuted),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppText.label.copyWith(
              fontSize: dense ? 10.5 : 11.5,
              color: selected ? tint : Palette.textSecondary,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }
}
