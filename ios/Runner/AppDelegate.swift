import Flutter
import UIKit
import UserNotifications

/// Cold-tap capture is split across two callbacks:
///
///   1. `SceneDelegate.scene(_:willConnectTo:options:)` — the modern route.
///      `connectionOptions.notificationResponse` carries the payload when
///      the FCM AppDelegate proxy did not swallow it first.
///   2. `application(_:didFinishLaunchingWithOptions:)` — legacy pre-UIScene
///      fallback. In scene-based apps `launchOptions[.remoteNotification]`
///      is `nil`, so this path is effectively a no-op today, but the
///      early-parking behaviour is kept in case a future iOS version routes
///      the payload through this callback again.
///
/// A previous revision also parked the URL from
/// `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:…)`,
/// but that method fires on every tap, including ones handled while the
/// app is alive (background → foreground). Its write survived a kill and
/// the next launch replayed a one-shot push URL through `_returningPortal`
/// — the exact "special screen reopens on relaunch" QA regression. In-app
/// taps are already handled by `FirebaseMessaging.onMessageOpenedApp` /
/// `EmberSignals.onAddress`, so nothing valuable is lost by dropping the
/// override. Missed cold taps are still caught by
/// `FirebaseMessaging.getInitialMessage()` inside
/// `FlowRouter._consumeColdTap`.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Without this the platform token never arrives, and the Firebase token
    // that depends on it stays nil for the whole run.
    application.registerForRemoteNotifications()

    let bootstrapped = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Legacy cold-start payload. Empty in scene-based apps but harmless.
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      Self.parkTrail(from: payload, source: "launchOptions")
    }
    return bootstrapped
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - Trail parking

  /// Extracts the destination URL from the notification payload (see
  /// `SceneDelegate.address(in:)` for the recognised keys) and parks it in
  /// user defaults under the bridged preferences prefix. `LaunchTrail`
  /// reads it exactly once on boot and deletes it right after. Only cold
  /// callbacks should call this — see the class-level doc for why.
  static func parkTrail(from payload: [AnyHashable: Any], source: String) {
    guard let address = SceneDelegate.address(in: payload) else {
      #if DEBUG
        NSLog("[LVR.trail] \(source) had no URL in payload")
      #endif
      return
    }
    UserDefaults.standard.set(address, forKey: SceneDelegate.trailKey)
    #if DEBUG
      NSLog("[LVR.trail] \(source) parked \(address)")
    #endif
  }
}
