import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/palette.dart';
import 'flow_button.dart';

/// Offers notifications before the system dialog appears, so a refusal costs
/// only this screen and not the one chance iOS gives us.
///
/// This screen moves on under its own context. Letting the screen that pushed
/// it navigate afterwards leaves the user stranded here: that screen is gone
/// by then, and its silent no-op looks like a dead button.
class EmberConsentPage extends StatefulWidget {
  const EmberConsentPage({
    super.key,
    required this.onAccept,
    required this.onSkip,
    required this.nextBuilder,
  });

  final Future<void> Function() onAccept;
  final Future<void> Function() onSkip;
  final WidgetBuilder nextBuilder;

  static const String portraitArt =
      'assets/Lavawake_Rush_additional_assets/Vertical_Notifications_Screen.webp';
  static const String landscapeArt =
      'assets/Lavawake_Rush_additional_assets/Horizontal_Notifications_Screen.webp';

  @override
  State<EmberConsentPage> createState() => _EmberConsentPageState();
}

class _EmberConsentPageState extends State<EmberConsentPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object {
      // Whatever the answer was, the user still has to get where they were going.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.nextBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width >= size.height;

    final Widget buttons;

    if (landscape) {
      // Горизонталь: две кнопки в ряд одинаковой ширины
      final rowWidth = (size.width * 0.62).clamp(360.0, 640.0);
      buttons = SizedBox(
        width: rowWidth,
        child: Row(
          children: [
            Expanded(
              child: FlowButton(
                label: 'Allow notifications',
                onPressed: _busy ? null : () => _run(widget.onAccept),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FlowButton(
                label: 'Not now',
                subdued: true,
                onPressed: _busy ? null : () => _run(widget.onSkip),
              ),
            ),
          ],
        ),
      );
    } else {
      // Портрет: кнопки друг под другом
      final colWidth = (size.width * 0.72).clamp(230.0, 390.0);
      buttons = SizedBox(
        width: colWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlowButton(
              label: 'Allow notifications',
              onPressed: _busy ? null : () => _run(widget.onAccept),
            ),
            const SizedBox(height: 12),
            FlowButton(
              label: 'Not now',
              subdued: true,
              onPressed: _busy ? null : () => _run(widget.onSkip),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Palette.voidBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            landscape ? EmberConsentPage.landscapeArt : EmberConsentPage.portraitArt,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          if (landscape)
            Align(alignment: const Alignment(0, 0.72), child: buttons)
          else
            SafeArea(
              child: Align(alignment: const Alignment(0, 0.78), child: buttons),
            ),
        ],
      ),
    );
  }
}
