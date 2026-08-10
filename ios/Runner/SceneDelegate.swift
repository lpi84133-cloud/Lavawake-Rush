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
    if let response = connectionOptions.notificationResponse {
      store(SceneDelegate.address(in: response.notification.request.content.userInfo))
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  private func store(_ address: String?) {
    guard let address, !address.isEmpty else { return }
    UserDefaults.standard.set(address, forKey: SceneDelegate.trailKey)
    #if DEBUG
      print("[LVR.scene] captured \(address)")
    #endif
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

    for branch in ["data", "payload"] {
      if let nested = payload[branch] as? [AnyHashable: Any], let found = pick(nested) {
        return found
      }
    }
    return nil
  }
}
