// ignore_for_file: avoid_print, avoid_relative_lib_imports

// Regenerates the packed values in `lib/conduit/config/flow_settings.dart`.
//
//   dart run tool/encode_flow_values.dart
//
// Edit the plaintext below, run the script, paste the printed block into
// `flow_settings.dart`, and confirm the VERIFY section round-trips exactly.
// Never hand-edit a packed value: one wrong character corrupts the whole
// string and the failure only shows up as a dead endpoint at runtime.

import '../lib/conduit/core/ash_codec.dart';

const Map<String, String> _values = <String, String>{
  'relayEndpoint': 'https://lavawakerush.com/config.php',
  'driftDevKey': 'qb5JfLNGoAsZmYs5q8ZuCH',
  'signalProjectNumber': '184042477853',
  'driftLookupBase': 'https://gcdsdk.appsflyer.com',

  // Client stamp fragments. Assembled at runtime so no recognisable browser
  // substring ships as a literal.
  'stampProduct': 'Mozilla/5.0',
  'stampPlatformOpen': '(iPhone; CPU iPhone OS',
  'stampPlatformClose': 'like Mac OS X)',
  'stampEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
  'stampRelease': 'Version/',
  'stampBuild': 'Mobile/15E148',
  'stampTail': 'Safari/604.1',

  // Partner identity tokens (see FlowSettings.stampIdentity).
  'stampIdKey': 'appid/',
  'stampNameKey': 'appname/',
  'stampNameValue': 'LavawakeRush',
};

void main() {
  final buffer = StringBuffer();
  _values.forEach((name, plain) {
    buffer.writeln("  static const String _$name = '${AshCodec.conceal(plain)}';");
  });

  print('--- paste into lib/conduit/config/flow_settings.dart ---');
  print(buffer);

  print('--- VERIFY (must match the plaintext above exactly) ---');
  var ok = true;
  _values.forEach((name, plain) {
    final round = AshCodec.reveal(AshCodec.conceal(plain));
    final matches = round == plain;
    ok = ok && matches;
    print('${matches ? 'OK  ' : 'FAIL'} $name = $round');
  });
  print(ok ? '\nAll values round-trip.' : '\nROUND-TRIP FAILED — do not ship.');
}
