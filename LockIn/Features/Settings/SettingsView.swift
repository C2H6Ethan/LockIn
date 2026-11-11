import FamilyControls
import LockInCore
import LockInPlatform
import SwiftUI

/// Everything that isn't Today.
struct SettingsView: View {
    @State var model: SettingsModel
    let environment: AppEnvironment
    var onAddTask: () -> Void
    var onEditTask: (LockInTask) -> Void
    /// Changes whenever Tasks may have been edited elsewhere, e.g. in the Task form sheet.
    var dataVersion: Int

    @State private var showsBlocklist = false
    @State private var showsEventLog = false
    @State private var choosesLockDuration = false
    @ObservedObject private var authorization = AuthorizationCenter.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                tasksSection
                blockingSection
                reminderSection
                lockSection
                Text(model.appVersion)
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .onLongPressGesture { showsEventLog = true }
                    .padding(.top, DesignSystem.Spacing.lg)
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignSystem.Colors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsEventLog) { EventLogView(store: environment.store) }
        .sheet(isPresented: $showsBlocklist) {
            BlocklistEditorView(model: BlocklistEditorModel(store: environment.store, onSave: environment.stateDidChange))
        }
        .onAppear { model.reload() }
        .onChange(of: dataVersion) { model.reload() }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel("Tasks")
                Spacer()
                Button("Add", action: onAddTask)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .padding(.bottom, DesignSystem.Spacing.sm)

            if model.tasks.isEmpty {
                Text("No tasks yet.")
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            }
            ForEach(model.requiredTasks) { taskRow($0) }
            if !model.optionalTasks.isEmpty {
                SectionLabel("Optional")
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                ForEach(model.optionalTasks) { taskRow($0) }
            }
        }
    }

    private func taskRow(_ task: LockInTask) -> some View {
        Button { onEditTask(task) } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(task.title).foregroundStyle(DesignSystem.Colors.primaryText)
                    Text(model.describe(task))
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionLabel("Blocking")
            row(title: "Blocklist", detail: "Apps, categories and websites") { showsBlocklist = true }
            row(title: "Screen Time access", detail: authorizationText) {
                Task { try? await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
            }
        }
    }

    private var authorizationText: String {
        switch authorization.authorizationStatus {
        case .approved: return "Allowed"
        case .denied: return "Not allowed. Blocking can't work until you allow it."
        default: return "Not set up yet. Tap to allow."
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionLabel("Reminder")
            Toggle(isOn: Binding(
                get: { model.reminderTime != nil },
                set: { model.reminderTime = $0 ? Settings.defaultReminderTime : nil }
            )) {
                Text("Daily reminder").foregroundStyle(DesignSystem.Colors.primaryText)
            }
            if let time = model.reminderTime {
                Picker("Time", selection: Binding(get: { time }, set: { model.reminderTime = $0 })) {
                    ForEach(TaskFormModel.startTimeChoices, id: \.self) { Text($0.description).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(DesignSystem.Colors.accent)
            }
            Text("Only sent if required tasks are still open.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }

    private var lockSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionLabel("Lock Mode")
            if let until = model.lockedUntil {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Locked until \(until.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    Text("You can add tasks and add to the Blocklist, but not remove or weaken anything.")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                Button("Extend") { choosesLockDuration = true }
                    .foregroundStyle(DesignSystem.Colors.accent)
            } else {
                row(title: "Lock Mode", detail: "Commit for a while: only stricter changes allowed") { choosesLockDuration = true }
            }
            Text("Turning off Screen Time access in iOS Settings can't be prevented.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .confirmationDialog("Lock for how long?", isPresented: $choosesLockDuration, titleVisibility: .visible) {
            ForEach(LockMode.durations, id: \.self) { days in
                Button(days == 1 ? "1 day" : "\(days) days") { model.lock(days: days) }
            }
        } message: {
            Text("Until it ends you can't delete tasks, make them optional, or remove anything from the Blocklist. It can't be ended early.")
        }
    }

    private func row(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title).foregroundStyle(DesignSystem.Colors.primaryText)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
