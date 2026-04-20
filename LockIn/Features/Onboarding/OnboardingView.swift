import SwiftUI
import FamilyControls
import UserNotifications
import CoreLocation

struct OnboardingView: View {

    let onComplete: () -> Void

    @State private var step = 0
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    @Environment(\.scenePhase) private var scenePhase

    // First task state — mirrors AddTaskSheet
    @State private var habitTitle = ""
    @State private var habitRepeats = true
    @State private var habitDays: Set<Int> = []
    @State private var habitStartDate: String = Date().dateString
    @State private var habitShowingDatePicker = false
    @State private var habitPickerDate = Date()
    @State private var habitBlocksApps = true
    @State private var habitBlockingStartTime: DateComponents? = nil
    @State private var habitShowingStartTimePicker = false
    @State private var habitStartTimePicker = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var habitHasStepGoal = false
    @State private var habitStepTarget: Int = 5_000
    @State private var habitHasLocation = false
    @State private var habitSelectedLocation: TaskLocation? = nil
    @State private var habitConfirmingPin: TaskLocation? = nil
    @State private var habitLocationDenied = false
    @FocusState private var habitFieldFocused: Bool

    private let stepOptions: [(value: Int, label: String)] = [
        (1_000, "1k"), (2_500, "2.5k"), (5_000, "5k"), (7_500, "7.5k"), (10_000, "10k"),
    ]

