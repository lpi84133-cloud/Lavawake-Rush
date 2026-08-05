import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/screen_shell.dart';
import '../data/asset_catalog.dart';
import '../state/audio_service.dart';
import 'web_page_screen.dart';

/// About. A wordmark and studio note on the left, legal and support links plus
/// build facts on the right. Everything opens offline.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenShell(
      title: 'About',
      eyebrow: 'Lavawake Rush',
      accent: Palette.lava,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 48,
            child: GlassPanel(
              padding: const EdgeInsets.all(Dim.l),
              accent: Palette.lava,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(Art.wordmark, fit: BoxFit.contain),
                    ),
                  ),
                  Text(AppConfig.tagline, style: AppText.subtitle.copyWith(fontSize: 16)),
                  const SizedBox(height: Dim.s),
                  Text(
                    'Awaken a living lava flow, devour everything in the channel and grow through eight '
                    'evolution stages. Every run is shaped by the mutations you draft, the routes you take '
                    'and the perks you forge in the Crucible.',
                    style: AppText.body14,
                  ),
                  const SizedBox(height: Dim.m),
                  Row(
                    children: [
                      _Fact(label: 'Version', value: AppConfig.version),
                      const SizedBox(width: Dim.s),
                      _Fact(label: 'Play', value: 'Offline'),
                      const SizedBox(width: Dim.s),
                      _Fact(label: 'Mode', value: 'Landscape'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Dim.m),
          Expanded(
            flex: 52,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LinkTile(
                    title: 'Privacy Policy',
                    subtitle: 'How your data is handled - always available offline.',
                    icon: Icons.privacy_tip_outlined,
                    accent: Palette.frost,
                    onTap: () => _open(context, WebDocument.privacy),
                  ),
                  const SizedBox(height: Dim.s),
                  _LinkTile(
                    title: 'Support',
                    subtitle: 'Questions and requests. Reach us at ${AppConfig.supportEmail}.',
                    icon: Icons.support_agent_rounded,
                    accent: Palette.venom,
                    onTap: () => _open(context, WebDocument.support),
                  ),
                  const SizedBox(height: Dim.s),
                  GlassPanel(
                    padding: const EdgeInsets.all(Dim.s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('BUILD', style: AppText.eyebrow),
                        const SizedBox(height: Dim.xs),
                        _Row(label: 'App name', value: AppConfig.appName),
                        _Row(label: 'Bundle ID', value: AppConfig.bundleId),
                        _Row(label: 'App Store ID', value: AppConfig.appStoreId),
                        _Row(label: 'Version', value: AppConfig.version),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, WebDocument doc) {
    context.read<AudioService>().tap();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebPageScreen(document: doc)),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: Dim.brS,
          color: Palette.surfaceHigh.withValues(alpha: 0.5),
          border: Border.all(color: Palette.hairline),
        ),
        child: Column(
          children: [
            Text(value, style: AppText.label.copyWith(fontSize: 13)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: AppText.eyebrow.copyWith(fontSize: 8)),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(Dim.m),
      accent: accent,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: Dim.brS,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: Dim.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.subtitle.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Palette.textMuted),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideX(begin: 0.05, curve: Curves.easeOutCubic);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: AppText.body14.copyWith(fontSize: 11, color: Palette.textMuted)),
          const Spacer(),
          Text(value, style: AppText.label.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
