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

    // Completion-handler versions on purpose: with the `async` versions, iOS calls UIKit's completion from a
    // background thread when the method returns, and UIKit crashes ("Call must be made on main thread").
    // So the handler is always called on the main thread here.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let url = (response.notification.request.content.userInfo["url"] as? String).flatMap(URL.init(string:))
        nonisolated(unsafe) let done = completionHandler
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if let url { self.router.open(url) }
            }
            done()
        }
    }

    /// Show LockIn's notifications even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        nonisolated(unsafe) let done = completionHandler
        DispatchQueue.main.async { done([.banner, .sound]) }
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
