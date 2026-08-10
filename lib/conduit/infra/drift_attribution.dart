import 'dart:async';
import 'dart:convert';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config/flow_settings.dart';
import '../core/trace.dart';
import 'client_stamp.dart';

/// Owns the attribution SDK and the tracking consent prompt.
///
/// Consent has its own memoised future, separate from the SDK start. Sharing
/// one future used to lose the prompt for an entire run: the SDK start is only
/// awaited once, so a request that the system swallowed — because the app was
/// not frontmost yet — was never attempted again.
class DriftAttribution {
  DriftAttribution({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  AppsflyerSdk? _sdk;
  String? _uid;

  final Map<String, dynamic> _collected = <String, dynamic>{};
  Completer<void>? _firstAnswer;

  Future<void>? _consentRun;
  Future<void>? _startRun;

  bool _reportedOrganic = false;

  Map<String, dynamic> get collected => Map<String, dynamic>.unmodifiable(_collected);

  // ── Tracking consent ─────────────────────────────────────────────────────

  Future<void> requestConsent() => _consentRun ??= _requestConsent();

  Future<void> _requestConsent() async {
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;

      await _waitUntilFrontmost();
      await Future<void>.delayed(FlowSettings.consentDelay);
      status = await AppTrackingTransparency.requestTrackingAuthorization();

      // The system answers with the current status and presents nothing when
      // the app is not frontmost. Still undetermined means nobody was asked.
      if (status == TrackingStatus.notDetermined) {
        await _waitUntilFrontmost();
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      trace('consent', 'status $status');
    } on Object catch (error) {
      trace('consent', 'unavailable: $error');
    }
  }

  Future<void> _waitUntilFrontmost() async {
    await WidgetsBinding.instance.endOfFrame;
    for (var attempt = 0; attempt < 24; attempt++) {
      final state = WidgetsBinding.instance.lifecycleState;
      // The platform reports the state late on a cold start, so an unknown
      // state counts as frontmost rather than blocking the prompt forever.
      if (state == null || state == AppLifecycleState.resumed) return;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<String?> advertisingId() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.authorized) return null;
      final id = await AppTrackingTransparency.getAdvertisingIdentifier();
      if (id.isEmpty || id.replaceAll(RegExp(r'[0\-]'), '').isEmpty) return null;
      return id;
    } on Object {
      return null;
    }
  }

  // ── SDK lifecycle ────────────────────────────────────────────────────────

  Future<void> start() => _startRun ??= _start();

  Future<void> _start() async {
    await requestConsent();
    _firstAnswer ??= Completer<void>();

    try {
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: FlowSettings.driftDevKey,
          appId: FlowSettings.storeNumber,
          showDebug: false,
          timeToWaitForATTUserAuthorization: 0,
          manualStart: true,
        ),
      );
      _sdk = sdk;

      sdk.onInstallConversionData(_onConversion);
      sdk.onAppOpenAttribution(_onReopen);
      sdk.onDeepLinking(_onDeepLink);

      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
      sdk.startSDK();
      _uid = await sdk.getAppsFlyerUID();
      trace('drift', 'uid $_uid');
    } on Object catch (error) {
      trace('drift', 'start failed: $error');
      _settle();
    }
  }

  void _onConversion(dynamic response) {
    final payload = _payloadOf(response);
    if (payload != null) {
      _collected.addAll(payload);
      _reportedOrganic = '${payload['af_status'] ?? ''}'.toLowerCase() == 'organic';
    }
    trace('drift', 'conversion ${_statusOf(response)} $payload');
    _settle();
  }

  void _onReopen(dynamic response) {
    final payload = _payloadOf(response);
    if (payload == null) return;
    // A re-open never overwrites what the install itself reported.
    payload.forEach((key, value) => _collected.putIfAbsent(key, () => value));
  }

  void _onDeepLink(dynamic result) {
    try {
      final click = (result as dynamic).deepLink?.clickEvent;
      if (click is Map) {
        click.forEach((key, value) => _collected.putIfAbsent('$key', () => value));
      }
    } on Object catch (error) {
      trace('drift', 'deep link unreadable: $error');
    }
  }

  Map<String, dynamic>? _payloadOf(dynamic response) {
    if (response is! Map) return null;
    final payload = response['payload'];
    if (payload is Map) return payload.map((key, value) => MapEntry('$key', value));
    return response.map((key, value) => MapEntry('$key', value));
  }

  String _statusOf(dynamic response) =>
      response is Map ? '${response['status'] ?? ''}' : '';

  void _settle() {
    final pending = _firstAnswer;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  /// Waits for the first attribution answer, then repairs the well-known
  /// false organic: the SDK reports organic for a paid install when its
  /// first-run timing is unlucky, and the backend would route that user to
  /// the game for good.
  Future<void> awaitSignals(Duration budget) async {
    await start();
    try {
      await (_firstAnswer?.future ?? Future<void>.value()).timeout(budget);
    } on TimeoutException {
      trace('drift', 'no attribution inside budget');
    }

    if (!_reportedOrganic) return;
    await Future<void>.delayed(const Duration(seconds: FlowSettings.organicRecheckSeconds));
    await _relookup();
  }

  Future<void> _relookup() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    final endpoint = Uri.parse(
      '${FlowSettings.driftLookupBase}/install_data/v5.0/'
      '${FlowSettings.storeReference}?device_id=$uid',
    );
    try {
      final response = await _client
          .get(
            endpoint,
            headers: <String, String>{
              'Authorization': 'Bearer ${FlowSettings.driftDevKey}',
              'Accept': 'application/json',
              'User-Agent': await ClientStamp.resolve(),
            },
          )
          .timeout(FlowSettings.relayTimeout);

      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final refreshed = decoded.map((key, value) => MapEntry('$key', value));
      if ('${refreshed['af_status'] ?? ''}'.toLowerCase() == 'organic') return;
      _collected.addAll(refreshed);
      _reportedOrganic = false;
      trace('drift', 'lookup corrected the organic answer');
    } on Object catch (error) {
      trace('drift', 'lookup failed: $error');
    }
  }

  /// The flat body the backend expects: everything the SDK produced, verbatim,
  /// with the device-side fields written last.
  Future<Map<String, dynamic>> buildBody({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{..._collected};

    final uid = _uid ?? await _readUid();
    if (uid != null && uid.isNotEmpty) body['af_id'] = uid;

    body['bundle_id'] = FlowSettings.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = FlowSettings.storeReference;
    body['locale'] = locale;

    // Both keys are omitted together while the token is missing: the backend
    // reads an empty string as "push is broken" rather than "not yet".
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = FlowSettings.signalProjectNumber;
    }

    final idfa = await advertisingId();
    if (idfa != null) body['sub_id_10'] = idfa;

    return body;
  }

  Future<String?> _readUid() async {
    try {
      return _uid = await _sdk?.getAppsFlyerUID();
    } on Object {
      return null;
    }
  }
}
