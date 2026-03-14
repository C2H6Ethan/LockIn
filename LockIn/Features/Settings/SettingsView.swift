import SwiftUI
import FamilyControls

struct SettingsView: View {

    @State private var viewModel = SettingsViewModel()
    @State private var pickerSelection = SharedStore.shared.selectedApps
    @State private var showingReminderSheet = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            List {
                // MARK: Section 1 — Blocked Apps
                Section {
                    Button {
                        viewModel.showingAppPicker = true
                    } label: {
                        HStack {
                            Text("Blocked Apps")
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                            Spacer()
                            Text(viewModel.appSelectionSummary)
                                .font(.system(.subheadline))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                    .familyActivityPicker(
                        isPresented: $viewModel.showingAppPicker,
                        selection: $pickerSelection
                    )
                    .onChange(of: pickerSelection) { _, newValue in
                        viewModel.saveSelectedApps(newValue)
                        // Sync back the enforced selection so the picker reflects
                        // the actual stored state (add-only when locked).
                        pickerSelection = SharedStore.shared.selectedApps
                    }
                }
                .listRowBackground(DesignSystem.Colors.background)

                // MARK: Section 2 — Tasks
                Section {
                    NavigationLink {
                        AllTasksView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Text("Tasks")
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                            Spacer()
                            let count = viewModel.tasks.count
                            Text(count == 0 ? "No tasks" : "\(count) task\(count == 1 ? "" : "s")")
                                .font(.system(.subheadline))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .listRowBackground(DesignSystem.Colors.background)

                // MARK: Section 4 — Reminder
                Section {
                    Button {
                        showingReminderSheet = true
                    } label: {
                        HStack {
                            Text("Daily Reminder")
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                            Spacer()
                            Text(viewModel.reminderSummary)
                                .font(.system(.subheadline))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .listRowBackground(DesignSystem.Colors.background)

                // MARK: Section 3 — Lock Mode
                Section {
                    if viewModel.isLocked {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(DesignSystem.Colors.accent)
                            Text(viewModel.lockedUntilSummary)
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                        }
                    } else {
                        Button {
                            viewModel.showingLockSheet = true
                        } label: {
                            HStack {
                                Text("Lock Mode")
                                    .foregroundStyle(DesignSystem.Colors.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                            }
                        }
                    }
                }
                .listRowBackground(DesignSystem.Colors.background)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $viewModel.showingLockSheet) {
            LockSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingReminderSheet, onDismiss: { viewModel.onAppear() }) {
            ReminderTimeSheet()
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

}
