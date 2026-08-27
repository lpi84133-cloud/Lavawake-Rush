import Flutter
import UIKit

/// The only writer of a cold-tap push URL.
///
/// Firebase never sees this tap on UIScene — the scene receives it instead,
/// and by the time the Dart isolate is alive the information is gone. The
/// address is parked in user defaults under the bridged preferences prefix
/// so `LaunchTrail` can pick it up (it polls briefly because Flutter can
/// start before this callback).
///
/// `trailKey` must stay identical to `LaunchTrail._key`, `flutter.` prefix
/// included. Only `connectionOptions.notificationResponse` is used: that
/// object exists solely when the user actually tapped a notification.
class SceneDelegate: FlutterSceneDelegate {

  static let trailKey = "flutter.lvr_trail_link"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let response = connectionOptions.notificationResponse,
       let address = Self.address(in: response.notification.request.content.userInfo) {
      UserDefaults.standard.set(address, forKey: Self.trailKey)
      #if DEBUG
        NSLog("[LVR.trail] scene parked \(address)")
      #endif
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

    for branch in ["data", "payload", "fcm_options"] {
      if let nested = payload[branch] as? [AnyHashable: Any], let found = pick(nested) {
        return found
      }
    }
    return nil
  }
}
