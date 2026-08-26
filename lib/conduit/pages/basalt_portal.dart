import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/flow_settings.dart';
import '../core/trace.dart';
import '../infra/client_stamp.dart';
import '../infra/reach_check.dart';
import 'dead_air_page.dart';

/// Full-screen browser surface.
class BasaltPortal extends StatefulWidget {
  const BasaltPortal({
    super.key,
    required this.address,
    required this.rebootBuilder,
    this.fromNotification = false,
  });

  final String address;
  final WidgetBuilder rebootBuilder;

  /// A launch that came from a tapped notification measures its viewport
  /// before immersive mode has settled, which bakes in the wrong height.
  final bool fromNotification;

  @override
  State<BasaltPortal> createState() => _BasaltPortalState();
}

class _BasaltPortalState extends State<BasaltPortal> with WidgetsBindingObserver {
  late final WebViewController _web;

  bool _canRender = false;
  bool _leftForOffline = false;
  bool _coldReloadDone = false;
  int _redirectRetries = 0;

  /// The most recent main-frame URL. A `-1007` retry reloads THIS, not the
  /// original portal address — restarting the whole chain from the entry URL
  /// throws away every redirect hop and the destination is never reached.
  late String _lastMainFrame = widget.address;
  Orientation? _lastOrientation;
  StreamSubscription<List<ConnectivityResult>>? _link;

  static const Set<String> _renderable = <String>{'http', 'https', 'about', 'data', 'blob'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _web = _buildController();
    _enableSwipeBack();
    _watchLink();

    if (widget.fromNotification) {
      unawaited(_settleThenLoad());
    } else {
      _immersive();
      _canRender = true;
      unawaited(_load());
    }
  }

  /// Activates the native iOS edge-swipe-back gesture so the user can
  /// navigate backwards through the WebView history by swiping from the
  /// left edge of the screen — the same gesture every Safari tab supports.
  void _enableSwipeBack() {
    final platform = _web.platform;
    if (platform is WebKitWebViewController) {
      unawaited(platform.setAllowsBackForwardNavigationGestures(true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_link?.cancel());
    super.dispose();
  }

  WebViewController _buildController() {
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            // Inline playback lives here rather than in an injected script:
            // one less behaviour to push into the page.
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    return WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      // The stamp MUST be set before the first `loadRequest`. Deferring it
      // to an async hop after mount used to leave WKWebView on `about:blank`
      // when a cold-tap arrived — the page never started loading and the
      // background colour made it look like a hard black screen. Prewarming
      // in `main()` fills the cache; `snapshot()` falls back to a synthesised
      // stamp on the very first cold start so nothing here is `null`.
      ..setUserAgent(ClientStamp.snapshot())
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _decideNavigation,
          onPageFinished: _afterPage,
          onWebResourceError: _onError,
        ),
      );
  }

  Future<void> _load() async {
    // Refresh the stamp in the background so the real (device-reported)
    // release replaces the fallback for the second navigation onwards, but
    // never block the very first `loadRequest` on it.
    unawaited(_refreshStampInBackground());
    try {
      await _web.loadRequest(Uri.parse(widget.address));
    } on Object catch (error) {
      trace('portal', 'load failed: $error');
      if (mounted && !await ReachCheck.routeUp()) unawaited(_goOffline());
    }
  }

  Future<void> _refreshStampInBackground() async {
    try {
      // If the cache was already populated by main()'s prewarm, `resolve`
      // returns immediately with the same value the builder used — nothing
      // to do. Otherwise it replaces the fallback release with the one
      // device_info reported, so subsequent requests carry the real stamp.
      final resolved = await ClientStamp.resolve();
      if (!mounted) return;
      await _web.setUserAgent(resolved);
    } on Object catch (error) {
      trace('portal', 'stamp refresh failed: $error');
    }
  }

  /// Enter immersive mode, let the viewport settle in the orientation the
  /// phone is actually in, and only then mount. Forcing a rotation to trigger
  /// the recalculation makes the page open sideways and visibly flip.
  Future<void> _settleThenLoad() async {
    _immersive();
    await Future<void>.delayed(FlowSettings.coldViewportSettle);
    if (!mounted) return;
    setState(() => _canRender = true);
    await _load();
  }

