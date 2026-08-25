import 'package:shared_preferences/shared_preferences.dart';

import '../core/trace.dart';

/// Reads the address captured by `SceneDelegate` when a notification launched
/// a terminated app.
///
/// Firebase never sees that tap — the scene delegate receives it instead — so
/// the native side parks the address in user defaults and this is where the
/// Dart side picks it up. The value is one-shot: reading it clears it, so a
/// later launch cannot replay an old notification.
///
/// The key must stay identical to `SceneDelegate.trailKey`, including the
/// `flutter.` prefix that bridges user defaults to preferences.
class LaunchTrail {
  const LaunchTrail._();

  static const String _key = 'lvr_trail_link';

  /// True once the scene-delegate address has been consumed in this process.
  /// Reset only by a full app restart. Callers on the messaging side use it
  /// to skip `getInitialMessage`, which on iOS occasionally returns a
  /// different notification than the one the user actually tapped when a
  /// stack of pushes is delivered simultaneously — firing our navigation
  /// callback with that wrong address is what caused the "opens the start
  /// page" bug.
  static bool _consumedInSession = false;
  static bool get consumedInSession => _consumedInSession;

  static Future<String?> consume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(_key);
      if (address == null || address.isEmpty) return null;

      await prefs.remove(_key);
      _consumedInSession = true;
      trace('trail', 'consumed $address');
      return address;
    } on Object catch (error) {
      trace('trail', 'unreadable: $error');
      return null;
    }
  }
}
