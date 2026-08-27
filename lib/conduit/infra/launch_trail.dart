import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/trace.dart';

/// Reads the address captured by `SceneDelegate` when a notification launched
/// a terminated app.
///
/// On UIScene the Dart isolate can start before
/// `scene(_:willConnectTo:options:)` has written the URL, so a single
/// `getString` races and returns null — the router then falls through to the
/// cached WebView page. The reader therefore reloads preferences and retries
/// for ~400 ms (8 × 50 ms). The value is one-shot: the first successful read
/// deletes the key, so a later launch cannot replay an old notification.
///
/// The key must stay identical to `SceneDelegate.trailKey`, including the
/// `flutter.` prefix that bridges user defaults to preferences.
class LaunchTrail {
  const LaunchTrail._();

  static const String _key = 'lvr_trail_link';
  static const int _attempts = 8;
  static const Duration _step = Duration(milliseconds: 50);

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (var attempt = 0; attempt < _attempts; attempt++) {
        await prefs.reload();
        final address = prefs.getString(_key)?.trim();
        if (address != null && address.isNotEmpty) {
          await prefs.remove(_key);
          trace('trail', 'consumed $address');
          return address;
        }
        if (attempt < _attempts - 1) {
          await Future<void>.delayed(_step);
        }
      }
      return null;
    } on Object catch (error) {
      trace('trail', 'unreadable: $error');
      return null;
    }
  }
}
