import SwiftUI

struct ContentView: View {

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
            case "bypass": showBypass = true
            case "today":  selectedTab = 0
            default: break
            }
        }
        .fullScreenCover(isPresented: $showBypass) {
            StepsChallengeView()
        }
    }
}
