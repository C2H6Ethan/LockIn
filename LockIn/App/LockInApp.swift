import FamilyControls
import SwiftUI

@main
struct LockInApp: App {
    private let environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            DebugHomeView(environment: environment)
                .preferredColorScheme(.dark)
        }
    }
}

/// Temporary home until the Today screen (006). Lets the Blocklist be exercised on device.
private struct DebugHomeView: View {
    let environment: AppEnvironment
    @State private var showsBlocklist = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("LockIn")
                .font(.system(.largeTitle, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Button("Allow Screen Time") {
                Task { try? await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
            }
            Button("Blocklist") { showsBlocklist = true }
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
