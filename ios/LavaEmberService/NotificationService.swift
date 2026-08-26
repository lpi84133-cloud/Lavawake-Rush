import UserNotifications

#if canImport(FirebaseMessaging)
  import FirebaseMessaging
#endif

/// Attaches rich media to a notification before it is shown.
///
/// The image URL lives on the payload under `fcm_options.image`. Firebase's
/// service-extension helper downloads it and hangs it on `best.attachments`
/// so both the small-circle preview and the large expanded slot in the
/// notification show that image. Without this extension the attachment
/// would only appear while the Dart isolate is already running — which is
/// precisely when a rich push adds no value.
class NotificationService: UNNotificationServiceExtension {

  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttempt: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttempt = request.content.mutableCopy() as? UNMutableNotificationContent

    guard let best = bestAttempt else {
      contentHandler(request.content)
      return
    }

    #if canImport(FirebaseMessaging)
      Messaging.serviceExtension().populateNotificationContent(
        best, withContentHandler: contentHandler)
    #else
      contentHandler(best)
    #endif
  }

  /// Time is up: show whatever has been assembled rather than nothing.
  override func serviceExtensionTimeWillExpire() {
    if let handler = contentHandler, let best = bestAttempt {
      handler(best)
    }
  }
}
