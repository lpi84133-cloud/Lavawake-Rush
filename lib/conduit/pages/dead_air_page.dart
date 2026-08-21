import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/palette.dart';
import 'flow_button.dart';

/// Shown when the app cannot reach anything.
///
/// [retryBuilder] rebuilds the boot screen from scratch rather than patching
/// state in place: the pipeline is idempotent, and a retry that reuses the old
/// context dies with the widget that launched it.
class DeadAirPage extends StatefulWidget {
  const DeadAirPage({super.key, required this.retryBuilder});

  final WidgetBuilder retryBuilder;

  static const String portraitArt =
      'assets/Lavawake_Rush_additional_assets/Vertical_Nowifi_Screen.webp';
  static const String landscapeArt =
      'assets/Lavawake_Rush_additional_assets/Horizontal_Nowifi_Screen.webp';

  @override
  State<DeadAirPage> createState() => _DeadAirPageState();
}

class _DeadAirPageState extends State<DeadAirPage> {
  bool _retrying = false;
  StreamSubscription<List<ConnectivityResult>>? _watch;

  @override
  void initState() {
    super.initState();
    // The boot screen locks orientation before handing over; this screen has
    // artwork for both and must be free to turn again.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Auto-continue the moment the radio reports a working interface again.
    // The pipeline is idempotent and rebuilds itself from scratch, so this
    // is safe to fire on the first up-edge — the user does not have to hunt
    // for the button after they turned Wi-Fi back on.
    _watch = Connectivity().onConnectivityChanged.listen((state) {
      if (_retrying) return;
      if (!state.any((entry) => entry != ConnectivityResult.none)) return;
      _retry();
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  void _retry() {
    if (_retrying || !mounted) return;
    setState(() => _retrying = true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.retryBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width >= size.height;
    final width = landscape
        ? (size.width * 0.35).clamp(200.0, 320.0)
        : (size.width * 0.70).clamp(220.0, 380.0);

    final button = SizedBox(
      width: width,
      child: FlowButton(label: 'Try again', onPressed: _retrying ? null : _retry),
    );

    return Scaffold(
      backgroundColor: Palette.voidBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            landscape ? DeadAirPage.landscapeArt : DeadAirPage.portraitArt,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          // In landscape the notch inset would shift the horizontal centre and
          // leave the button visibly off-axis, so the artwork is trusted.
          if (landscape)
            Align(alignment: const Alignment(0, 0.72), child: button)
          else
            SafeArea(
              child: Align(alignment: const Alignment(0, 0.80), child: button),
            ),
        ],
      ),
    );
  }
}
