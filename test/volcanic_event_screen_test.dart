import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lavawake_rush/core/design/app_theme.dart';
import 'package:lavawake_rush/screens/volcanic_event_screen.dart';
import 'package:lavawake_rush/state/game_state.dart';
import 'package:lavawake_rush/state/save_service.dart';

/// The event screen switches between a two-column and a single-scroll layout,
/// and the two need different flex rules. Rendering both at real device sizes
/// is the only thing that catches an overflow before a player does.
void main() {
  Future<GameState> freshState() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return GameState(SaveService(await SharedPreferences.getInstance()));
  }

  Future<void> renderAt(
    WidgetTester tester,
    GameState game,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<GameState>.value(
        value: game,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const VolcanicEventScreen(),
        ),
      ),
    );

    // The backdrop animates forever, so the frames are pumped by hand rather
    // than settled.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('lays out on a landscape phone without overflowing', (tester) async {
    final game = await freshState();
    await renderAt(tester, game, const Size(852, 393));

    expect(tester.takeException(), isNull);
    expect(find.text(game.activeEvent.tagline), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lays out on a wide tablet without overflowing', (tester) async {
    final game = await freshState();
    await renderAt(tester, game, const Size(1366, 1024));

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lays out in the narrow single-column fallback', (tester) async {
    final game = await freshState();
    // Narrow enough to trip the < 720 branch, where the briefing must wrap its
    // content instead of claiming a Spacer.
    await renderAt(tester, game, const Size(640, 900));

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows the live event and its objectives', (tester) async {
    final game = await freshState();
    game.refreshEventIfNeeded();
    await renderAt(tester, game, const Size(1180, 820));

    expect(tester.takeException(), isNull);
    expect(game.eventQuests, isNotEmpty);
    for (final quest in game.eventQuests) {
      expect(find.text(quest.def.title), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
