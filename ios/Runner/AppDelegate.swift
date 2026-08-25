import Flutter
import UIKit
import UserNotifications

/// A push that launched a terminated app can be delivered through three
/// separate iOS callbacks depending on OS version and whether the Firebase
/// AppDelegate proxy is in the picture:
///
///   1. `SceneDelegate.scene(_:willConnectTo:options:)` — the modern route,
///      but `connectionOptions.notificationResponse` is `nil` in practice
///      whenever the FCM delegate proxy consumed the response first.
///   2. `application(_:didFinishLaunchingWithOptions:)` — `launchOptions`
///      carries the payload under `.remoteNotification` on OS versions that
///      still fall back to the pre-UIScene lifecycle for cold-start pushes.
///   3. `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:…)`
///      — every tap (foreground, background, and killed-state) is delivered
///      here once the app is running.
///
/// Any single one of them missing the payload is enough to send the router
/// to the previous session's saved OneLink URL instead of the URL the
/// notification actually pointed at. All three write the same address to
/// `UserDefaults[SceneDelegate.trailKey]`, which `LaunchTrail.consume()`
/// reads on boot; the `flutter.` prefix is what bridges the value to Dart's
/// `SharedPreferences`.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Without this the platform token never arrives, and the Firebase token
    // that depends on it stays nil for the whole run.
    application.registerForRemoteNotifications()

    // Third channel: whatever the OS routes through the UNUserNotificationCenter.
    // FCM sets its own delegate when the AppDelegate proxy is on, so we call
    // super first (populates the FCM chain) and then override the delegate to
    // ourselves; the FCM message-open callback still runs because it goes
    // through `messaging:didReceiveRegistrationToken:` and
    // `application:didReceiveRemoteNotification:` paths, not this delegate.
    let bootstrapped = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = self

    // Cold-start payload the OS handed us before the scene was even created.
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      Self.parkTrail(from: payload, source: "launchOptions")
    }
    return bootstrapped
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - UNUserNotificationCenterDelegate

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    Self.parkTrail(
      from: response.notification.request.content.userInfo,
      source: "didReceive"
    )
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  // MARK: - Trail parking

  /// Extracts the destination URL from the notification payload (see
  /// `SceneDelegate.address(in:)` for the recognised keys) and parks it in
  /// user defaults under the bridged preferences prefix. Callers pass a
  /// short `source` string for debug traces so field logs can tell which
  /// callback actually captured a given cold tap.
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
