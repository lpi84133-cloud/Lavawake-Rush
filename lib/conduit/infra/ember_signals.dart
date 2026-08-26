import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../main.dart' show firebaseReady;
import '../config/flow_settings.dart';
import '../core/trace.dart';

/// Notification plumbing: registration, the token the backend needs to reach
/// this install, and the address carried by a tapped notification.
///
/// Banners in the foreground are left to the system. Drawing a second one
/// locally for the same message is the usual way to end up showing everything
/// twice.
class EmberSignals {
  EmberSignals();

  /// Lazy: `FirebaseMessaging.instance` reads through `Firebase.app()` and
  /// that call throws until `Firebase.initializeApp` settles. Because init
  /// now runs off to one side while the loading screen paints, the getter
  /// stays untouched until `bootstrap()` has already awaited `firebaseReady`.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  String? _token;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _opened;

  /// Fired when a token first becomes available after the pipeline already
  /// asked the backend without one.
  void Function(String token)? onToken;

  /// Fired when a notification is tapped while the app is alive.
  void Function(String address)? onAddress;

  String? get token => _token;

  Future<void> bootstrap() async {
    try {
      // Firebase.initializeApp() runs in parallel with the first frame so the
      // loading screen paints faster. Everything below reaches for a
      // FirebaseMessaging platform channel, so wait for the initialization to
      // land before touching it.
      await firebaseReady;
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _refresh ??= _messaging.onTokenRefresh.listen((value) {
        if (value.isEmpty || value == _token) return;
        _token = value;
        trace('signals', 'token refreshed');
        onToken?.call(value);
      });

      _opened ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final address = addressIn(message.data);
        if (address != null) onAddress?.call(address);
      });

      // Firebase's `getInitialMessage()` on iOS keeps returning the last
      // tapped notification across cold launches until it is explicitly
      // read once — the SDK does not clear the cached message on kill.
      // Using it as a routing source therefore made every plain relaunch
      // reopen the previous push URL (the exact QA regression), so the
      // cold-tap URL lives in a single place now: `SceneDelegate` →
      // `UserDefaults[flutter.lvr_trail_link]` → `LaunchTrail.consume()`.
      //
      // We still invoke `getInitialMessage()` once here — but discard the
      // result — to force Firebase to mark the cached message as consumed
      // so a subsequent launch never sees it again.
      try {
        await _messaging.getInitialMessage();
      } on Object catch (error) {
        trace('signals', 'getInitialMessage flush failed: $error');
      }

      await _collectToken(FlowSettings.tokenPollAttempts);
    } on Object catch (error) {
      trace('signals', 'bootstrap failed: $error');
    }
  }

  Future<bool> systemAllows() async {
    try {
      await firebaseReady;
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } on Object {
      return false;
    }
  }

  Future<bool> undecided() async {
    try {
      await firebaseReady;
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.notDetermined;
    } on Object {
      return false;
    }
  }

  Future<bool> askPermission() async {
    // Firebase throws outright if a second request overlaps the first.
    final running = _asking;
    if (running != null) return running;
    final attempt = _askPermission();
    _asking = attempt;
    try {
      return await attempt;
    } finally {
      _asking = null;
    }
  }

  Future<bool>? _asking;

  Future<bool> _askPermission() async {
    try {
      await firebaseReady;
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      // Registration takes noticeably longer right after a fresh grant.
      if (granted) {
        unawaited(_collectToken(FlowSettings.tokenPollAttemptsAfterConsent));
      }
      return granted;
    } on Object catch (error) {
      trace('signals', 'permission failed: $error');
      return false;
    }
  }

  /// The Firebase token stays null until APNs finishes registering, so the
  /// platform token is polled first and only then exchanged.
  Future<void> _collectToken(int attempts) async {
    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        final apns = await _messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) break;
        await Future<void>.delayed(FlowSettings.tokenPollStep);
      }

      final value = await _messaging.getToken();
      if (value == null || value.isEmpty || value == _token) return;
      _token = value;
      trace('signals', 'token ready');
      onToken?.call(value);
    } on Object catch (error) {
      trace('signals', 'token unavailable: $error');
    }
  }

  /// Digs the address out of a notification payload. Senders disagree on both
  /// the key and the nesting, so every shape we have seen is checked.
  static String? addressIn(Map<String, dynamic> data) {
    const keys = <String>['url', 'link', 'target', 'deeplink', 'deep_link'];

    String? pick(Map<dynamic, dynamic> source) {
      for (final key in keys) {
        final value = source[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final direct = pick(data);
    if (direct != null) return direct;

    // `fcm_options` is the FCM v1 API home for the web-URL fallback link
    // (`fcm_options.link`) — a push that carries the destination only under
    // that key would otherwise be missed here, and `FlowRouter._decide` would
    // fall back to the saved OneLink address instead of routing to the URL
    // the notification actually pointed at.
    for (final nested in <String>['data', 'payload', 'fcm_options']) {
      final branch = data[nested];
      if (branch is Map) {
        final found = pick(branch);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await _refresh?.cancel();
    await _opened?.cancel();
  }
}
