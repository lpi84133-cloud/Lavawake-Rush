import UserNotifications

/// Rewrites the notification so its media matches the app icon 1-for-1.
///
/// iOS shows two images inside a notification: the small circle on the left
/// (always the app icon — the OS reads it straight from `AppIcon.appiconset`,
/// nothing this extension can influence) and the large attachment on the
/// right (whatever image the payload asks the extension to fetch). The
/// second one is what caused the "notification icon differs from the app
/// icon" QA complaint — the FCM payload's `fcm_options.image` pointed at a
/// creative that had nothing to do with the app icon, and Firebase's
/// service-extension helper attached it verbatim.
///
/// Now we ignore whatever the server puts in `fcm_options.image` and attach
/// the bundled `NotificationIcon.png` (a copy of the 1024×1024 app icon)
/// instead. Both slots of the notification therefore show the same artwork.
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

    // Any attachment the server tried to add is dropped: only the bundled
    // app-icon copy is allowed to reach the user. Failing to load the local
    // icon is not worth blocking the notification for — we just show the
    // banner without an attachment, which still displays the app icon in
    // the small circle.
    best.attachments = []
    if let attachment = appIconAttachment() {
      best.attachments = [attachment]
    }

    contentHandler(best)
  }

  /// Time is up: show whatever has been assembled rather than nothing.
  override func serviceExtensionTimeWillExpire() {
    if let handler = contentHandler, let best = bestAttempt {
      handler(best)
    }
  }

  private func appIconAttachment() -> UNNotificationAttachment? {
    guard let source = Bundle.main.url(forResource: "NotificationIcon", withExtension: "png") else {
      return nil
    }
    // `UNNotificationAttachment` requires a unique file URL it can take
    // ownership of, so the bundled PNG is copied into the extension's tmp
    // directory. A UUID keeps two overlapping notifications from clashing
    // on the destination path.
    let destination = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString + ".png")
    do {
      try FileManager.default.copyItem(at: source, to: destination)
      return try UNNotificationAttachment(
        identifier: "app-icon",
        url: destination,
        options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
      )
    } catch {
      return nil
    }
  }
}
