import 'package:flutter/material.dart';

import '../../core/design/palette.dart';

/// Button used by the two artwork screens of the delivery shell.
///
/// Kept separate from the game's own button so these screens can render
/// without pulling the game's services in behind them.
class FlowButton extends StatelessWidget {
  const FlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.subdued = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// A quieter treatment for the secondary choice. Still a full button with
  /// the same tap target — a faint text link reads as decoration and gets
  /// missed.
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final gradient = subdued
        ? <Color>[Palette.surfaceHigh, Palette.surfaceRaised]
        : Palette.lavaGradient;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: subdued ? Palette.hairlineStrong : Colors.white.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: (subdued ? Colors.black : Palette.lava).withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        // A flat line height keeps the label optically centred;
                        // the default leading drifts it downward.
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
