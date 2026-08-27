import Flutter
import UIKit

/// AppDelegate is intentionally not a `UNUserNotificationCenterDelegate` and
/// does not park a push URL. On UIScene apps a silent / background wake can
/// still arrive in `launchOptions[.remoteNotification]`; writing that into
/// UserDefaults leaves a stale one-shot address for the next icon tap.
///
/// Cold-tap capture lives only in `SceneDelegate.scene(_:willConnectTo:)`:
/// a real user tap is the only thing that populates
/// `connectionOptions.notificationResponse`. Warm taps go through
/// `FirebaseMessaging.onMessageOpenedApp` in Dart.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Without this the platform token never arrives, and the Firebase token
    // that depends on it stays nil for the whole run.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
