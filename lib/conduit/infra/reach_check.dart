import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Two-step reachability.
///
/// The interface check is separate on purpose: while the radio is off a name
/// lookup blocks for seconds, and every one of those seconds is spent showing
/// the user a screen that looks frozen. A reported-down interface is an
/// immediate answer, and only an interface that claims to be up is worth
/// confirming against a real route.
class ReachCheck {
  const ReachCheck._();

  static const List<String> _probeHosts = <String>['one.one.one.one', 'apple.com'];
  static const Duration _probeBudget = Duration(milliseconds: 1400);

  static Future<bool> interfaceUp() async {
    try {
      final state = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(milliseconds: 900));
      return state.any((entry) => entry != ConnectivityResult.none);
    } on Object {
      // Assume an interface exists and let the route check decide.
      return true;
    }
  }

  static Future<bool> routeUp() async {
    if (!await interfaceUp()) return false;
    for (final host in _probeHosts) {
      try {
        final found = await InternetAddress.lookup(host).timeout(_probeBudget);
        if (found.isNotEmpty && found.first.rawAddress.isNotEmpty) return true;
      } on Object {
        // Try the next host before declaring offline: a single blocked
        // resolver must not fail an otherwise healthy connection.
      }
    }
    return false;
  }
}
