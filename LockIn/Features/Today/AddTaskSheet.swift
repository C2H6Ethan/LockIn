import SwiftUI
import CoreLocation

struct AddTaskSheet: View {

    @Bindable var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var repeats = false
    @State private var selectedDays: Set<Int> = []
    @State private var onceStartDate: String = Date().dateString
    @State private var showingDatePicker = false
    @State private var pickerDate = Date()
    @State private var blocksApps = true
    @State private var blockingStartTime: DateComponents? = nil
    @State private var showingStartTimePicker = false
    @State private var startTimePicker = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var hasStepGoal = false
    @State private var stepTarget: Int = 5_000
    @State private var hasLocation = false
    @State private var selectedLocation: TaskLocation? = nil
    @State private var confirmingPin: TaskLocation? = nil
    @State private var showLocationDeniedHint = false
    @State private var isSubmitting = false
    @FocusState private var titleFocused: Bool

    private let stepOptions: [(value: Int, label: String)] = [
        (1_000, "1k"), (2_500, "2.5k"), (5_000, "5k"), (7_500, "7.5k"), (10_000, "10k"),
    ]

    // Calendar weekday order: Mon=2 … Sun=1, displayed Mon–Sun
    private let dayOptions: [(label: String, weekday: Int)] = [
        ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7), ("Sun", 1),
    ]

    private var canAdd: Bool {
        let titleOk = !title.trimmingCharacters(in: .whitespaces).isEmpty
        return repeats ? titleOk && !selectedDays.isEmpty : titleOk
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    showingStartTimePicker = false
                    titleFocused = false
                }

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    Spacer()

                    Text("New Task")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    Spacer()

                    Button {
                        guard !isSubmitting else { return }
                        isSubmitting = true
                        let recurrence: TaskRecurrence = repeats
                            ? .weekly(days: selectedDays)
                            : .once(startDate: onceStartDate)
                        let resolvedLocation = hasLocation ? (selectedLocation ?? confirmingPin) : nil
                        viewModel.addTask(
                            title: title.trimmingCharacters(in: .whitespaces),
                            recurrence: recurrence,
                            blocksApps: blocksApps,
                            stepTarget: hasStepGoal ? stepTarget : nil,
                            blockingStartTime: blockingStartTime,
                            location: resolvedLocation
                        )
                        dismiss()
                    } label: {
                        Text("Add")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(canAdd ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText.opacity(0.4))
                    }
                    .disabled(!canAdd || isSubmitting)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)

                Rectangle()
                    .fill(DesignSystem.Colors.secondaryText.opacity(0.15))
                    .frame(height: 0.5)

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        // Title field
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("What do you need to do?")
                                .font(.system(.subheadline))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)

                            TextField("", text: $title)
                                .font(.system(.title3, weight: .regular))
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                                .tint(DesignSystem.Colors.accent)
                                .focused($titleFocused)
                                .submitLabel(.done)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundStyle(DesignSystem.Colors.secondaryText.opacity(0.3))
                                        .offset(y: 8)
                                }
                        }
                        .padding(.top, DesignSystem.Spacing.sm)

                        // Repeats toggle
                        Toggle(isOn: $repeats) {
                            Text("Repeats")
                                .font(.system(.body))
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                        }
                        .tint(DesignSystem.Colors.accent)

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
                                            if isSelected { selectedDays.remove(option.weekday) }
                                            else { selectedDays.insert(option.weekday) }
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
                            // Once — start date picker
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
                                    startChip("Today",    selected: !isCustom && onceStartDate == todayStr)    { onceStartDate = todayStr;    showingDatePicker = false }
                                    startChip("Tomorrow", selected: !isCustom && onceStartDate == tomorrowStr) { onceStartDate = tomorrowStr; showingDatePicker = false }
                                    startChip(customLabel, selected: isCustom) { showingDatePicker = isCustom ? !showingDatePicker : true }
                                }

                                if isCustom && showingDatePicker {
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
                        if viewModel.isHealthKitAvailable {
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

                        // Location toggle + search
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Toggle(isOn: $hasLocation) {
                                Text("Location")
                                    .font(.system(.body))
                                    .foregroundStyle(DesignSystem.Colors.primaryText)
                            }
                            .tint(DesignSystem.Colors.accent)
                            .onChange(of: hasLocation) { _, on in
                                if on {
                                    let status = LocationVerificationService.shared.authorizationStatus
                                    if status == .denied || status == .restricted {
                                        showLocationDeniedHint = true
                                        hasLocation = false
                                    } else {
                                        showLocationDeniedHint = false
                                        if status == .notDetermined {
                                            LocationVerificationService.shared.requestAlwaysAuthorization()
                                        }
                                    }
                                } else if !showLocationDeniedHint {
                                    selectedLocation = nil
                                }
                            }

                            Text("Verifies you were there to complete")
                                .font(.system(.caption))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)

                            if showLocationDeniedHint {
                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text("Location access required. Open Settings →")
                                        .font(.system(.caption))
                                        .foregroundStyle(DesignSystem.Colors.overdue)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if hasLocation {
                            LocationSearchBar(selectedLocation: $selectedLocation, confirmingPin: $confirmingPin)
                        }

                        // Blocks Apps toggle + optional start time
                        Toggle(isOn: $blocksApps) {
                            Text("Blocks Apps")
                                .font(.system(.body))
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                        }
                        .tint(DesignSystem.Colors.accent)
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
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
        }
        .onAppear { titleFocused = true }
    }

    private func formatStartTime(_ comps: DateComponents) -> String {
        var c = comps; c.second = 0
        guard let date = Calendar.current.date(from: c) else { return "" }
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
    }

    @ViewBuilder
    private func startChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.secondaryText)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .background(selected ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
        }
        .buttonStyle(.plain)
    }
}
