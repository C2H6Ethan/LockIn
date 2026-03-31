import SwiftUI
import UserNotifications

struct ContentView: View {

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showBypass = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Tasks", systemImage: "checkmark.circle")
            }
            .tag(0)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(1)
        }
        .tint(DesignSystem.Colors.accent)
        .onOpenURL { url in
            switch url.host {
            case "bypass":
                clearBypassNotification()
                showBypass = true
            case "today":  selectedTab = 0
            default: break
            }
        }
        .fullScreenCover(isPresented: $showBypass) {
            StepsChallengeView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !showBypass && SharedStore.shared.bypassRequested {
                clearBypassNotification()
                showBypass = true
            }
        }
    }

    private func clearBypassNotification() {
        SharedStore.shared.bypassRequested = false
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Constants.Stepping.notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [Constants.Stepping.notificationID])
    }
}
