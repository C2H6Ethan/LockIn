import LockInCore
import StoreKit
import SwiftUI

/// The main screen: what's due today, and whether blocking is on. Completing the last owed Required Task turns it off.
struct TodayView: View {
    @State var model: TodayModel
    var onAddTask: () -> Void = {}
    var onEditTask: (LockInTask) -> Void = { _ in }
    var onShowTasks: () -> Void = {}
    /// The status line asked for something: Screen Time access or a Blocklist.
    var onStatusAction: (ShieldStatus.State) -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

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
                            .padding(.bottom, DesignSystem.Spacing.xs)
                        ForEach(model.today.optional, id: \.task.id) { row($0) }
                    }
                }
            }
            // Matches the large title's leading margin, so the header lines up under "Today".
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
        .navigationTitle("Today")
        .sensoryFeedback(.success, trigger: model.shieldDrops)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            model.reload()
        }
        .onChange(of: model.streak, initial: true) {
            if model.consumeReviewRequest() { requestReview() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(model.dateHeader)
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            // With nothing due, the empty state says it; the line stays only if it asks for something.
            if !model.today.all.isEmpty || model.statusText.isAction {
                StatusLine(text: model.statusText) { onStatusAction(model.status.state) }
                    .padding(.top, DesignSystem.Spacing.sm)
                    .animation(.easeOut(duration: 0.2), value: model.statusText)
            }
            if let until = model.status.lockedUntil {
                Label("Locked until \(until.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))",
                      systemImage: "lock.fill")
                    .labelStyle(InlineIconLabelStyle())
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
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
            Text("Nothing due today.")
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Text("Add a task. Until your required tasks are done, your Blocklist stays blocked.")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            Button("Add task", action: onAddTask)
                .font(.body.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.accent)
            if model.tasksOnOtherDays > 0 {
                Button(action: onShowTasks) {
                    Text(model.tasksOnOtherDays == 1 ? "1 task on other days ›" : "\(model.tasksOnOtherDays) tasks on other days ›")
                }
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
    }

    private func row(_ entry: Today.Entry) -> some View {
        let task = entry.task
        return TaskRow(
            title: task.title,
            subtitle: model.subtitle(for: task),
            isCompleted: entry.isCompleted,
            isRequired: task.isRequired,
            completesItself: !task.canCompleteManually,
            isLocation: task.place != nil,
            stepProgress: task.stepTarget == nil ? nil : .some(model.stepProgress(for: task)),
            isChecking: model.checkingLocation.contains(task.id),
            message: model.message(for: task),
            onToggle: { model.toggle(task.id) },
            onEdit: { onEditTask(task) }
        )
        .contextMenu {
            Button("Edit", systemImage: "pencil") { onEditTask(task) }
            if task.canCompleteManually {
                Button(entry.isCompleted ? "Undo" : "Complete",
                       systemImage: entry.isCompleted ? "circle" : "checkmark.circle") { model.toggle(task.id) }
            }
        }
    }
}

/// "Blocking on · 2 required tasks left": the state in primary, the detail in secondary.
/// Accent and tappable only when it asks for something.
struct StatusLine: View {
    let text: ShieldStatus.Text
    var action: () -> Void = {}

    var body: some View {
        if text.isAction {
            Button(action: action) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        let lead = text.isAction ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText
        let rest = text.isAction ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText
        let detail = text.detail.map { text.isAction ? ": \($0) ›" : " · \($0)" } ?? ""
        return (Text(text.lead).foregroundStyle(lead).fontWeight(.medium) + Text(detail).foregroundStyle(rest))
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
            .accessibilityElement()
            .accessibilityLabel(text.lead + (text.detail.map { ", \($0)" } ?? ""))
    }
}

/// One Task. The marker completes it; the title opens it for editing. Both are 44 pt targets.
struct TaskRow: View {
    let title: String
    let subtitle: String?
    let isCompleted: Bool
    let isRequired: Bool
    /// Step-Goal Tasks: the marker shows progress, and tapping it does nothing.
    var completesItself = false
    /// Location Tasks get a map-pin marker.
    var isLocation = false
    /// Step-Goal Tasks only: `.some(nil)` while today's steps are unknown.
    var stepProgress: Double?? = nil
    /// A location fix is being taken for this row.
    var isChecking = false
    /// Why the last tap didn't complete it.
    var message: String?
    let onToggle: () -> Void
    var onEdit: () -> Void = {}

    @ScaledMetric(relativeTo: .body) private var markerSize = DesignSystem.Size.marker
    @ScaledMetric(relativeTo: .body) private var markerColumn = DesignSystem.Spacing.rowMarker

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
            Button(action: onToggle) {
                marker.frame(width: markerColumn)
            }
            .buttonStyle(.plain)
            // Not `.disabled`: that would dim the progress ring. `TodayModel.toggle` ignores Step-Goal Tasks.
            .allowsHitTesting(!completesItself)
            .padding(hitPadding)
            .contentShape(Rectangle())
            .padding(-hitPadding)

            Button(action: onEdit) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .foregroundStyle(isCompleted ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.primaryText)
                            .strikethrough(isCompleted, color: DesignSystem.Colors.secondaryText)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                        if let message {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.destructive)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sensoryFeedback(.selection, trigger: isCompleted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, subtitle].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue("\(isRequired ? "Required" : "Optional"), \(isCompleted ? "done" : "not done")")
        .accessibilityAddTraits(isCompleted ? .isSelected : [])
        .accessibilityAction(named: completesItself ? "Completes at your step goal" : isCompleted ? "Undo" : "Complete") {
            if !completesItself { onToggle() }
        }
        .accessibilityAction(named: "Edit", onEdit)
    }

    /// Grows the marker's tap area to 44 pt without moving it.
    private var hitPadding: CGFloat { max(0, (DesignSystem.Size.hitArea - markerColumn) / 2) }

    @ViewBuilder private var marker: some View {
        let color = isRequired ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText
        if isChecking {
            ProgressView().controlSize(.mini).tint(color)
        } else if isLocation {
            Image(systemName: isCompleted ? "mappin.circle.fill" : "mappin.circle")
                .font(.body)
                .foregroundStyle(color)
        } else if let progress = stepProgress, !isCompleted {
            // The Task completes itself, so the marker shows how far along it is (empty while unknown).
            ZStack {
                Circle().stroke(color.opacity(0.3), lineWidth: 1.5)
                Circle().trim(from: 0, to: progress ?? 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: markerSize, height: markerSize)
        } else if isCompleted {
            Circle().fill(color).frame(width: markerSize, height: markerSize)
        } else {
            Circle().strokeBorder(color, lineWidth: 1.5).frame(width: markerSize, height: markerSize)
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

/// A small leading icon on the text's first baseline, e.g. the lock before "Locked until …".
struct InlineIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
