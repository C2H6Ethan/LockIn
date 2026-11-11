import LockInCore
import LockInPlatform
import SwiftUI

/// Top-level navigation.
struct RootView: View {
    let environment: AppEnvironment
    @State private var formTask: FormTarget?
    @State private var dataVersion = 0
    @State private var recap: RecapModel?
    @State private var path: [Route] = []
    @State private var needsOnboarding: Bool

    init(environment: AppEnvironment) {
        self.environment = environment
        _needsOnboarding = State(initialValue: !environment.store.read(.settings).hasCompletedOnboarding)
    }

    private enum Route: Hashable { case settings }
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
        if needsOnboarding {
            OnboardingView(
                model: .live(environment: environment, onFinish: {
                    environment.stateDidChange()
                    withAnimation { needsOnboarding = false }
                }),
                environment: environment
            )
        } else {
            main
        }
    }

    private var main: some View {
        NavigationStack(path: $path) {
            TodayView(
                model: TodayModel(store: environment.store, onChange: environment.stateDidChange),
                onAddTask: { formTask = .new },
                onEditTask: { formTask = .edit($0) }
            )
                .id(dataVersion)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { formTask = .new } label: {
                            Image(systemName: "plus").foregroundStyle(DesignSystem.Colors.accent)
                        }
                        .accessibilityLabel("Add Task")
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(value: Route.settings) {
                            Image(systemName: "gearshape")
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings:
                        SettingsView(
                            model: SettingsModel(store: environment.store, onChange: environment.stateDidChange),
                            environment: environment,
                            onAddTask: { formTask = .new },
                            onEditTask: { formTask = .edit($0) },
                            dataVersion: dataVersion
                        )
                    }
                }
        }
        .tint(DesignSystem.Colors.accent)
        #if DEBUG
        .onAppear {
            if DebugLaunch.opensNewTask { formTask = .new }
            if DebugLaunch.opensSettings { Task { path = [.settings] } }
        }
        #endif
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            // Launch and every return to the foreground: re-sync schedules, finalize ended Days and the
            // Shield first, so the recap below sees yesterday's record.
            environment.enforcement.refresh(reason: "foreground")
            if recap == nil { recap = RecapModel.pending(store: environment.store) }
            dataVersion += 1
        }
        .fullScreenCover(item: $recap) { model in
            RecapView(model: model) {
                recap = nil
                dataVersion += 1
            }
        }
        .sheet(item: $formTask, onDismiss: { dataVersion += 1 }) { target in
            switch target {
            case .new:
                TaskFormView(model: TaskFormModel(editing: nil, store: environment.store, onChange: environment.stateDidChange))
            case .edit(let task):
                TaskFormView(model: TaskFormModel(editing: task, store: environment.store, onChange: environment.stateDidChange))
            }
        }
    }
}
