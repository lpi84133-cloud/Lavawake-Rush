import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lavawake_rush/core/design/app_theme.dart';
import 'package:lavawake_rush/screens/main_menu_screen.dart';
import 'package:lavawake_rush/state/audio_service.dart';
import 'package:lavawake_rush/state/game_state.dart';
import 'package:lavawake_rush/state/save_service.dart';
import 'package:lavawake_rush/state/settings_state.dart';

/// The hub packs a fixed grid and a branding column into whatever height the
/// device gives it, and nothing on it scrolls. Adding the weekly-event banner
/// ate into that budget, so the sizes it has to survive are pinned here.
void main() {
  Future<(GameState, AudioService)> freshState() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final save = SaveService(await SharedPreferences.getInstance());
    final game = GameState(save)..refreshEventIfNeeded();
    // The hub resolves the audio service during build, so it has to be in the
    // tree even though nothing here taps anything.
    return (game, AudioService(SettingsState(save)));
  }

  Future<void> renderAt(
    WidgetTester tester,
    (GameState, AudioService) state,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: state.$1),
          Provider<AudioService>.value(value: state.$2),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const MainMenuScreen()),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  final sizes = <String, Size>{
    'landscape phone': Size(852, 393),
    'small landscape phone': Size(736, 414),
    'tablet': Size(1180, 820),
    'wide tablet': Size(1366, 1024),
  };

  sizes.forEach((name, size) {
    testWidgets('fits a $name with the event banner', (tester) async {
      final state = await freshState();
      await renderAt(tester, state, size);

      expect(tester.takeException(), isNull);
      expect(find.text(state.$1.activeEvent.name), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
