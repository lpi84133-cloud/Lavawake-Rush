import UserNotifications

#if canImport(FirebaseMessaging)
  import FirebaseMessaging
#endif

/// Attaches rich media to a notification before it is shown.
///
/// Without this extension the image only appears while the Dart isolate
/// happens to be alive, which is exactly when it matters least.
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
