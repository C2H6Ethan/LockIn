import FamilyControls
import LockInCore
import SwiftUI

/// Top-level navigation.
struct RootView: View {
    let environment: AppEnvironment
    @State private var showsBlocklist = false
    @State private var formTask: FormTarget?
    @State private var todayReload = 0
    @State private var recap: RecapModel?
    @Environment(\.scenePhase) private var scenePhase

    /// What the Task form is open for.
    private enum FormTarget: Identifiable {
        case new
        case edit(LockInTask)
        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let t): return t.id.uuidString
            }
        }
    }

    var body: some View {
        NavigationStack {
            TodayView(
                model: TodayModel(store: environment.store, onChange: environment.stateDidChange),
                onAddTask: { formTask = .new },
                onEditTask: { formTask = .edit($0) }
            )
                .id(todayReload)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { formTask = .new } label: {
                            Image(systemName: "plus").foregroundStyle(DesignSystem.Colors.accent)
                        }
                        .accessibilityLabel("Add Task")
                    }
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
        #if DEBUG
        .onAppear { if DebugLaunch.opensNewTask { formTask = .new } }
        #endif
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Enforcement.refresh (run by LockInApp on foreground) finalizes ended Days first.
            if phase == .active, recap == nil { recap = RecapModel.pending(store: environment.store) }
        }
        .fullScreenCover(item: $recap) { model in
            RecapView(model: model) {
                recap = nil
                todayReload += 1
            }
        }
        .sheet(item: $formTask, onDismiss: { todayReload += 1 }) { target in
            switch target {
            case .new:
                TaskFormView(model: TaskFormModel(editing: nil, store: environment.store, onChange: environment.stateDidChange))
            case .edit(let task):
                TaskFormView(model: TaskFormModel(editing: task, store: environment.store, onChange: environment.stateDidChange))
            }
        }
        .sheet(isPresented: $showsBlocklist) {
            BlocklistEditorView(model: BlocklistEditorModel(store: environment.store, onSave: environment.stateDidChange))
        }
    }
}
