import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/audio_service.dart';
import '../../state/avatar_service.dart';
import '../../state/game_state.dart';
import '../design/app_theme.dart';
import '../design/palette.dart';
import 'buttons.dart';
import 'glass_panel.dart';

/// Bottom sheet offering camera capture, gallery pick, or removal of the current
/// profile picture. Shared by the onboarding flow and the profile screen.
Future<void> showAvatarPicker(BuildContext context) async {
  final game = context.read<GameState>();
  final audio = context.read<AudioService>();
  const service = AvatarService();

  audio.openPanel();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Palette.voidBlack.withValues(alpha: 0.66),
    isScrollControlled: true,
    builder: (sheetContext) {
      Future<void> apply(Future<String?> Function() pick) async {
        final previous = game.avatarPath;
        final path = await pick();
        if (path == null) {
          audio.cancel();
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          return;
        }
        if (previous != null && previous != path) await service.delete(previous);
        game.setProfile(avatar: path);
        audio.confirm();
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Dim.m),
          child: GlassPanel(
            padding: const EdgeInsets.all(Dim.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Profile picture', style: AppText.subtitle),
                const SizedBox(height: 4),
                Text(
                  'Take a new photo or choose one from your gallery. The image stays on this device.',
                  style: AppText.body14,
                ),
                const SizedBox(height: Dim.l),
                Row(
                  children: [
                    Expanded(
                      child: LavaButton(
                        label: 'Take photo',
                        icon: Icons.photo_camera_rounded,
                        expand: true,
                        onPressed: () => apply(service.pickFromCamera),
                      ),
                    ),
                    const SizedBox(width: Dim.m),
                    Expanded(
                      child: LavaButton(
                        label: 'From gallery',
                        icon: Icons.photo_library_rounded,
                        tone: ButtonTone.ghost,
                        expand: true,
                        onPressed: () => apply(service.pickFromGallery),
                      ),
                    ),
                  ],
                ),
                if (game.avatarPath != null) ...[
                  const SizedBox(height: Dim.m),
                  LavaButton(
                    label: 'Remove current picture',
                    icon: Icons.delete_outline_rounded,
                    tone: ButtonTone.danger,
                    expand: true,
                    onPressed: () async {
                      await service.delete(game.avatarPath);
                      game.clearAvatar();
                      audio.cancel();
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  audio.closePanel();
}
