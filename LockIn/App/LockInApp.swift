import FamilyControls
import LockInPlatform
import SwiftUI

@main
struct LockInApp: App {
    private let environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DebugHomeView(environment: environment)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Launch and every return to the foreground re-sync schedules and the Shield.
            if phase == .active { environment.enforcement.refresh(reason: "foreground") }
        }
    }
}

/// Temporary home until the Today screen (006). Lets the Blocklist be exercised on device.
private struct DebugHomeView: View {
    let environment: AppEnvironment
    @State private var showsBlocklist = false

    var body: some View {
        NavigationStack {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("LockIn")
                .font(.system(.largeTitle, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Button("Allow Screen Time") {
                Task { try? await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
            }
            Button("Blocklist") { showsBlocklist = true }
            NavigationLink("Event log") { EventLogView(store: environment.store) }
            Spacer()
        }
        .tint(DesignSystem.Colors.accent)
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showsBlocklist) {
            BlocklistEditorView(model: BlocklistEditorModel(store: environment.store, onSave: environment.stateDidChange))
        }
        }
    }
}
