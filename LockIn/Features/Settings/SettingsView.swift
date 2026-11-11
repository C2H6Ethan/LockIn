import FamilyControls
import LockInCore
import LockInPlatform
import SwiftUI

/// Everything that isn't Today.
struct SettingsView: View {
    @State var model: SettingsModel
    let environment: AppEnvironment

    @State private var showsBlocklist = false
    @State private var showsEventLog = false
    @State private var showsLockSheet = false
    @State private var blocklist = Blocklist()
    @ObservedObject private var authorization = AuthorizationCenter.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                lockSection
                blockingSection
                reminderSection
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    SectionLabel("About")
                    Text(model.appVersion)
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .onLongPressGesture { showsEventLog = true }
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignSystem.Colors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsEventLog) { EventLogView(store: environment.store) }
        .sheet(isPresented: $showsBlocklist, onDismiss: reload) {
            BlocklistEditorView(model: BlocklistEditorModel(store: environment.store, onSave: environment.stateDidChange))
        }
        .sheet(isPresented: $showsLockSheet, onDismiss: reload) {
            LockModeSheet(model: model)
                .presentationDragIndicator(.visible)
        }
        .onAppear(perform: reload)
        #if DEBUG
        .onAppear { if DebugLaunch.opensLockSheet { showsLockSheet = true } }
        #endif
    }

    private func reload() {
        model.reload()
        blocklist = environment.store.read(.blocklist)
    }

    /// "12 apps, 2 categories, 3 websites"
    private var blocklistText: String {
        let websites = blocklist.webDomainCount + blocklist.customDomains.count
        let parts = [(blocklist.appCount, "app", "apps"), (blocklist.categoryCount, "category", "categories"), (websites, "website", "websites")]
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.0 == 1 ? $0.1 : $0.2)" }
        return parts.isEmpty ? "Empty. Choose what to block." : parts.joined(separator: ", ")
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionLabel("Blocking")
            row(title: "Blocklist", detail: blocklistText) { showsBlocklist = true }
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
            Text("Only sent while required tasks are still open.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }

    private var lockSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionLabel("Lock Mode")
            if let until = model.lockedUntil {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Locked until \(until.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))")
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                        Text("Only stricter changes until then.")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                    Spacer(minLength: DesignSystem.Spacing.md)
                    Button("Extend") { showsLockSheet = true }
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            } else {
                row(title: "Lock Mode", detail: "Off. While it's on, you can only make Lock In stricter.") { showsLockSheet = true }
            }
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
