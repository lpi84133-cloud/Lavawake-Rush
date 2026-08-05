import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Decoded images kept in memory for the duration of a run.
///
/// The renderer draws straight onto a `Canvas`, so it needs `ui.Image` handles
/// rather than widgets. Everything is decoded once during the loading screen and
/// during the pre-run brief, which keeps the first seconds of gameplay smooth.
class SpriteCache {
  SpriteCache._();

  static final SpriteCache instance = SpriteCache._();

  final Map<String, ui.Image> _images = {};
  final Map<String, Future<ui.Image>> _pending = {};

  ui.Image? get(String path) => _images[path];

  bool has(String path) => _images.containsKey(path);

  Future<ui.Image> load(String path, {int? targetHeight}) {
    final cached = _images[path];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(path, () async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetHeight: targetHeight,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      _images[path] = frame.image;
      _pending.remove(path);
      return frame.image;
    });
  }

  /// Loads a batch, reporting `0..1` progress. Individual failures are ignored so
  /// a single bad asset can never stall the boot sequence.
  Future<void> loadAll(
    Iterable<String> paths, {
    int? targetHeight,
    void Function(double progress)? onProgress,
  }) async {
    final list = paths.toList();
    if (list.isEmpty) {
      onProgress?.call(1);
      return;
    }
    var done = 0;
    for (final path in list) {
      try {
        await load(path, targetHeight: targetHeight);
      } on Object catch (error) {
        debugPrint('Sprite load failed for $path: $error');
      }
      done++;
      onProgress?.call(done / list.length);
    }
  }

  void evict(Iterable<String> paths) {
    for (final path in paths) {
      _images.remove(path)?.dispose();
    }
  }
}
