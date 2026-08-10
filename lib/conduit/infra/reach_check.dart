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

  static const String _probeHost = 'one.one.one.one';
  static const Duration _probeBudget = Duration(seconds: 4);

  static Future<bool> interfaceUp() async {
    try {
      final state = await Connectivity().checkConnectivity();
      return state.any((entry) => entry != ConnectivityResult.none);
    } on Object {
      // Assume an interface exists and let the route check decide.
      return true;
    }
  }

  static Future<bool> routeUp() async {
    if (!await interfaceUp()) return false;
    try {
      final found = await InternetAddress.lookup(_probeHost).timeout(_probeBudget);
      return found.isNotEmpty && found.first.rawAddress.isNotEmpty;
    } on Object {
      return false;
    }
  }
}
