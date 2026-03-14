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

            List {
                ForEach(viewModel.tasks) { task in
                    Button {
                        editingTask = task
                    } label: {
                        taskRow(task)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(DesignSystem.Colors.background)
                }
                .onDelete { indexSet in
                    guard !viewModel.isLocked else { return }
                    for index in indexSet {
                        viewModel.deleteTask(id: viewModel.tasks[index].id)
                    }
                }
                .deleteDisabled(viewModel.isLocked)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
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
        }
        .sheet(isPresented: $viewModel.showingAddTask) {
            AddTaskSheet(viewModel: TodayViewModel())
        }
        .onAppear {
            viewModel.onAppear()
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

    // MARK: - Row

    @ViewBuilder
    private func taskRow(_ task: Task) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(task.title)
                    .font(.system(.body))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                if let target = task.stepTarget {
                    let thousands = Double(target) / 1_000
                    let label = thousands.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(thousands))k steps"
                        : "\(String(format: "%.1f", thousands))k steps"
                    Text(label)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(task.blocksApps ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                } else if task.isOnce {
                    Text(onceDateLabel(for: task))
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(task.blocksApps ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                } else {
                    // Day chips sorted Mon–Sun
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(dayOrder, id: \.self) { weekday in
                            if task.activeDays.contains(weekday) {
                                Text(dayLabels[weekday] ?? "")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(
                                        task.blocksApps
                                            ? DesignSystem.Colors.accent
                                            : DesignSystem.Colors.secondaryText
                                    )
                            }
                        }
                        if task.blocksApps, let startTime = task.blockingStartTime {
                            Text("· from \(formattedTime(startTime))")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
