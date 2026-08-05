import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'palette.dart';

/// Shared spacing / radius / motion scale.
///
/// Every screen composes from these so the layouts can differ wildly while
/// still feeling like one product.
class Dim {
  const Dim._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 14;
  static const double l = 22;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusS = 10;
  static const double radiusM = 16;
  static const double radiusL = 24;
  static const double radiusXl = 34;

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 520);

  static BorderRadius brS = BorderRadius.circular(radiusS);
  static BorderRadius brM = BorderRadius.circular(radiusM);
  static BorderRadius brL = BorderRadius.circular(radiusL);
  static BorderRadius brXl = BorderRadius.circular(radiusXl);
}

/// Typography helpers. `Sora` carries display copy, `Manrope` carries UI text.
class AppText {
  const AppText._();

  static const String display = 'Sora';
  static const String body = 'Manrope';

  static const TextStyle hero = TextStyle(
    fontFamily: display,
    fontSize: 40,
    height: 1.04,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    color: Palette.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: display,
    fontSize: 24,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    color: Palette.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: display,
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: Palette.textPrimary,
  );

  static const TextStyle body16 = TextStyle(
    fontFamily: body,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: Palette.textSecondary,
  );

  static const TextStyle body14 = TextStyle(
    fontFamily: body,
    fontSize: 13.5,
    height: 1.42,
    fontWeight: FontWeight.w500,
    color: Palette.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: body,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: Palette.textPrimary,
  );

  /// Wide, small, upper-case labels used for section eyebrows and tags.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: body,
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.8,
    color: Palette.textMuted,
  );

  static const TextStyle numeric = TextStyle(
    fontFamily: display,
    fontSize: 26,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    fontFeatures: [FontFeature.tabularFigures()],
    color: Palette.textPrimary,
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.lava,
    onPrimary: Colors.white,
    secondary: Palette.ember,
    onSecondary: Palette.voidBlack,
    surface: Palette.surface,
    onSurface: Palette.textPrimary,
    error: Palette.danger,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.ink,
    fontFamily: AppText.body,
    splashFactory: InkSparkle.splashFactory,
    canvasColor: Palette.surface,
    dividerColor: Palette.hairline,
    textTheme: const TextTheme(
      displayLarge: AppText.hero,
      headlineMedium: AppText.title,
      titleMedium: AppText.subtitle,
      bodyLarge: AppText.body16,
      bodyMedium: AppText.body14,
      labelLarge: AppText.label,
      labelSmall: AppText.eyebrow,
    ),
    iconTheme: const IconThemeData(color: Palette.textSecondary, size: 20),
    sliderTheme: SliderThemeData(
      activeTrackColor: Palette.lava,
      inactiveTrackColor: Palette.hairlineStrong,
      thumbColor: Palette.lavaBright,
      overlayColor: Palette.lava.withValues(alpha: 0.14),
      trackHeight: 4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Palette.lavaBright : Palette.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.lava.withValues(alpha: 0.35)
            : Palette.surfaceHigh,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Palette.hairline),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: Palette.surfaceHigh, borderRadius: Dim.brS),
      textStyle: AppText.body14.copyWith(color: Palette.textPrimary),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
