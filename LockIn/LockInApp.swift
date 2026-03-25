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
                        // Register monitors only after authorization — startMonitoring throws if called without it.
                        SchedulingService.shared.scheduleDailyMonitorIfNeeded()
                        SchedulingService.shared.scheduleBlockingStartTimeMonitors(for: SharedStore.shared.tasks)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active,
                       ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                        BlockingService.shared.updateShieldsForCurrentHabitState()
                        SchedulingService.shared.rescheduleReminderIfNeeded()
                        SchedulingService.shared.scheduleBlockingStartTimeMonitors(for: SharedStore.shared.tasks)
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView { showOnboarding = false }
                }
        }
    }

    // MARK: - Screenshot mock data

    private func injectScreenshotDataIfNeeded() {
        #if DEBUG
        // TEMPORARY: always inject mock data for screenshots. Revert this.
        let store = SharedStore.shared
        // Clear existing
        for task in store.tasks { store.removeTask(id: task.id) }

        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let todayString = today.dateString

        let t1 = Task(title: "Morning workout", activeDays: [weekday], blocksApps: true, createdAt: today)
        let t2 = Task(title: "Read 20 pages", activeDays: [weekday], blocksApps: true, createdAt: today)
        let t3 = Task(title: "Go for a walk", activeDays: [weekday], blocksApps: true, createdAt: today, stepTarget: 7500)
        let t4 = Task(title: "Do laundry", activeDays: [weekday], blocksApps: false, createdAt: today)

        store.addTask(t1)
        store.addTask(t2)
        store.addTask(t3)
        store.addTask(t4)

        store.completeTask(t1.id, on: todayString)
        store.completeTask(t2.id, on: todayString)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        store.streakData = StreakData(currentStreak: 14, longestStreak: 14,
                                      lastCompletedDate: yesterday.dateString)
        store.hasCompletedOnboarding = true
        #endif
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

