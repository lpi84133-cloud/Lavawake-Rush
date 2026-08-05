import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'save_service.dart';

enum GraphicsQuality { performance, balanced, cinematic }

extension GraphicsQualityInfo on GraphicsQuality {
  String get label => switch (this) {
    GraphicsQuality.performance => 'Performance',
    GraphicsQuality.balanced => 'Balanced',
    GraphicsQuality.cinematic => 'Cinematic',
  };

  String get blurb => switch (this) {
    GraphicsQuality.performance => 'Fewest particles, steadiest frame rate.',
    GraphicsQuality.balanced => 'The intended look on most phones.',
    GraphicsQuality.cinematic => 'Every ember and glow layer enabled.',
  };

  /// Multiplier applied to particle budgets in the renderer.
  double get particleScale => switch (this) {
    GraphicsQuality.performance => 0.45,
    GraphicsQuality.balanced => 1.0,
    GraphicsQuality.cinematic => 1.6,
  };
}

enum ControlScheme { drag, lanes }

extension ControlSchemeInfo on ControlScheme {
  String get label => switch (this) {
    ControlScheme.drag => 'Free drag',
    ControlScheme.lanes => 'Three lanes',
  };

  String get blurb => switch (this) {
    ControlScheme.drag => 'The flow follows your finger anywhere in the channel.',
    ControlScheme.lanes => 'Tap or swipe to snap between three fixed lanes.',
  };
}

class SettingsState extends ChangeNotifier {
  SettingsState(this._save) {
    final data = _save.readSettings();
    _music = (data['music'] as num?)?.toDouble() ?? 0.45;
    _sfx = (data['sfx'] as num?)?.toDouble() ?? 0.8;
    _haptics = data['haptics'] as bool? ?? true;
    _screenShake = data['screenShake'] as bool? ?? true;
    _showTips = data['showTips'] as bool? ?? true;
    _leftHanded = data['leftHanded'] as bool? ?? false;
    _quality = GraphicsQuality.values[(data['quality'] as int? ?? 1).clamp(0, 2)];
    _controls = ControlScheme.values[(data['controls'] as int? ?? 0).clamp(0, 1)];
  }

  final SaveService _save;

  late double _music;
  late double _sfx;
  late bool _haptics;
  late bool _screenShake;
  late bool _showTips;
  late bool _leftHanded;
  late GraphicsQuality _quality;
  late ControlScheme _controls;

  double get music => _music;
  double get sfx => _sfx;
  bool get haptics => _haptics;
  bool get screenShake => _screenShake;
  bool get showTips => _showTips;
  bool get leftHanded => _leftHanded;
  GraphicsQuality get quality => _quality;
  ControlScheme get controls => _controls;

  set music(double value) {
    _music = value.clamp(0, 1);
    _commit();
  }

  set sfx(double value) {
    _sfx = value.clamp(0, 1);
    _commit();
  }

  set haptics(bool value) {
    _haptics = value;
    _commit();
  }

  set screenShake(bool value) {
    _screenShake = value;
    _commit();
  }

  set showTips(bool value) {
    _showTips = value;
    _commit();
  }

  set leftHanded(bool value) {
    _leftHanded = value;
    _commit();
  }

  set quality(GraphicsQuality value) {
    _quality = value;
    _commit();
  }

  set controls(ControlScheme value) {
    _controls = value;
    _commit();
  }

  void restoreDefaults() {
    _music = 0.45;
    _sfx = 0.8;
    _haptics = true;
    _screenShake = true;
    _showTips = true;
    _leftHanded = false;
    _quality = GraphicsQuality.balanced;
    _controls = ControlScheme.drag;
    _commit();
  }

  void tick() {
    if (_haptics) HapticFeedback.selectionClick();
  }

  void thud() {
    if (_haptics) HapticFeedback.mediumImpact();
  }

  void _commit() {
    notifyListeners();
    _save.writeSettings({
      'music': _music,
      'sfx': _sfx,
      'haptics': _haptics,
      'screenShake': _screenShake,
      'showTips': _showTips,
      'leftHanded': _leftHanded,
      'quality': _quality.index,
      'controls': _controls.index,
    });
  }
}
