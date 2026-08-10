import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'conduit/core/trace.dart';
import 'conduit/flow_router.dart';
import 'conduit/pages/basalt_portal.dart';
import 'core/app_config.dart';
import 'core/design/app_theme.dart';
import 'screens/loading_screen.dart';
import 'state/audio_service.dart';
import 'state/game_state.dart';
import 'state/save_service.dart';
import 'state/settings_state.dart';

/// Lets a notification tapped while the app is running open its destination
/// without threading a context through the pipeline.
final GlobalKey<NavigatorState> appNavigator = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Notifications are a bonus, not a prerequisite. A failure here must leave
  // the rest of the launch — including attribution — completely unaffected.
  try {
    await Firebase.initializeApp();
  } on Object catch (error) {
    trace('boot', 'messaging unavailable: $error');
  }

  flowRouter.signals.onToken = (token) => flowRouter.resendWithToken(token);
  flowRouter.signals.onAddress = _openFromNotification;

  // Reading the save file is the only thing that must happen before the first
  // frame; everything else is reported by the loading screen.
  final save = await SaveService.open();
  final settings = SettingsState(save);

  runApp(
    MultiProvider(
      providers: [
        Provider<SaveService>.value(value: save),
        ChangeNotifierProvider<SettingsState>.value(value: settings),
        ChangeNotifierProvider<GameState>(create: (_) => GameState(save)),
        Provider<AudioService>(
          create: (_) => AudioService(settings),
          dispose: (_, service) => service.dispose(),
          lazy: false,
        ),
      ],
      child: const LavawakeRushApp(),
    ),
  );
}

void _openFromNotification(String address) {
  final navigator = appNavigator.currentState;
  if (navigator == null) return;
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => BasaltPortal(
        address: address,
        rebootBuilder: (_) => const LoadingScreen(),
      ),
    ),
  );
}

class LavawakeRushApp extends StatelessWidget {
  const LavawakeRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      navigatorKey: appNavigator,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoadingScreen(),
      builder: (context, child) {
        // The game is designed against a fixed type scale; ignoring the system
        // font size keeps the landscape HUD from overflowing on any device.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 1,
          maxScaleFactor: 1,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
