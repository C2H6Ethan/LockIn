import LockInCore
import Observation
import UIKit
import UserNotifications

/// Owns the app's environment so work that must start in `didFinishLaunching` (HealthKit background
/// delivery) can use it, and turns notification taps into deep links.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let router = DeepLinkRouter()
    private(set) lazy var environment = AppEnvironment.live()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        environment.startBackgroundObservers()
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let string = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: string) else { return }
        await MainActor.run { router.open(url) }
    }

    /// Show LockIn's notifications even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
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
