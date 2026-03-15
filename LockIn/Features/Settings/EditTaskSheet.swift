import SwiftUI

struct EditTaskSheet: View {

    let task: Task
    let isLocked: Bool
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var repeats: Bool
    @State private var selectedDays: Set<Int>
    @State private var onceStartDate: String
    @State private var showingDatePicker = false
    @State private var pickerDate = Date()
    @State private var blocksApps: Bool
    @State private var blockingStartTime: DateComponents?
    @State private var showingStartTimePicker = false
    @State private var startTimePicker: Date
    @State private var hasStepGoal: Bool
    @State private var stepTarget: Int

    // Calendar weekday order: Mon=2 … Sun=1, displayed Mon–Sun
    private let dayOptions: [(label: String, weekday: Int)] = [
        ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7), ("Sun", 1),
    ]

    private let stepOptions: [(value: Int, label: String)] = [
        (1_000, "1k"), (2_500, "2.5k"), (5_000, "5k"), (7_500, "7.5k"), (10_000, "10k"),
    ]

    init(task: Task, isLocked: Bool = false, viewModel: SettingsViewModel) {
        self.task = task
        self.isLocked = isLocked
        self.viewModel = viewModel
        _title = State(initialValue: task.title)
        _repeats = State(initialValue: !task.isOnce)
        _selectedDays = State(initialValue: task.activeDays)
        _onceStartDate = State(initialValue: task.onceStartDate ?? Date().dateString)
        _blocksApps = State(initialValue: task.blocksApps)
        _blockingStartTime = State(initialValue: task.blockingStartTime)
        let defaultPickerTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
        if let comps = task.blockingStartTime, let date = Calendar.current.date(from: comps) {
            _startTimePicker = State(initialValue: date)
        } else {
            _startTimePicker = State(initialValue: defaultPickerTime)
        }
        _hasStepGoal = State(initialValue: task.stepTarget != nil)
        _stepTarget = State(initialValue: task.stepTarget ?? 5_000)
    }

    private var canSave: Bool {
        let titleOk = !title.trimmingCharacters(in: .whitespaces).isEmpty
        return repeats ? titleOk && !selectedDays.isEmpty : titleOk
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showingStartTimePicker = false }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                Text("Edit Task")
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .padding(.top, DesignSystem.Spacing.lg)

                // Title field
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("What do you need to do?")
                        .font(.system(.subheadline))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    TextField("", text: $title)
                        .font(.system(.title3, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .tint(DesignSystem.Colors.accent)
                        .submitLabel(.done)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(DesignSystem.Colors.secondaryText.opacity(0.3))
                                .offset(y: 8)
                        }
                }

                // Repeats toggle — disabled when locked (can't change recurrence type)
                Toggle(isOn: $repeats) {
                    Text("Repeats")
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                .tint(DesignSystem.Colors.accent)
                .disabled(isLocked)

                if repeats {
                    // Day picker
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Repeat on")
                            .font(.system(.subheadline))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(dayOptions, id: \.weekday) { option in
                                let isSelected = selectedDays.contains(option.weekday)
                                Button {
                                    if isSelected {
                                        // When locked, only deselect days added this session
                                        let isOriginalDay = task.activeDays.contains(option.weekday)
                                        if !isLocked || !isOriginalDay {
                                            selectedDays.remove(option.weekday)
                                        }
                                    } else {
                                        selectedDays.insert(option.weekday)
                                    }
                                } label: {
                                    Text(option.label)
                                        .font(.system(.caption, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(
                                            isSelected
                                                ? DesignSystem.Colors.background
                                                : DesignSystem.Colors.secondaryText
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.sm)
                                        .padding(.vertical, DesignSystem.Spacing.xs + 2)
                                        .background(
                                            isSelected
                                                ? DesignSystem.Colors.accent
                                                : DesignSystem.Colors.secondaryText.opacity(0.12)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    // Once — start date
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Starting")
                            .font(.system(.subheadline))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)

                        let todayStr = Date().dateString
                        let tomorrowStr = Calendar.current.date(byAdding: .day, value: 1, to: Date())!.dateString
                        let isCustom = showingDatePicker || (onceStartDate != todayStr && onceStartDate != tomorrowStr)

                        let customLabel: String = {
                            guard isCustom, !showingDatePicker,
                                  let d = Date.from(dateString: onceStartDate) else { return "Pick date" }
                            let f = DateFormatter()
                            f.dateFormat = "MMM d"
                            f.locale = Locale(identifier: "en_US_POSIX")
                            return f.string(from: d)
                        }()

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            startChip("Today",     selected: !isCustom && onceStartDate == todayStr,    disabled: isLocked) { onceStartDate = todayStr;    showingDatePicker = false }
                            startChip("Tomorrow",  selected: !isCustom && onceStartDate == tomorrowStr, disabled: isLocked) { onceStartDate = tomorrowStr; showingDatePicker = false }
                            startChip(customLabel, selected: isCustom,                                  disabled: isLocked) { showingDatePicker = isCustom ? !showingDatePicker : true }
                        }

                        if isCustom && showingDatePicker && !isLocked {
                            DatePicker("", selection: $pickerDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(DesignSystem.Colors.accent)
                                .onChange(of: pickerDate) { _, newDate in
                                    onceStartDate = newDate.dateString
                                    showingDatePicker = false
                                }
                        }
                    }
                }

                // Step goal toggle + chips — hidden if HealthKit unavailable
                if StepCountService.shared.isAvailable {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Toggle(isOn: $hasStepGoal) {
                            Text("Step goal")
                                .font(.system(.body))
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                        }
                        .tint(DesignSystem.Colors.accent)

                        Text("Auto-completes task with steps")
                            .font(.system(.caption))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }

                    if hasStepGoal {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(stepOptions, id: \.value) { option in
                                let isSelected = stepTarget == option.value
                                Button { stepTarget = option.value } label: {
                                    Text(option.label)
                                        .font(.system(.caption, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(
                                            isSelected
                                                ? DesignSystem.Colors.background
                                                : DesignSystem.Colors.secondaryText
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.sm)
                                        .padding(.vertical, DesignSystem.Spacing.xs + 2)
                                        .background(
                                            isSelected
                                                ? DesignSystem.Colors.accent
                                                : DesignSystem.Colors.secondaryText.opacity(0.12)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Blocks Apps toggle + optional start time
                Toggle(isOn: $blocksApps) {
                    Text("Blocks Apps")
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                .tint(DesignSystem.Colors.accent)
                .disabled(isLocked && blocksApps)
                .onChange(of: blocksApps) { _, on in
                    if !on { blockingStartTime = nil; showingStartTimePicker = false }
                }

                if blocksApps {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("from")
                                .font(.system(.caption))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                            startChip("Start of Day", selected: blockingStartTime == nil) {
                                blockingStartTime = nil
                                showingStartTimePicker = false
                            }
                            startChip(blockingStartTime == nil ? "Set time" : formatStartTime(blockingStartTime!),
                                      selected: blockingStartTime != nil) {
                                if blockingStartTime == nil {
                                    blockingStartTime = Calendar.current.dateComponents([.hour, .minute], from: startTimePicker)
                                }
                                showingStartTimePicker.toggle()
                            }
                        }
                        if showingStartTimePicker {
                            DatePicker("", selection: $startTimePicker, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .tint(DesignSystem.Colors.accent)
                                .colorScheme(.dark)
                                .onChange(of: startTimePicker) { _, date in
                                    blockingStartTime = Calendar.current.dateComponents([.hour, .minute], from: date)
                                }
                        }
                    }
                }

                Spacer()

                // Save button
                Button {
                    let recurrence: TaskRecurrence = repeats
                        ? .weekly(days: selectedDays)
                        : .once(startDate: onceStartDate)
                    let updated = Task(
                        id: task.id,
                        title: title.trimmingCharacters(in: .whitespaces),
                        recurrence: recurrence,
                        blocksApps: blocksApps,
                        createdAt: task.createdAt,
                        stepTarget: hasStepGoal ? stepTarget : nil,
                        blockingStartTime: blockingStartTime
                    )
                    viewModel.updateTask(updated)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(canSave ? DesignSystem.Colors.background : DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(canSave ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                }
                .disabled(!canSave)

                // Delete button — hidden when locked
                if !isLocked {
                    Button {
                        viewModel.deleteTask(id: task.id)
                        dismiss()
                    } label: {
                        Text("Delete Task")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                } else {
                    Spacer()
                        .frame(height: DesignSystem.Spacing.lg)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    private func formatStartTime(_ comps: DateComponents) -> String {
        var c = comps; c.second = 0
        guard let date = Calendar.current.date(from: c) else { return "" }
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
    }

    @ViewBuilder
    private func startChip(_ label: String, selected: Bool, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.secondaryText)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .background(selected ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                .opacity(disabled && !selected ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
