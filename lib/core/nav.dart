import 'package:flutter/material.dart';

import 'design/app_theme.dart';

/// Shared fade-and-lift transition so moving between screens feels like one app.
Route<T> fadeThrough<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: Dim.normal,
  reverseTransitionDuration: Dim.fast,
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  },
);

Future<T?> goTo<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(fadeThrough<T>(page));
