import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/asset_catalog.dart';
import 'settings_state.dart';

/// Fire-and-forget sound effects plus one looping music bed.
///
/// Everything is bundled with the app, so audio never depends on the network.
/// Failures are swallowed: a device that refuses to play audio should not take
/// the game with it.
class AudioService {
  AudioService(this._settings) {
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsState _settings;
  final AudioPlayer _music = AudioPlayer(playerId: 'lavawake.music');
  final List<AudioPlayer> _pool = [
    for (var i = 0; i < 4; i++) AudioPlayer(playerId: 'lavawake.sfx.$i'),
  ];

  int _next = 0;
  String? _currentLoop;
  bool _ready = false;

  Future<void> warmUp() async {
    if (_ready) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      for (final player in _pool) {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
      }
      _ready = true;
    } on Exception catch (error) {
      debugPrint('Audio warm-up skipped: $error');
    }
  }

  void play(String asset) {
    if (!_ready || _settings.sfx <= 0.01) return;
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    player
        .play(AssetSource(asset), volume: _settings.sfx)
        .catchError((Object error) => debugPrint('SFX failed: $error'));
  }

  void tap() => play(Sfx.tap);
  void back() => play(Sfx.back);
  void confirm() => play(Sfx.confirm);
  void cancel() => play(Sfx.cancel);
  void openPanel() => play(Sfx.menuOpen);
  void closePanel() => play(Sfx.menuClose);
  void toggle() => play(Sfx.toggle);
  void reward() => play(Sfx.reward);
  void unlock() => play(Sfx.unlock);
  void error() => play(Sfx.error);
  void transition() => play(Sfx.transition);

  Future<void> loop(String asset) async {
    if (!_ready || _currentLoop == asset) return;
    _currentLoop = asset;
    try {
      await _music.stop();
      if (_settings.music <= 0.01) return;
      await _music.setVolume(_settings.music);
      await _music.play(AssetSource(asset), volume: _settings.music);
    } on Exception catch (error) {
      debugPrint('Music failed: $error');
    }
  }

  Future<void> stopLoop() async {
    _currentLoop = null;
    try {
      await _music.stop();
    } on Exception catch (_) {
      // Nothing to recover: the loop is already silent.
    }
  }

  void _onSettingsChanged() {
    if (!_ready) return;
    if (_settings.music <= 0.01) {
      _music.stop();
    } else {
      _music.setVolume(_settings.music);
      final loopAsset = _currentLoop;
      if (loopAsset != null && _music.state != PlayerState.playing) {
        _music.play(AssetSource(loopAsset), volume: _settings.music);
      }
    }
  }

  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _music.dispose();
    for (final player in _pool) {
      player.dispose();
    }
  }
}
