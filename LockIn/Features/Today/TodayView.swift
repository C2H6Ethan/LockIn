import LockInCore
import SwiftUI

/// The main screen: what's due today. Completing the last Required Task drops the Shield.
struct TodayView: View {
    @State var model: TodayModel
    var onAddTask: () -> Void = {}
    var onEditTask: (LockInTask) -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, DesignSystem.Spacing.xl)

                if model.today.all.isEmpty {
                    emptyState
                } else {
                    ForEach(model.today.required, id: \.task.id) { row($0) }
                    if !model.today.optional.isEmpty {
                        SectionLabel("Optional")
                            .padding(.top, DesignSystem.Spacing.xl)
                            .padding(.bottom, DesignSystem.Spacing.sm)
                        ForEach(model.today.optional, id: \.task.id) { row($0) }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.background)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            model.reload()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(model.dateHeader)
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            Text("Today")
                .font(.system(.largeTitle, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
            if let streak = model.streakLabel {
                Text(streak)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .contentTransition(.numericText())
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("No tasks today.")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            Button("Add Task", action: onAddTask)
                .font(.body.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.accent)
        }
    }

    private func row(_ entry: Today.Entry) -> some View {
        TaskRow(
            title: entry.task.title,
            subtitle: model.subtitle(for: entry.task),
            isCompleted: entry.isCompleted,
            isRequired: entry.task.isRequired,
            onToggle: { model.toggle(entry.task.id) }
        )
        .contextMenu {
            Button("Edit") { onEditTask(entry.task) }
        }
    }
}

/// One Task: marker, title and an optional secondary line. Tap anywhere to toggle.
struct TaskRow: View {
    let title: String
    let subtitle: String?
    let isCompleted: Bool
    let isRequired: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                marker
                    .frame(width: DesignSystem.Spacing.rowMarker)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(isCompleted ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.primaryText)
                        .strikethrough(isCompleted, color: DesignSystem.Colors.secondaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, DesignSystem.Spacing.sm + DesignSystem.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isCompleted) { _, new in new }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCompleted ? .isSelected : [])
        .accessibilityHint(isCompleted ? "Marks as not done" : "Marks as done")
    }

    @ViewBuilder private var marker: some View {
        let color = isRequired ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText
        if isCompleted {
            Circle().fill(color).frame(width: 14, height: 14)
        } else {
            Circle().strokeBorder(color, lineWidth: 1.5).frame(width: 14, height: 14)
        }
    }
}

/// Uppercase, letter-spaced, secondary label above a group.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.footnote.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(DesignSystem.Colors.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}
