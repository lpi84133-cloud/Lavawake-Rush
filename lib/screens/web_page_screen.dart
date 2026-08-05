import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_config.dart';
import '../core/design/app_theme.dart';
import '../core/design/palette.dart';
import '../core/widgets/buttons.dart';
import '../state/audio_service.dart';

enum WebDocument { privacy, support }

extension _WebDocumentInfo on WebDocument {
  String get title => switch (this) {
    WebDocument.privacy => 'Privacy Policy',
    WebDocument.support => 'Support',
  };

  String get eyebrow => switch (this) {
    WebDocument.privacy => 'Legal',
    WebDocument.support => 'Help centre',
  };

  String get url => switch (this) {
    WebDocument.privacy => AppConfig.privacyPolicyUrl,
    WebDocument.support => AppConfig.supportUrl,
  };

  String get asset => switch (this) {
    WebDocument.privacy => AppConfig.privacyPolicyAsset,
    WebDocument.support => AppConfig.supportAsset,
  };

  IconData get icon => switch (this) {
    WebDocument.privacy => Icons.privacy_tip_outlined,
    WebDocument.support => Icons.support_agent_rounded,
  };
}

/// Renders the Privacy Policy and Support pages in a WebView.
///
/// Both documents are always reachable: the online page is preferred, and a
/// bundled copy with identical content is loaded whenever there is no connection
/// or the request fails. Content is always black text on a white sheet.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key, required this.document});

  final WebDocument document;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;

  bool _loading = true;
  bool _usingBundledCopy = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onHttpError: (_) => _fallBackToBundledCopy(),
          onWebResourceError: (error) {
            // Sub-resources failing is harmless; only a dead main document
            // should trigger the offline copy.
            if (error.isForMainFrame ?? true) _fallBackToBundledCopy();
          },
          onNavigationRequest: _handleNavigation,
        ),
      );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _progress = 0;
    });
    if (await _hasConnection()) {
      _usingBundledCopy = false;
      await _controller.loadRequest(Uri.parse(widget.document.url));
    } else {
      await _loadBundledCopy();
    }
  }

  Future<bool> _hasConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any(
        (status) =>
            status == ConnectivityResult.wifi ||
            status == ConnectivityResult.mobile ||
            status == ConnectivityResult.ethernet ||
            status == ConnectivityResult.vpn,
      );
    } on Object {
      // If the platform channel is unavailable, try the network anyway; the
      // error handler will fall back to the bundled copy.
      return true;
    }
  }

  Future<void> _loadBundledCopy() async {
    final html = await DefaultAssetBundle.of(context).loadString(widget.document.asset);
    if (!mounted) return;
    setState(() => _usingBundledCopy = true);
    await _controller.loadHtmlString(html, baseUrl: 'https://lavawakerush.com/');
  }

  void _fallBackToBundledCopy() {
    if (_usingBundledCopy || !mounted) return;
    _loadBundledCopy();
  }

  Future<NavigationDecision> _handleNavigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    // The support form posts through a mailto: link so it also works offline.
    if (uri.scheme == 'mailto' || uri.scheme == 'tel') {
      await _openExternally(uri);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      if (!mounted) return;
      _toast('No app on this device can open ${uri.scheme} links.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.body14.copyWith(color: Palette.textPrimary)),
        backgroundColor: Palette.surfaceHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return Scaffold(
      backgroundColor: Palette.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Dim.m, Dim.s, Dim.m, Dim.m),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAction(
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      context.read<AudioService>().back();
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(width: Dim.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              doc.eyebrow.toUpperCase(),
                              style: AppText.eyebrow.copyWith(color: Palette.lava),
                            ),
                            if (_usingBundledCopy) ...[
                              const SizedBox(width: Dim.s),
                              const Chip2(
                                label: 'OFFLINE COPY',
                                icon: Icons.cloud_off_rounded,
                                dense: true,
                                selected: true,
                                color: Palette.frost,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(doc.title, style: AppText.title.copyWith(fontSize: 20)),
                      ],
                    ),
                  ),
                  CircleAction(icon: Icons.refresh_rounded, tooltip: 'Reload', onTap: _load),
                  const SizedBox(width: Dim.s),
                  CircleAction(
                    icon: Icons.open_in_new_rounded,
                    tooltip: 'Open in browser',
                    onTap: () => _openExternally(Uri.parse(doc.url)),
                  ),
                ],
              ),
              const SizedBox(height: Dim.m),
              Expanded(
                child: ClipRRect(
                  borderRadius: Dim.brM,
                  child: Container(
                    color: Colors.white,
                    child: Stack(
                      children: [
                        // Selection is left to the platform; the sheet itself is
                        // plain white so the bundled black-on-white styling and
                        // the live page look identical.
                        WebViewWidget(
                          controller: _controller,
                          gestureRecognizers: const {},
                        ),
                        if (_loading)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: _progress == 0 ? null : _progress / 100,
                              minHeight: 2.5,
                              backgroundColor: Colors.black12,
                              valueColor: const AlwaysStoppedAnimation(Palette.lava),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Dim.s),
              Row(
                children: [
                  Icon(doc.icon, size: 13, color: Palette.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _usingBundledCopy
                          ? 'Showing the copy bundled with the app, so this page works with no connection.'
                          : doc.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14.copyWith(fontSize: 11.5, color: Palette.textMuted),
                    ),
                  ),
                  if (doc == WebDocument.support)
                    GestureDetector(
                      onTap: () => Clipboard.setData(
                        const ClipboardData(text: AppConfig.supportEmail),
                      ).then((_) => _toast('Support email copied.')),
                      child: Text(
                        AppConfig.supportEmail,
                        style: AppText.label.copyWith(fontSize: 11, color: Palette.lava),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
