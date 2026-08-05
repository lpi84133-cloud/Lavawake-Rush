import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lavawake_rush/core/design/app_theme.dart';

void main() {
  testWidgets('theme builds without error', (tester) async {
    final theme = buildAppTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Center(child: Text('Lavawake Rush'))),
      ),
    );
    expect(find.text('Lavawake Rush'), findsOneWidget);
  });
}
