import LockInCore
import Observation
import UIKit
import UserNotifications

/// Receives notification taps and turns them into deep links.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let router = DeepLinkRouter()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let string = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: string) else { return }
        await MainActor.run { router.open(url) }
    }

    /// Show LockIn's notifications even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// The latest deep link the app hasn't handled yet.
@MainActor
@Observable
final class DeepLinkRouter {
    var pending: DeepLink?

    func open(_ url: URL) {
        pending = DeepLink(url: url)
    }
}
