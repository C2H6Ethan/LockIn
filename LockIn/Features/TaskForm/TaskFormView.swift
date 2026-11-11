import LockInCore
import SwiftUI

/// Create or edit a Task. One form for both, so they can never drift apart.
struct TaskFormView: View {
    @State var model: TaskFormModel
    @State private var confirmsDelete = false
    @FocusState private var titleFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    TextField("Task name", text: $model.draft.title, axis: .vertical)
                        .font(.system(.title2, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .focused($titleFocused)
                        .submitLabel(.done)

                    requiredSection
                    repeatSection
                    startTimeSection
                    stepGoalSection

                    if !model.draft.title.isEmpty {
                        ForEach(model.errors.filter { $0 != .emptyTitle }, id: \.self) { error in
                            Text(error.message)
                                .font(.footnote)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }

                    if model.isEditing {
                        Button("Delete Task", role: .destructive) { confirmsDelete = true }
                            .foregroundStyle(DesignSystem.Colors.destructive)
                            .padding(.top, DesignSystem.Spacing.lg)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
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
                        .disabled(!model.canSave)
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.delete()
                    dismiss()
                }
            }
            .onAppear { if !model.isEditing { titleFocused = true } }
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
                 ? "Keeps your Blocklist shielded until it's done."
                 : "Tracked, but never shields anything.")
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
            Text(verbatim: model.draft.startTime.map { "Shields from \($0.description) until done." } ?? "Shields from midnight until done.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .opacity(model.draft.requirement == .required ? 1 : 0)
        }
    }
}

extension TaskFormView {
    var stepGoalSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: Binding(
                get: { model.draft.stepTarget != nil },
                set: { model.draft.stepTarget = $0 ? TaskFormModel.defaultStepTarget : nil }
            )) {
                Text("Step goal").foregroundStyle(DesignSystem.Colors.primaryText)
            }
            if let target = model.draft.stepTarget {
                Picker("Steps", selection: Binding(get: { target }, set: { model.draft.stepTarget = $0 })) {
                    ForEach(model.stepTargetChoices, id: \.self) { Text("\($0.formatted()) steps").tag($0) }
                }
                .pickerStyle(.menu)
                .tint(DesignSystem.Colors.accent)
                Text("Completes itself once Apple Health counts this many steps today. It can't be ticked off by hand.")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
    }
}

/// Seven single-letter toggles, Monday first.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    private let order: [(Weekday, String, String)] = [
        (.monday, "M", "Monday"), (.tuesday, "T", "Tuesday"), (.wednesday, "W", "Wednesday"),
        (.thursday, "T", "Thursday"), (.friday, "F", "Friday"), (.saturday, "S", "Saturday"), (.sunday, "S", "Sunday"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(order, id: \.0) { day, letter, name in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(letter)
                        .font(.body.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
