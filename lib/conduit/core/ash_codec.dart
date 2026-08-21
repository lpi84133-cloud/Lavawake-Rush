import 'dart:convert';
import 'dart:typed_data';

/// At-rest obfuscation for operational values (endpoint, attribution key,
/// client stamp fragments).
///
/// Every payload byte is XOR-ed against a rolling 32-bit state that mixes in
/// both the position AND the previous plaintext byte. The self-feedback means
/// the mask for byte `n` depends on every plaintext byte before it, so two
/// blobs that share a prefix diverge as soon as any byte differs. That is
/// intentional — a linear position-only XOR would look identical in shape to
/// the codec used by every other sibling in the portfolio.
///
/// It is NOT a content-protection cipher; the only job is to keep casual
/// `strings` / `class-dump` sweeps from surfacing the endpoint and the
/// attribution key. Public URLs (privacy, support) stay plaintext in
/// `AppConfig` — packing something that already lives in App Store Connect
/// protects nothing.
class AshCodec {
  const AshCodec._();

  // 32-bit mixing constants. `_projectSeed` must be unique per project;
  // rotating it invalidates every existing encoded blob and forces a
  // regeneration via `dart run tool/encode_flow_values.dart`.
  static const int _mixPrime = 0x01000193;
  static const int _mixOffset = 0x811c9dc5;
  static const int _projectSeed = 0x1a4c5aa3;
  static const int _mask32 = 0xffffffff;

  static String reveal(String packed) {
    if (packed.isEmpty) return '';
    return utf8.decode(_decode(base64Decode(packed)));
  }

  /// Encoder half — used only by `tool/encode_flow_values.dart` and by tests.
  static String conceal(String plain) =>
      base64Encode(_encode(utf8.encode(plain)));

  static Uint8List _decode(List<int> cipher) {
    final out = Uint8List(cipher.length);
    var seed = (_mixOffset ^ _projectSeed) & _mask32;
    for (var i = 0; i < cipher.length; i++) {
      seed = ((seed ^ i) * _mixPrime) & _mask32;
      final key = (seed >> 8) & 0xff;
      out[i] = cipher[i] ^ key;
      seed = ((seed ^ out[i]) * _mixPrime) & _mask32;
    }
    return out;
  }

  static Uint8List _encode(List<int> plain) {
    final out = Uint8List(plain.length);
    var seed = (_mixOffset ^ _projectSeed) & _mask32;
    for (var i = 0; i < plain.length; i++) {
      seed = ((seed ^ i) * _mixPrime) & _mask32;
      final key = (seed >> 8) & 0xff;
      out[i] = plain[i] ^ key;
      seed = ((seed ^ plain[i]) * _mixPrime) & _mask32;
    }
    return out;
  }
}
