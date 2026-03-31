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
                // MARK: Section 1 — Blocked Apps & Websites
                Section {
                    Button {
                        viewModel.showingAppPicker = true
                    } label: {
                        HStack {
                            Text("Blocked Apps & Websites")
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
                    .familyActivityPicker(isPresented: $viewModel.showingAppPicker, selection: $pickerSelection)
                    .onChange(of: pickerSelection) { _, newValue in
                        viewModel.saveSelectedApps(newValue)
                        pickerSelection = SharedStore.shared.selectedApps
                    }
                    .swipeActions(edge: .trailing) {
                        if viewModel.selectedCount > 0 && !viewModel.isLocked {
                            Button(role: .destructive) {
                                viewModel.clearAllBlocked()
                                pickerSelection = FamilyActivitySelection()
                            } label: {
                                Label("Clear", systemImage: "trash")
                            }
                        }
                    }
                }
                .listRowBackground(DesignSystem.Colors.background)

                // MARK: Section 1b — Blocked Custom Domains
                Section {
                    NavigationLink {
                        BlockCustomURLsView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Text("Blocked Custom Domains")
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                            Spacer()
                            Text(viewModel.customDomainSummary)
                                .font(.system(.subheadline))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if !viewModel.customDomains.isEmpty && !viewModel.isLocked {
                            Button(role: .destructive) {
                                viewModel.clearCustomDomains()
                            } label: {
                                Label("Clear", systemImage: "trash")
                            }
                        }
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
                    .swipeActions(edge: .trailing) {
                        if !viewModel.tasks.isEmpty && !viewModel.isLocked {
                            Button(role: .destructive) {
                                viewModel.deleteAllTasks()
                            } label: {
                                Label("Clear", systemImage: "trash")
                            }
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
                #if DEBUG
                // MARK: Section — Activity Log (debug only)
                Section {
                    NavigationLink {
                        DebugLogView()
                    } label: {
                        Text("Activity Log")
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
                .listRowBackground(DesignSystem.Colors.background)
                #endif
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
