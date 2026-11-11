#if os(iOS)
import Foundation
import UserNotifications

/// Posts local notifications. Exists so posting can be tested with a fake.
public protocol NotificationPoster {
    func post(id: String, title: String, body: String, deepLink: URL?)
}

/// Posts immediately through `UNUserNotificationCenter`. Works from the app and from extensions.
public struct UserNotificationPoster: NotificationPoster {
    public init() {}

    public func post(id: String, title: String, body: String, deepLink: URL?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let deepLink { content.userInfo = ["url": deepLink.absoluteString] }
        // A nil trigger delivers now; reusing the id replaces an undelivered or delivered one.
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
#endif
