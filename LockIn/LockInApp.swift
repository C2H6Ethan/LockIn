import SwiftUI
import FamilyControls
import UserNotifications

// MARK: - App Delegate (notification deep link handling)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Handles tapping a delivered notification. Opens the deep link URL in the app.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard
            let urlString = response.notification.request.content.userInfo["url"] as? String,
            let url = URL(string: urlString)
        else { return }
        await UIApplication.shared.open(url)
    }

    /// Show notification banner even when app is in foreground (e.g. on Today screen).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

// MARK: - App

@main
struct LockInApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOnboarding = !SharedStore.shared.hasCompletedOnboarding

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .task {
                    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
                    // Only request on launch for users who completed onboarding already.
                    // New users get the prompt from the Screen Time explainer step.
                    if SharedStore.shared.hasCompletedOnboarding {
                        await requestFamilyControlsAuthorization()
                    }
                    SchedulingService.shared.scheduleWeeklyMonitorIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active,
                       ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                        BlockingService.shared.updateShieldsForCurrentHabitState()
                        SchedulingService.shared.rescheduleReminderIfNeeded()
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView { showOnboarding = false }
                }
        }
    }

    // MARK: - Private

    private func requestFamilyControlsAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // Authorization failed or denied — blocking unavailable until granted
        }
    }

}

extension Notification.Name {
    static let habitsDidChange = Notification.Name("habitsDidChange")
}

