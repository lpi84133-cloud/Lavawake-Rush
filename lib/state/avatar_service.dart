import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Picks a profile picture from the camera or the gallery and keeps a private
/// copy inside the app's documents directory.
///
/// The copy matters: gallery URIs and camera temp files are not guaranteed to
/// survive a restart, but the game has to be able to show the avatar offline
/// forever.
class AvatarService {
  const AvatarService();

  static const int _maxEdge = 720;

  Future<String?> pickFromCamera() => _pick(ImageSource.camera);

  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: _maxEdge.toDouble(),
        maxHeight: _maxEdge.toDouble(),
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null) return null;
      return _persist(picked);
    } on Object catch (error) {
      debugPrint('Avatar pick failed: $error');
      return null;
    }
  }

  Future<String> _persist(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatars = Directory('${dir.path}/avatars');
    if (!avatars.existsSync()) avatars.createSync(recursive: true);

    // A fresh filename each time avoids the image cache serving the old photo.
    final name = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = File('${avatars.path}/$name');
    await target.writeAsBytes(await picked.readAsBytes(), flush: true);

    for (final stale in avatars.listSync().whereType<File>()) {
      if (stale.path != target.path) {
        try {
          stale.deleteSync();
        } on Object catch (_) {
          // A locked leftover file is not worth failing the whole pick over.
        }
      }
    }
    return target.path;
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on Object catch (error) {
      debugPrint('Avatar delete failed: $error');
    }
  }
}
