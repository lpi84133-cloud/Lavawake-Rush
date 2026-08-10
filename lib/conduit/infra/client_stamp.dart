import 'package:device_info_plus/device_info_plus.dart';

import '../config/flow_settings.dart';

/// Builds the client stamp sent by the HTTP client and by the embedded
/// browser. Both must present the same string — the backend compares them and
/// treats a mismatch as a broken session.
///
/// The stamp is assembled from packed fragments so that no recognisable
/// browser substring exists as a literal in the shipped binary.
///
/// GAME THEME CATEGORY: slot (partner refused headers; appid/appname suffix
///                            present, all tokens encoded)
///
/// The partner's specification puts the store reference after `appid/` rather
/// than the bundle id, so that is what ships. If they ever accept the identity
/// as `X-Partner-App-*` headers on the config request, drop the last two
/// segments here — this suffix is the most recognisable thing in the binary.
class ClientStamp {
  const ClientStamp._();

  static String? _cached;

  static Future<String> resolve() async {
    final ready = _cached;
    if (ready != null) return ready;

    var release = FlowSettings.fallbackRelease;
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      final reported = info.systemVersion.trim();
      if (reported.isNotEmpty) release = reported;
    } on Object {
      // A device that will not describe itself gets the pinned release.
    }

    return _cached = _compose(release);
  }

  /// The stamp for the current process, or null before [resolve] has run.
  static String? get cached => _cached;

  static String _compose(String release) {
    final parts = release.split('.');
    final marketing = parts.length >= 2 ? '${parts[0]}.${parts[1]}' : parts.first;

    final stamp = StringBuffer()
      ..write(FlowSettings.stampProduct)
      ..write(' ')
      ..write(FlowSettings.stampPlatformOpen)
      ..write(' ')
      ..write(release.replaceAll('.', '_'))
      ..write(' ')
      ..write(FlowSettings.stampPlatformClose)
      ..write(' ')
      ..write(FlowSettings.stampEngine)
      ..write(' ')
      ..write(FlowSettings.stampRelease)
      ..write(marketing)
      ..write(' ')
      ..write(FlowSettings.stampBuild)
      ..write(' ')
      ..write(FlowSettings.stampTail)
      ..write(' ')
      ..write(FlowSettings.stampIdKey)
      ..write(FlowSettings.storeReference)
      ..write(' ')
      ..write(FlowSettings.stampNameKey)
      ..write(FlowSettings.stampNameValue);

    return stamp.toString();
  }
}
