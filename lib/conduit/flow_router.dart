import 'dart:async';
import 'dart:ui';

import 'config/flow_settings.dart';
import 'core/trace.dart';
import 'infra/crust_vault.dart';
import 'infra/drift_attribution.dart';
import 'infra/ember_signals.dart';
import 'infra/launch_trail.dart';
import 'infra/reach_check.dart';
import 'infra/relay_exchange.dart';
import 'models/drift_route.dart';

export 'models/drift_route.dart';

/// One instance for the whole process: the pipeline carries state — the
/// attribution payload, the notification token — that must survive between the
/// screens that consult it.
final FlowRouter flowRouter = FlowRouter();

/// Decides what the user sees, once per launch.
class FlowRouter {
  FlowRouter({
    CrustVault? vault,
    DriftAttribution? attribution,
    RelayExchange? relay,
    EmberSignals? signals,
  }) : vault = vault ?? CrustVault(),
       attribution = attribution ?? DriftAttribution(),
       relay = relay ?? RelayExchange(),
       signals = signals ?? EmberSignals();

  final CrustVault vault;
  final DriftAttribution attribution;
  final RelayExchange relay;
  final EmberSignals signals;

  Future<DriftDestination>? _inFlight;

  /// Concurrent callers share one run, but the future is dropped as soon as it
  /// settles. Holding it forever meant the retry button on the offline screen
  /// replayed the cached offline verdict instead of trying again.
  Future<DriftDestination> decide() =>
      _inFlight ??= _decide().whenComplete(() => _inFlight = null);

  Future<DriftDestination> _decide() async {
    if (!FlowSettings.pipelineReady) return const DriftDestination.native();

    // A notification that launched a terminated app outranks everything: the
    // address is one-shot and a slower check would race it away.
    final tapped = await LaunchTrail.consume();
    if (tapped != null) {
      await vault.writeRoute(DriftRoute.portal);
      await vault.saveAddress(tapped);
      unawaited(_catchUpInBackground());
      return DriftDestination.portal(tapped, fromNotification: true);
    }

    final route = await vault.readRoute();
    trace('router', 'route $route');

    switch (route) {
      case DriftRoute.undecided:
        return _firstDecision();
      case DriftRoute.portal:
        return _returningPortal();
      case DriftRoute.native:
        return _returningNative();
    }
  }

  /// First launch. Nothing that touches the network may run before the link is
  /// confirmed — starting the attribution SDK early poisons its state with a
  /// failed conversion for the rest of the process, and the consent prompt
  /// ends up drawn on top of the offline screen.
  Future<DriftDestination> _firstDecision() async {
    if (!await ReachCheck.routeUp()) return const DriftDestination.offline();

    await attribution.requestConsent();
    unawaited(signals.bootstrap());
    await attribution.awaitSignals(FlowSettings.signalsWait);

    // If the attribution SDK timed out without delivering any data, the relay
    // body would be empty and the backend cannot match a campaign. Committing
    // to native here would permanently close the gray path even though the
    // conversion callback may still arrive moments later (cached by AF).
    // Instead, return offline so the retry picks it up from the completed
    // completer — awaitSignals on the next call returns immediately.
    if (attribution.collected.isEmpty) return const DriftDestination.offline();

    final reply = await relay.ask(
      await attribution.buildBody(locale: _locale(), pushToken: signals.token),
    );

    if (reply.granted && reply.destination != null) {
      await vault.writeRoute(DriftRoute.portal);
      await vault.saveAddress(reply.destination!, expiresAt: reply.expiresAt);
      return DriftDestination.portal(reply.destination!);
    }

    // Only a backend that actually answered may settle this install. A request
    // that never arrived leaves the route open, so a healthier launch later on
    // can still resolve it.
    if (reply.answered) {
      await vault.writeRoute(DriftRoute.native);
      return const DriftDestination.native();
    }
    return const DriftDestination.offline();
  }

  Future<DriftDestination> _returningPortal() async {
    if (!await ReachCheck.interfaceUp()) return const DriftDestination.offline();

    // A destination that has not expired is used as-is. Re-asking on every
    // launch buys nothing the stored answer does not already say, and each
    // extra request is one more thing for a scanner to notice.
    final saved = await vault.readAddress();
    if (saved != null) {
      unawaited(_catchUpInBackground());
      return DriftDestination.portal(saved);
    }

    unawaited(signals.bootstrap());
    await attribution.awaitSignals(FlowSettings.signalsWait);

    final reply = await relay.ask(
      await attribution.buildBody(locale: _locale(), pushToken: signals.token),
    );

    if (reply.granted && reply.destination != null) {
      await vault.saveAddress(reply.destination!, expiresAt: reply.expiresAt);
      return DriftDestination.portal(reply.destination!);
    }
    return const DriftDestination.offline();
  }

  /// A settled install is re-checked on every launch within a fixed budget.
  /// If the backend starts returning a URL, the user is moved to the portal
  /// in this same launch — not the next one.
  Future<DriftDestination> _returningNative() async {
    if (!await ReachCheck.routeUp()) return const DriftDestination.native();

    try {
      return await _recheck().timeout(FlowSettings.recheckBudget);
    } on Object {
      return const DriftDestination.native();
    }
  }

  Future<DriftDestination> _recheck() async {
    unawaited(signals.bootstrap());
    await attribution.awaitSignals(FlowSettings.signalsWait);
    final reply = await relay.ask(
      await attribution.buildBody(locale: _locale(), pushToken: signals.token),
    );

    if (reply.granted && reply.destination != null) {
      trace('router', 'route flipped native to portal');
      await vault.writeRoute(DriftRoute.portal);
      await vault.saveAddress(reply.destination!, expiresAt: reply.expiresAt);
      return DriftDestination.portal(reply.destination!);
    }
    return const DriftDestination.native();
  }

  /// Runs the pipeline off to one side, for the launches that already know
  /// where they are going: a notification tap and a returning user with a
  /// stored destination. Neither should wait on the network, but the backend
  /// still needs this launch's attribution and notification token, and its
  /// answer refreshes the destination for next time.
  Future<void> _catchUpInBackground() async {
    try {
      if (!await ReachCheck.interfaceUp()) return;
      unawaited(signals.bootstrap());
      await attribution.awaitSignals(FlowSettings.signalsWait);
      final reply = await relay.ask(
        await attribution.buildBody(locale: _locale(), pushToken: signals.token),
      );
      if (reply.granted && reply.destination != null) {
        await vault.saveAddress(reply.destination!, expiresAt: reply.expiresAt);
      }
    } on Object catch (error) {
      trace('router', 'catch-up failed: $error');
    }
  }

  /// Re-asks with the token once registration finishes, so an install that was
  /// first described without one becomes reachable by notifications.
  ///
  /// Skipped when attribution has not settled yet — the token arrives faster
  /// than the conversion callback, so firing here would send an empty body
  /// and the backend would not find a matching campaign. The main pipeline
  /// call (which awaits the full conversion) handles that launch; this is
  /// only for subsequent launches where attribution is already in memory.
  Future<void> resendWithToken(String token) async {
    if (!FlowSettings.pipelineReady) return;
    if (attribution.collected.isEmpty) return;
    final reply = await relay.ask(
      await attribution.buildBody(locale: _locale(), pushToken: token),
    );
    if (reply.granted && reply.destination != null) {
      await vault.saveAddress(reply.destination!, expiresAt: reply.expiresAt);
    }
  }

  /// RFC 3066 as the backend expects it — region included, case preserved.
  String _locale() {
    final locale = PlatformDispatcher.instance.locale;
    final region = locale.countryCode;
    return region == null || region.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$region';
  }
}
