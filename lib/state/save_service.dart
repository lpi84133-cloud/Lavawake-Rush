import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin JSON-blob persistence on top of `SharedPreferences`.
///
/// Everything the game needs lives on the device, so the app is fully playable
/// with no network at any point.
class SaveService {
  SaveService(this._prefs);

  static const String _progressKey = 'lavawake.progress.v1';
  static const String _settingsKey = 'lavawake.settings.v1';

  final SharedPreferences _prefs;

  static Future<SaveService> open() async => SaveService(await SharedPreferences.getInstance());

  Map<String, dynamic> readProgress() => _read(_progressKey);

  Map<String, dynamic> readSettings() => _read(_settingsKey);

  Future<void> writeProgress(Map<String, dynamic> data) => _prefs.setString(_progressKey, jsonEncode(data));

  Future<void> writeSettings(Map<String, dynamic> data) => _prefs.setString(_settingsKey, jsonEncode(data));

  Future<void> wipeProgress() => _prefs.remove(_progressKey);

  Map<String, dynamic> _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      // A corrupt blob should never brick the app; start fresh instead.
      return <String, dynamic>{};
    }
  }
}
