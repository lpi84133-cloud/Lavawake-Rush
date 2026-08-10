import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/flow_settings.dart';
import '../models/drift_route.dart';

/// Persistence for the delivery pipeline.
///
/// Ordinary preferences hold the route and the invitation bookkeeping; the
/// destination itself lives in the keychain, because it is the one value worth
/// reading off a device.
class CrustVault {
  CrustVault({FlutterSecureStorage? secure})
    : _secure =
          secure ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          );

  final FlutterSecureStorage _secure;

  static const String _routeKey = 'lvr.flow.route';
  static const String _snoozeKey = 'lvr.flow.invite_snooze';
  static const String _refusedKey = 'lvr.flow.invite_refused';
  static const String _addressKey = 'lvr.flow.address';
  static const String _addressExpiryKey = 'lvr.flow.address_expiry';

  Future<DriftRoute> readRoute() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_routeKey)) {
      case 'portal':
        return DriftRoute.portal;
      case 'native':
        return DriftRoute.native;
      default:
        return DriftRoute.undecided;
    }
  }

  Future<void> writeRoute(DriftRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, route.name);
  }

  Future<void> saveAddress(String address, {int? expiresAt}) async {
    // Fall back to the local expiry window when the backend does not name one,
    // so a destination can never outlive its usefulness in the keychain.
    final fallback = DateTime.now()
        .add(const Duration(days: FlowSettings.savedRouteExpiryDays))
        .millisecondsSinceEpoch ~/
        1000;
    await _secure.write(key: _addressKey, value: address);
    await _secure.write(key: _addressExpiryKey, value: '${expiresAt ?? fallback}');
  }

  /// The stored destination, or null when absent or past its expiry.
  Future<String?> readAddress() async {
    final address = await _secure.read(key: _addressKey);
    if (address == null || address.isEmpty) return null;

    final rawExpiry = await _secure.read(key: _addressExpiryKey);
    final expiry = int.tryParse(rawExpiry ?? '');
    if (expiry == null) return address;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now >= expiry) {
      await clearAddress();
      return null;
    }
    return address;
  }

  Future<void> clearAddress() async {
    await _secure.delete(key: _addressKey);
    await _secure.delete(key: _addressExpiryKey);
  }

  Future<bool> inviteAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_refusedKey) ?? false) return false;

    final until = prefs.getInt(_snoozeKey) ?? 0;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= until;
  }

  Future<void> snoozeInvite() async {
    final prefs = await SharedPreferences.getInstance();
    final until =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + FlowSettings.inviteSnoozeSeconds;
    await prefs.setInt(_snoozeKey, until);
  }

  /// The system dialog is only offered once; a refusal there is permanent.
  Future<void> markInviteRefused() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_refusedKey, true);
  }
}
