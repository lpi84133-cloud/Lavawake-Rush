import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/app_config.dart';
import 'core/design/app_theme.dart';
import 'screens/loading_screen.dart';
import 'state/audio_service.dart';
import 'state/game_state.dart';
import 'state/save_service.dart';
import 'state/settings_state.dart';

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

class LavawakeRushApp extends StatelessWidget {
  const LavawakeRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
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
