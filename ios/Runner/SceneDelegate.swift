import Flutter
import UIKit

/// Catches the notification that launched a terminated app.
///
/// Firebase never sees this tap — the scene receives it instead, and by the
/// time the Dart isolate is alive the information is gone. The address is
/// parked in user defaults under the bridged preferences prefix so `LaunchTrail`
/// can pick it up as the very first thing the pipeline does.
///
/// `trailKey` must stay identical to `LaunchTrail._key`, `flutter.` prefix
/// included.
class SceneDelegate: FlutterSceneDelegate {

  static let trailKey = "flutter.lvr_trail_link"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // First channel of the cold-tap capture, see AppDelegate for the full
    // story. When the Firebase AppDelegate proxy is enabled this response
    // is often nil (FCM consumed it before the scene connects), but on
    // versions where it isn't we still get the fastest possible path.
    if let response = connectionOptions.notificationResponse {
      AppDelegate.parkTrail(
        from: response.notification.request.content.userInfo,
        source: "scene"
      )
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  /// Senders disagree on both the key and the nesting, so every shape we have
  /// received in practice is checked.
  static func address(in payload: [AnyHashable: Any]) -> String? {
    let keys = ["url", "link", "target", "deeplink", "deep_link"]

    func pick(_ source: [AnyHashable: Any]) -> String? {
      for key in keys {
        if let value = source[key] as? String, !value.isEmpty { return value }
      }
      return nil
    }

    if let direct = pick(payload) { return direct }

    // `fcm_options` is where Firebase Cloud Messaging v1 stores the web-URL
    // fallback (`fcm_options.link`). Missing it here was the reason a cold
    // tap on a push whose URL sat under that key silently fell through to
    // the saved OneLink address on next launch.
    for branch in ["data", "payload", "fcm_options"] {
      if let nested = payload[branch] as? [AnyHashable: Any], let found = pick(nested) {
        return found
      }
    }
    return nil
  }
}
