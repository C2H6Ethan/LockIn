import LockInCore
import SwiftUI

/// Create or edit a Task. One form for both, so they can never drift apart.
/// Order: name, Required, Repeat, Completes by, then Start Time for Required Tasks only.
struct TaskFormView: View {
    @State var model: TaskFormModel
    @State var showsPlacePicker = false
    @State private var confirmsDelete = false
    @FocusState private var titleFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        TextField("Task name", text: $model.draft.title, axis: .vertical)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                            .focused($titleFocused)
                            .submitLabel(.done)
                            // A multi-line field turns Return into a newline and never calls onSubmit.
                            .onChange(of: model.draft.title) { _, title in
                                guard title.contains("\n") else { return }
                                model.draft.title = title.replacingOccurrences(of: "\n", with: "")
                                titleFocused = false
                            }
                        if let hint = model.saveHint {
                            Text(hint)
                                .font(.footnote)
                                .foregroundStyle(model.lockViolations.isEmpty ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.destructive)
                                .accessibilityLabel("Can't save yet. \(hint)")
                        }
                    }

                    Group {
                        requiredSection
                        repeatSection
                        completesBySection
                        if model.draft.requirement == .required {
                            startTimeSection
                        }
                    }
                    // Leaving the name for any other control closes the keyboard. Otherwise iOS hands focus
                    // back to the name when a date popover or the place picker closes, and scrolls to the top.
                    .simultaneousGesture(TapGesture().onEnded { titleFocused = false })

                    if let until = model.lockedUntil {
                        Label("Locked until \(until.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())). You can only make this task stricter.",
                              systemImage: "lock.fill")
                            .labelStyle(InlineIconLabelStyle())
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }

                    if model.canDelete {
                        Button("Delete task", role: .destructive) { confirmsDelete = true }
                            .foregroundStyle(DesignSystem.Colors.destructive)
                            .padding(.top, DesignSystem.Spacing.lg)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .animation(.easeOut(duration: 0.2), value: model.draft.requirement)
                .animation(.easeOut(duration: 0.2), value: model.draft.completesBy)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DesignSystem.Colors.background)
            .navigationTitle(model.isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if model.save() { dismiss() } }
                        .fontWeight(.semibold)
                        .disabled(!model.canSave)
                }
            }
            // A centered alert, not a confirmationDialog: on iOS 26 that becomes a popover pointing at
            // whatever it's attached to, here the top of the screen.
            .alert("Delete “\(model.draft.title)”?", isPresented: $confirmsDelete) {
                Button("Delete", role: .destructive) {
                    model.delete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
            // Only a new Task opens with the keyboard; editing opens on the whole form.
            .onAppear { if !model.isEditing { titleFocused = true } }
            .onChange(of: model.draft.requirement) { titleFocused = false }
            .onChange(of: model.draft.repeats) { titleFocused = false }
            .onChange(of: model.draft.weekdays) { titleFocused = false }
            .onChange(of: model.onceDate) { titleFocused = false }
            .onChange(of: model.draft.completesBy) { titleFocused = false }
            .onChange(of: model.draft.startTime) { titleFocused = false }
        }
        .tint(DesignSystem.Colors.accent)
        .presentationDetents([.large])
        .presentationBackground(DesignSystem.Colors.background)
        .presentationDragIndicator(.hidden)
    }

    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: Binding(
                get: { model.draft.requirement == .required },
                set: { model.draft.requirement = $0 ? .required : .optional }
            )) {
                Text("Required").foregroundStyle(DesignSystem.Colors.primaryText)
            }
            Text(model.draft.requirement == .required
                 ? "The apps on your Blocklist stay blocked until this is done."
                 : "Shows on Today, but never blocks anything.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionLabel("Repeat")
            Picker("Repeat", selection: $model.draft.repeats) {
                Text("Weekly").tag(TaskDraft.Repeats.weekly)
                Text("Once").tag(TaskDraft.Repeats.once)
            }
            .pickerStyle(.segmented)

            switch model.draft.repeats {
            case .weekly:
                WeekdayPicker(selection: $model.draft.weekdays)
            case .once:
                DatePicker("Day", selection: $model.onceDate, in: model.today.startOfDay(in: .current)..., displayedComponents: .date)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
        }
    }

    private var completesBySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionLabel("How it's done")
            Picker("How it's done", selection: Binding(
                get: { model.draft.completesBy },
                set: { choice in
                    model.draft.completesBy = choice
                    if choice == .place, model.draft.place == nil { openPlacePicker() }
                }
            )) {
                Text("Tick off").tag(TaskDraft.CompletesBy.tickOff)
                Text("Steps").tag(TaskDraft.CompletesBy.steps)
                Text("Place").tag(TaskDraft.CompletesBy.place)
            }
            .pickerStyle(.segmented)

            switch model.draft.completesBy {
            case .tickOff:
                footnote("You tick it off yourself on Today.")
            case .steps:
                Picker("Goal", selection: $model.draft.stepTarget) {
                    ForEach(model.stepTargetChoices, id: \.self) { Text("\($0.formatted()) steps").tag($0) }
                }
                .pickerStyle(.menu)
                .tint(DesignSystem.Colors.accent)
                footnote("Ticks itself off when you've walked this many steps today.")
                footnote("Steps not counting? In the Health app, tap your profile, then Apps → Lock In, and turn on Steps.")
            case .place:
                Button { openPlacePicker() } label: {
                    Text(model.draft.place?.name ?? "Choose a place")
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                footnote("You can only tick it off after you've been there today.")
            }
        }
        .sheet(isPresented: $showsPlacePicker) {
            PlacePickerView(initial: model.draft.place) { model.draft.place = $0 }
        }
    }

    private var startTimeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: Binding(
                get: { model.draft.startTime != nil },
                set: { model.draft.startTime = $0 ? TimeOfDay(hour: 9, minute: 0) : nil }
            )) {
                Text("Start time").foregroundStyle(DesignSystem.Colors.primaryText)
            }
            if let start = model.draft.startTime {
                Picker("From", selection: Binding(get: { start }, set: { model.draft.startTime = $0 })) {
                    ForEach(TaskFormModel.startTimeChoices, id: \.self) { Text($0.description).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }
            footnote(model.draft.startTime.map { "Your apps are blocked from \($0.description) until this is done." }
                     ?? "Your apps are blocked all day until this is done. Turn on to start blocking later.")
        }
    }

    /// Closes the keyboard first, so it doesn't come back on the name when the picker closes.
    private func openPlacePicker() {
        titleFocused = false
        showsPlacePicker = true
    }

    private func footnote(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(DesignSystem.Colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Seven single-letter toggles, Monday first.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    private let order: [(Weekday, String, String)] = [
        (.monday, "M", "Monday"), (.tuesday, "T", "Tuesday"), (.wednesday, "W", "Wednesday"),
        (.thursday, "T", "Thursday"), (.friday, "F", "Friday"), (.saturday, "S", "Saturday"), (.sunday, "S", "Sunday"),
    ]

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var dayCircle = DesignSystem.Size.dayCircle

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                accessibilityList
            } else {
                letters
            }
        }
        // Same light tick as completing a task, so every toggle is felt.
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var accessibilityList: some View {
        Group {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(order, id: \.0) { day, _, name in
                    let on = selection.contains(day)
                    Button {
                        if on { selection.remove(day) } else { selection.insert(day) }
                    } label: {
                        HStack {
                            Text(name)
                                .fontWeight(on ? .semibold : .regular)
                                .foregroundStyle(on ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                            Spacer()
                            if on { Image(systemName: "checkmark").foregroundStyle(DesignSystem.Colors.accent) }
                        }
                        .frame(minHeight: DesignSystem.Size.hitArea)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var letters: some View {
        HStack(spacing: 0) {
            ForEach(order, id: \.0) { day, letter, name in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(letter)
                        .font(.body.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? DesignSystem.Colors.background : DesignSystem.Colors.secondaryText)
                        .frame(width: dayCircle, height: dayCircle)
                        .background(Circle().fill(on ? DesignSystem.Colors.accent : .clear))
                        .animation(.easeOut(duration: 0.15), value: on)
                        .frame(maxWidth: .infinity, minHeight: DesignSystem.Size.hitArea)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