  void _immersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _watchLink() {
    _link = Connectivity().onConnectivityChanged.listen((state) {
      // A reported-down interface is answer enough; probing first would let
      // the page render its own error screen in the meantime.
      if (state.every((entry) => entry == ConnectivityResult.none)) {
        unawaited(_goOffline());
      }
    });
  }

  Future<NavigationDecision> _decideNavigation(NavigationRequest request) async {
    final scheme = Uri.tryParse(request.url)?.scheme.toLowerCase() ?? '';

    if (_renderable.contains(scheme)) {
      // Remember where the main frame is actually going so a redirect-loop
      // retry resumes from here instead of the entry URL.
      if (request.isMainFrame) _lastMainFrame = request.url;
      return NavigationDecision.navigate;
    }

    // javascript: has no external handler and must be silently dropped.
    if (scheme == 'javascript') return NavigationDecision.prevent;

    // Any other scheme (tel:, mailto:, paytmmp:, etc.) is handed off to the
    // system — payment apps, dialers and mailers all register their schemes
    // this way. WebView cannot render them, so we prevent the navigation and
    // let the OS decide what to open.
    try {
      await launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      trace('portal', 'hand-off failed $scheme: $error');
    }
    return NavigationDecision.prevent;
  }

  Future<void> _afterPage(String url) async {
    _redirectRetries = 0;
    await _applyPageTweaks();

    // The viewport is still settling right after a load; a late nudge fixes
    // any height the page measured too early.
    Future<void>.delayed(FlowSettings.reflowSettle, () async {
      if (!mounted) return;
      setState(() {}); // re-read the insets immersive mode has since changed
      await _web.runJavaScript(
        'window.dispatchEvent(new Event("resize"));'
        'if(window.visualViewport)'
        'window.visualViewport.dispatchEvent(new Event("resize"));',
      );
      await _applyPageTweaks();

      // A page first painted during a cold start can keep the height it
      // measured while the status bar was still up. Nudging the viewport is
      // not always enough; one re-render in the settled frame is.
      if (widget.fromNotification && !_coldReloadDone) {
        _coldReloadDone = true;
        await _web.reload();
      }
    });
  }

  Future<void> _applyPageTweaks() async {
    try {
      await _web.runJavaScript(_pageTweaks);
    } on Object catch (error) {
      trace('portal', 'tweaks failed: $error');
    }
  }

  Future<void> _onError(WebResourceError error) async {
    // WKWebView reports null for the main navigation often enough that
    // treating null as "not main frame" swallows real failures and the app
    // simply looks frozen.
    final mainFrame = error.isForMainFrame ?? true;
    if (!mainFrame) return;
    if (error.errorCode == -999) return; // superseded by another navigation

    if (error.errorCode == -1007 && _redirectRetries < FlowSettings.redirectRetryLimit) {
      _redirectRetries++;
      trace('portal', 'redirect loop, retry $_redirectRetries -> $_lastMainFrame');
      await _web.loadRequest(Uri.parse(_lastMainFrame));
      return;
    }

    trace('portal', 'load error ${error.errorCode} ${error.description}');
    if (!await ReachCheck.routeUp()) unawaited(_goOffline());
  }

  /// Navigates to the offline screen, passing the *current* WebView URL as the
  /// retry address so the user resumes from where they were, not from the
  /// original portal entry point.
  Future<void> _goOffline() async {
    if (_leftForOffline || !mounted) return;
    _leftForOffline = true;

    String current;
    try {
      current = await _web.currentUrl() ?? widget.address;
    } on Object {
      current = widget.address;
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DeadAirPage(
          retryBuilder: (_) => BasaltPortal(
            address: current,
            rebootBuilder: widget.rebootBuilder,
            fromNotification: false,
          ),
        ),
      ),
    );
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});

    final orientation = MediaQuery.orientationOf(context);
    if (orientation == _lastOrientation) return;
    _lastOrientation = orientation;

    // WKWebView holds the pre-rotation width for about a second, so the page
    // is poked repeatedly while the native frame catches up.
    for (final delay in FlowSettings.reflowPokes) {
      Future<void>.delayed(Duration(milliseconds: delay), () async {
        if (!mounted) return;
        try {
          await _web.runJavaScript(
            'window.dispatchEvent(new Event("orientationchange"));'
            'window.dispatchEvent(new Event("resize"));',
          );
          await _applyPageTweaks();
        } on Object {
          // The controller may be gone mid-rotation; nothing to recover.
        }
      });
    }
  }

  Future<bool> _handleBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
      return false;
    }
    // The first page is the end of the road, but leaving it would drop the
    // user out of the surface entirely.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // Letting the Scaffold shrink for the keyboard resizes the WebView
        // native frame, which is what caused two casino sites to collapse
        // their input forms (fields overlapping the keyboard in landscape,
        // fields blanking out to gray when switching focus in portrait).
        // WKWebView already reports the keyboard through `visualViewport`,
        // so the site's own layout can lift the focused field without any
        // help from Flutter's inset arithmetic.
        resizeToAvoidBottomInset: false,
        body: _canRender
            ? Padding(padding: inset, child: WebViewWidget(controller: _web))
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}

