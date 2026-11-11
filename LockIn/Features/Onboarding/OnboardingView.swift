import FamilyControls
import LockInCore
import LockInPlatform
import SwiftUI

/// First run: one small screen per step, big two-line headline, one primary action at the bottom.
struct OnboardingView: View {
    @State var model: OnboardingModel
    let environment: AppEnvironment

    @State private var showsBlocklist = false
    @State private var showsTaskForm = false
    @State private var dataVersion = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            content
                .id(model.step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            Spacer()
            actions
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.background)
        .animation(.easeInOut(duration: 0.25), value: model.step)
        .sheet(isPresented: $showsBlocklist, onDismiss: { dataVersion += 1 }) {
            BlocklistEditorView(model: BlocklistEditorModel(store: environment.store, onSave: environment.stateDidChange))
        }
        .sheet(isPresented: $showsTaskForm, onDismiss: { dataVersion += 1 }) {
            TaskFormView(model: TaskFormModel(editing: nil, store: environment.store, onChange: environment.stateDidChange))
        }
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .welcome:
            page("Lock In.", "Block distracting apps until your tasks are done.")
        case .screenTime:
            page("How blocking\nworks.",
                 model.screenTimeDenied
                    ? "Lock In needs Screen Time access to block anything. Nothing leaves your device. Allow it to continue."
                    : "Lock In uses Apple's Screen Time to shield distracting apps until you finish what matters.\n\nNo accounts. No servers. Everything stays on your device.")
        case .blocklist:
            page("Block your\ndistractions.", blocklistSubtitle)
        case .firstTask:
            page("Add your\nfirst task.", firstTaskSubtitle)
        case .notifications:
            page("A nudge,\nif needed.", "One reminder in the evening, only on days you still have required tasks open. You can change the time in Settings.")
        case .done:
            page("You're\nlocked in.", model.doneSubtitle)
        }
    }

    private var blocklistSubtitle: String {
        _ = dataVersion
        let blocklist = environment.store.read(.blocklist)
        return blocklist.isEmpty
            ? "Pick the apps, categories and websites you reach for when you should be doing something else."
            : "Blocklist saved. You can change it any time in Settings."
    }

    private var firstTaskSubtitle: String {
        _ = dataVersion
        let tasks = environment.store.read(.tasks)
        return tasks.isEmpty
            ? "Something you'll do every day. Required tasks keep your Blocklist shielded until they're done."
            : "Added \(tasks.map(\.title).joined(separator: ", ")). Add more now or later."
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            switch model.step {
            case .welcome:
                PrimaryButton("Get started") { advance() }
            case .screenTime:
                PrimaryButton(model.screenTimeDenied ? "Try again" : "Allow Screen Time", isWorking: model.isWorking) { advance() }
            case .blocklist:
                let empty = { _ = dataVersion; return environment.store.read(.blocklist).isEmpty }()
                PrimaryButton(empty ? "Choose what to block" : "Continue") {
                    if empty { showsBlocklist = true } else { advance() }
                }
                SecondaryButton(empty ? "Skip for now" : "Change Blocklist") {
                    if empty { advance() } else { showsBlocklist = true }
                }
            case .firstTask:
                let none = { _ = dataVersion; return environment.store.read(.tasks).isEmpty }()
                PrimaryButton(none ? "Add a task" : "Continue") {
                    if none { showsTaskForm = true } else { advance() }
                }
                SecondaryButton(none ? "Skip for now" : "Add another") {
                    if none { advance() } else { showsTaskForm = true }
                }
            case .notifications:
                PrimaryButton("Allow notifications", isWorking: model.isWorking) { advance() }
            case .done:
                PrimaryButton("Start") { model.finish() }
            }
        }
    }

    private func advance() {
        Task { await model.continue() }
    }

    private func page(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text(title)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension OnboardingModel {
    /// Production wiring: real permission prompts.
    static func live(environment: AppEnvironment, onFinish: @escaping () -> Void) -> OnboardingModel {
        OnboardingModel(
            store: environment.store,
            requestScreenTime: {
                try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                return AuthorizationCenter.shared.authorizationStatus == .approved
            },
            requestNotifications: {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            },
            onFinish: onFinish
        )
    }
}
