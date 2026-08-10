/// Parsed answer from the configuration endpoint.
///
/// A malformed body or a non-200 status is still an answer — the backend was
/// reached and said no. [answered] is false only when the request never got
/// through at all, and that difference decides whether a first launch is
/// allowed to settle on a route.
class RelayReply {
  const RelayReply._({
    required this.granted,
    required this.answered,
    this.destination,
    this.expiresAt,
  });

  const RelayReply.refused()
    : granted = false,
      answered = true,
      destination = null,
      expiresAt = null;

  const RelayReply.unreachable()
    : granted = false,
      answered = false,
      destination = null,
      expiresAt = null;

  factory RelayReply.fromJson(Map<String, dynamic> body) {
    final ok = body['ok'] == true;
    final raw = body['url'];
    final address = raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    if (!ok || address == null) return const RelayReply.refused();

    final expires = body['expires'];
    return RelayReply._(
      granted: true,
      answered: true,
      destination: address,
      expiresAt: expires is num ? expires.toInt() : null,
    );
  }

  final bool granted;
  final bool answered;
  final String? destination;
  final int? expiresAt;
}
