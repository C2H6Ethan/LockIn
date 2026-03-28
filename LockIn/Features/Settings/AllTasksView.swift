import SwiftUI

struct AllTasksView: View {

    @Bindable var viewModel: SettingsViewModel
    @State private var editingTask: Task? = nil

    // Calendar weekday order: Mon=2 … Sun=1
    private let dayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]
    private let dayLabels: [Int: String] = [
        2: "Mon", 3: "Tue", 4: "Wed",
        5: "Thu", 6: "Fri", 7: "Sat", 1: "Sun",
    ]

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            if viewModel.tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task, isLocked: viewModel.isLocked, viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(DesignSystem.Colors.background)
        }
        .sheet(isPresented: $viewModel.showingAddTask) {
            AddTaskSheet(viewModel: TodayViewModel())
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(DesignSystem.Colors.background)
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.tasks) { task in
                    taskRow(task)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("No tasks yet.")
                .font(.system(.body))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            Button {
                viewModel.showingAddTask = true
            } label: {
                Text("Add Task")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Row

    @ViewBuilder
    private func taskRow(_ task: Task) -> some View {
        Button {
            editingTask = task
        } label: {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                // Title + metadata
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(task.title)
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    metadataLine(for: task)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.secondaryText.opacity(0.5))
            }
            .padding(.vertical, DesignSystem.Spacing.sm + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metadataLine(for task: Task) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Date: once date or day abbreviations
            if task.isOnce {
                Text(onceDateLabel(for: task))
                    .font(.system(.caption))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            } else {
                HStack(spacing: 3) {
                    ForEach(dayOrder, id: \.self) { weekday in
                        if task.activeDays.contains(weekday) {
                            Text(dayLabels[weekday] ?? "")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                    if task.blocksApps, let startTime = task.blockingStartTime {
                        Text("· from \(formattedTime(startTime))")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignSystem.Colors.secondaryText.opacity(0.6))
                    }
                }
            }

            // Location
            if let locationName = task.location?.name {
                HStack(spacing: 3) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10))
                    Text(locationName)
                        .font(.system(.caption))
                }
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            }

            // Steps
            if let target = task.stepTarget {
                let thousands = Double(target) / 1_000
                let label = thousands.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(thousands))k steps"
                    : "\(String(format: "%.1f", thousands))k steps"
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10))
                    Text(label)
                        .font(.system(.caption))
                }
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
    }

    // MARK: - Helpers

    private func formattedTime(_ comps: DateComponents) -> String {
        var c = comps; c.second = 0
        guard let date = Calendar.current.date(from: c) else { return "" }
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
    }

    private func onceDateLabel(for task: Task) -> String {
        guard let startDateString = task.onceStartDate else { return "Once" }
        let today = Date().dateString
        if startDateString == today { return "Today" }
        guard let date = Date.from(dateString: startDateString) else { return "Once" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
