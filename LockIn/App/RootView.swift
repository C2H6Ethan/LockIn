import FamilyControls
import LockInCore
import SwiftUI

/// Top-level navigation.
struct RootView: View {
    let environment: AppEnvironment
    @State private var showsBlocklist = false

    var body: some View {
        NavigationStack {
            TodayView(model: TodayModel(store: environment.store, onChange: environment.stateDidChange))
                .toolbar {
                    // Temporary until Settings (011) and Onboarding (012).
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Allow Screen Time") {
                                Task { try? await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
                            }
                            Button("Blocklist") { showsBlocklist = true }
                            NavigationLink("Event log") { EventLogView(store: environment.store) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
        }
        .tint(DesignSystem.Colors.accent)
        .sheet(isPresented: $showsBlocklist) {
            BlocklistEditorView(model: BlocklistEditorModel(store: environment.store, onSave: environment.stateDidChange))
        }
    }
}
