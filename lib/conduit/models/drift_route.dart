/// Which surface this install has settled on.
///
/// [undecided] is the only state that may still change into either of the
/// other two on a first launch. A launch that never reached the backend must
/// stay [undecided] so a later, healthier launch can still resolve it.
enum DriftRoute { undecided, portal, native }

/// Where the boot sequence hands the user next.
class DriftDestination {
  const DriftDestination.portal(String this.address, {this.fromNotification = false})
    : offline = false;

  const DriftDestination.native() : address = null, offline = false, fromNotification = false;

  const DriftDestination.offline()
    : address = null,
      offline = true,
      fromNotification = false;

  final String? address;
  final bool offline;
  final bool fromNotification;

  bool get isPortal => address != null;
}