/// One idempotent bundle instead of a series of independent scripts.
///
/// It neutralises the safe-area variables the site may declare, locks the
/// zoom, removes the tap highlight and lifts a focused field into view. It
/// deliberately never touches horizontal padding on the document or the app
/// root: zeroing those erases the site's own gutters and the layout collapses
/// against the screen edges.
const String _pageTweaks = r'''
(function(){
  if (window.__lvrShell) { window.__lvrShell.sync(); return; }

  var typing = function(){
    return !!(window.visualViewport &&
      window.visualViewport.height < window.innerHeight * 0.75);
  };

  var styleId = 'lvr-shell-style';
  var css =
    ':root{' +
      ' --safe-area-inset-top: 0px !important; --safe-area-inset-right: 0px !important;' +
      ' --safe-area-inset-bottom: 0px !important; --safe-area-inset-left: 0px !important;' +
      ' --sat: 0px !important; --sar: 0px !important; --sab: 0px !important; --sal: 0px !important;' +
      ' --safe-top: 0px !important; --safe-bottom: 0px !important;' +
      ' --safe-left: 0px !important; --safe-right: 0px !important;' +
    ' }' +
    'html, body{ overscroll-behavior: none !important; overscroll-behavior-y: none !important; }' +
    '*{ -webkit-tap-highlight-color: transparent !important; }' +
    'input, textarea, select{ font-size: max(16px, 1em) !important; }' +
    '::-webkit-scrollbar{ width: 0; height: 0; }' +
    '::-webkit-scrollbar-thumb{ background: rgba(72, 20, 10, 0.55); }';

  var paintStyle = function(){
    var tag = document.getElementById(styleId);
    if (!tag) {
      tag = document.createElement('style');
      tag.id = styleId;
      (document.head || document.documentElement).appendChild(tag);
    }
    if (tag.textContent !== css) tag.textContent = css;
  };

  var lockScale = function(){
    if (typing()) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      (document.head || document.documentElement).appendChild(meta);
    }
    meta.setAttribute('content',
      'width=device-width, initial-scale=1, maximum-scale=1, ' +
      'minimum-scale=1, user-scalable=no, viewport-fit=contain');
  };

  var block = function(event){ event.preventDefault(); };
  document.addEventListener('gesturestart', block, {passive:false});
  document.addEventListener('gesturechange', block, {passive:false});
  document.addEventListener('gestureend', block, {passive:false});

  var lastTap = 0;
  document.addEventListener('touchend', function(event){
    var now = Date.now();
    if (now - lastTap < 320) event.preventDefault();
    lastTap = now;
  }, {passive:false});

  // A single deferred jump. Smooth scrolling here runs a second animator
  // alongside the keyboard and the two fight for the compositor.
  document.addEventListener('focusin', function(event){
    var field = event.target;
    if (!field || !field.scrollIntoView) return;
    var tag = (field.tagName || '').toLowerCase();
    if (tag !== 'input' && tag !== 'textarea' && tag !== 'select') return;
    setTimeout(function(){
      field.scrollIntoView({behavior:'auto', block:'nearest'});
    }, 350);
  });

  window.__lvrShell = { sync: function(){ paintStyle(); lockScale(); } };
  window.__lvrShell.sync();
  window.addEventListener('orientationchange', function(){
    setTimeout(window.__lvrShell.sync, 150);
  });
})();
''';