    private let dayOptions: [(label: String, weekday: Int)] = [
        ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7), ("Sun", 1),
    ]

    private var canAddTask: Bool {
        let titleOk = !habitTitle.trimmingCharacters(in: .whitespaces).isEmpty
        return habitRepeats ? titleOk && !habitDays.isEmpty : titleOk
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            if step == 0 {
                welcomeStep.transition(.opacity)
            } else if step == 1 {
                screenTimeStep.transition(.opacity)
            } else if step == 2 {
                healthKitStep.transition(.opacity)
            } else if step == 3 {
                notificationsStep.transition(.opacity)
            } else if step == 4 {
                appsStep.transition(.opacity)
            } else if step == 5 {
                habitStep.transition(.opacity)
            }
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
        .onChange(of: selection) {
            // Strip category tokens only — app and web domain tokens both contribute to blocking.
            var cleaned = selection
            cleaned.categoryTokens = []
            SharedStore.shared.selectedApps = cleaned
            BlockingService.shared.updateShieldsForCurrentHabitState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // User may have approved Screen Time in the system dialog while app was
            // backgrounded (or in Settings). Detect it when we come back to foreground.
            if newPhase == .active && step == 1
                && AuthorizationCenter.shared.authorizationStatus == .approved {
                advance()
            }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Spacer()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Lock In.")
                    .font(.system(.largeTitle, design: .default, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("Block distracting apps until your habits are done.")
                    .font(.system(.title3, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            primaryButton("Get started") { advance() }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    private var screenTimeStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Spacer()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("How blocking\nworks.")
                    .font(.system(.largeTitle, design: .default, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("Lock In uses Apple's Screen Time to block distracting apps until you finish what matters.\n\nNo accounts. No servers. No data collected.\nEverything stays on your device, always.")
                    .font(.system(.body, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            primaryButton("Got it. Let's set it up.") {
                _Concurrency.Task {
                    try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    // Advance if approved — iOS sometimes throws even on success,
                    // or defers the dialog until the next foreground cycle.
                    if AuthorizationCenter.shared.authorizationStatus == .approved {
                        advance()
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .onAppear {
            if AuthorizationCenter.shared.authorizationStatus == .approved { advance() }
        }
    }

    private var healthKitStep: some View {
        let healthAvailable = StepCountService.shared.isAvailable
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Spacer()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Track your\nsteps.")
                    .font(.system(.largeTitle, design: .default, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text(healthAvailable
                    ? "Lock In reads your step count from Apple Health to automatically complete step goal tasks. Step data is read only, stays on your device, and is never shared."
                    : "Lock In uses Apple Health on iPhone to read your step count and automatically complete step goal tasks. This device doesn't report step data, so step goals won't be available here — but the rest of Lock In works as usual.")
                    .font(.system(.body, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: DesignSystem.Spacing.sm) {
                if healthAvailable {
                    primaryButton("Connect Apple Health") {
                        _Concurrency.Task {
                            try? await StepCountService.shared.requestAuthorization()
                            advance()
                        }
                    }
                    skipButton { advance() }
                } else {
                    primaryButton("Continue") { advance() }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Spacer()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Earn your\nway in.")
                    .font(.system(.largeTitle, design: .default, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("When blocked, you can walk to earn temporary access. We'll notify you the moment you're ready.")
                    .font(.system(.body, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: DesignSystem.Spacing.sm) {
                primaryButton("Allow Notifications") {
                    _Concurrency.Task {
                        try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                        advance()
                    }
                }
                skipButton { advance() }
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    private var appsStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Spacer()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Block your\ndistractions.")
                    .font(.system(.largeTitle, design: .default, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("Pick the apps you reach for when you should be working.")
                    .font(.system(.body, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: DesignSystem.Spacing.sm) {
                if selection.applicationTokens.isEmpty {
                    primaryButton("Choose apps") { showingPicker = true }
                    skipButton { advance() }
                } else {
                    Text("\(selection.applicationTokens.count) app\(selection.applicationTokens.count == 1 ? "" : "s") selected")
                        .font(.system(.subheadline))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                    primaryButton("Continue") { advance() }
                    Button {
                        showingPicker = true
                    } label: {
                        Text("Change apps")
                            .font(.system(.subheadline))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    private var habitStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Add your\nfirst task.")
                    .font(.system(.largeTitle, design: .default, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                // Title
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("What do you need to do?")
                        .font(.system(.subheadline))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    TextField("", text: $habitTitle)
                        .font(.system(.title3, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .tint(DesignSystem.Colors.accent)
                        .focused($habitFieldFocused)
                        .submitLabel(.done)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(DesignSystem.Colors.secondaryText.opacity(0.3))
                                .offset(y: 8)
                        }
                }

                // Repeats toggle
                Toggle(isOn: $habitRepeats) {
                    Text("Repeats")
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                .tint(DesignSystem.Colors.accent)

                if habitRepeats {
                    // Day chips
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Repeat on")
                            .font(.system(.subheadline))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(dayOptions, id: \.weekday) { option in
                                let isSelected = habitDays.contains(option.weekday)
                                Button {
                                    if isSelected { habitDays.remove(option.weekday) }
                                    else { habitDays.insert(option.weekday) }
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
                    // Once — start date chips
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Starting")
                            .font(.system(.subheadline))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)

                        let todayStr = Date().dateString
                        let tomorrowStr = Calendar.current.date(byAdding: .day, value: 1, to: Date())!.dateString
                        let isCustom = habitShowingDatePicker || (habitStartDate != todayStr && habitStartDate != tomorrowStr)

                        let customLabel: String = {
                            guard isCustom, !habitShowingDatePicker,
                                  let d = Date.from(dateString: habitStartDate) else { return "Pick date" }
                            let f = DateFormatter()
                            f.dateFormat = "MMM d"
                            f.locale = Locale(identifier: "en_US_POSIX")
                            return f.string(from: d)
                        }()

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            startChip("Today",    selected: !isCustom && habitStartDate == todayStr)    { habitStartDate = todayStr;    habitShowingDatePicker = false }
                            startChip("Tomorrow", selected: !isCustom && habitStartDate == tomorrowStr) { habitStartDate = tomorrowStr; habitShowingDatePicker = false }
                            startChip(customLabel, selected: isCustom) { habitShowingDatePicker = isCustom ? !habitShowingDatePicker : true }
                        }

                        if isCustom && habitShowingDatePicker {
                            DatePicker("", selection: $habitPickerDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(DesignSystem.Colors.accent)
                                .onChange(of: habitPickerDate) { _, newDate in
                                    habitStartDate = newDate.dateString
                                    habitShowingDatePicker = false
                                }
                        }
                    }
                }

                // Step goal toggle — disabled when Apple Health unavailable on this device
                let stepHealthAvailable = StepCountService.shared.isAvailable
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Toggle(isOn: $habitHasStepGoal) {
                        Text("Step goal")
                            .font(.system(.body))
                            .foregroundStyle(stepHealthAvailable ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                    }
                    .tint(DesignSystem.Colors.accent)
                    .disabled(!stepHealthAvailable)

                    Text(stepHealthAvailable
                        ? "Auto-completes task using steps from Apple Health"
                        : "Requires Apple Health step data (iPhone only)")
                        .font(.system(.caption))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                if stepHealthAvailable, habitHasStepGoal {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(stepOptions, id: \.value) { option in
                            let isSelected = habitStepTarget == option.value
                            Button { habitStepTarget = option.value } label: {
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

                // Location toggle
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Toggle(isOn: $habitHasLocation) {
                        Text("Location")
                            .font(.system(.body))
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                    }
                    .tint(DesignSystem.Colors.accent)
                    .onChange(of: habitHasLocation) { _, on in
                        if on {
                            let status = LocationVerificationService.shared.authorizationStatus
                            if status == .denied || status == .restricted {
                                habitLocationDenied = true
                                habitHasLocation = false
                            } else {
                                habitLocationDenied = false
                                if status == .notDetermined {
                                    LocationVerificationService.shared.requestAlwaysAuthorization()
                                }
                            }
                        } else if !habitLocationDenied {
                            habitSelectedLocation = nil
                        }
                    }

                    Text("Verifies you were there to complete")
                        .font(.system(.caption))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    if habitLocationDenied {
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

                if habitHasLocation {
                    LocationSearchBar(selectedLocation: $habitSelectedLocation, confirmingPin: $habitConfirmingPin)
                }

                // Blocks Apps toggle + optional start time
                Toggle(isOn: $habitBlocksApps) {
                    Text("Blocks Apps")
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                .tint(DesignSystem.Colors.accent)
                .onChange(of: habitBlocksApps) { _, on in
                    if !on { habitBlockingStartTime = nil; habitShowingStartTimePicker = false }
                }

                if habitBlocksApps {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("from")
                                .font(.system(.caption))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                            startChip("Start of Day", selected: habitBlockingStartTime == nil) {
                                habitBlockingStartTime = nil
                                habitShowingStartTimePicker = false
                            }
                            startChip(habitBlockingStartTime == nil ? "Set time" : formatStartTime(habitBlockingStartTime!),
                                      selected: habitBlockingStartTime != nil) {
                                if habitBlockingStartTime == nil {
                                    habitBlockingStartTime = Calendar.current.dateComponents([.hour, .minute], from: habitStartTimePicker)
                                }
                                habitShowingStartTimePicker.toggle()
                            }
                        }
                        if habitShowingStartTimePicker {
                            DatePicker("", selection: $habitStartTimePicker, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .tint(DesignSystem.Colors.accent)
                                .colorScheme(.dark)
                                .onChange(of: habitStartTimePicker) { _, date in
                                    habitBlockingStartTime = Calendar.current.dateComponents([.hour, .minute], from: date)
                                }
                        }
                    }
                }

                let titleFilled = !habitTitle.trimmingCharacters(in: .whitespaces).isEmpty
                // Enabled when skipping (no title) OR when all required fields are filled.
                let isEnabled = !titleFilled || canAddTask
                Button {
                    finish()
                } label: {
                    Text(titleFilled ? "Add & finish" : "Skip")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(isEnabled ? DesignSystem.Colors.background : DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(isEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                }
                .disabled(!isEnabled)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .scrollDisabled(habitShowingDatePicker)
        .simultaneousGesture(TapGesture().onEnded { habitShowingStartTimePicker = false })
        .onAppear { habitFieldFocused = true }
    }

    // MARK: - Shared Components

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        }
    }

    private func skipButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Skip for now")
                .font(.system(.subheadline))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
        }
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

    // MARK: - Actions

    private func finish() {
        let trimmed = habitTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && canAddTask {
            let recurrence: TaskRecurrence = habitRepeats
                ? .weekly(days: habitDays)
                : .once(startDate: habitStartDate)
            SharedStore.shared.addTask(Task(
                title: trimmed,
                recurrence: recurrence,
                blocksApps: habitBlocksApps,
                stepTarget: habitHasStepGoal ? habitStepTarget : nil,
                blockingStartTime: habitBlockingStartTime,
                location: habitHasLocation ? (habitSelectedLocation ?? habitConfirmingPin) : nil
            ))
            BlockingService.shared.updateShieldsForCurrentHabitState()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        SharedStore.shared.hasCompletedOnboarding = true
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)
        onComplete()
    }
}

#Preview("Welcome") {
    OnboardingView { }
}
