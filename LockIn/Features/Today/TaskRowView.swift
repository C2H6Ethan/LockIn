import SwiftUI

struct TaskRowView: View {

    let task: TodayTask
    let onComplete: () -> Void
    var stepCount: Int? = nil            // non-nil only for step goal tasks
    var isCompleted: Bool = false
    var locationVerificationFailed: Bool = false  // true while showing "must be at X" error
    var locationAlwaysAuthorized: Bool = false

    @State private var hapticTrigger = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Left icon
            let stepsReached = task.stepTarget.map { (stepCount ?? 0) >= $0 } ?? false
            if task.stepTarget != nil && !(task.location != nil && stepsReached) {
                // Walk icon: pure step task, or combined step+location task waiting on steps
                Image(systemName: "figure.walk")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        isCompleted
                            ? DesignSystem.Colors.accent
                            : task.blocksApps
                                ? DesignSystem.Colors.accent
                                : DesignSystem.Colors.secondaryText
                    )
                    .frame(width: 22, height: 22)
                    .padding(.top, 2)
            } else if isCompleted {
                Circle()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 22, height: 22)
                    .padding(.top, 2)
            } else {
                Button {
                    hapticTrigger.toggle()
                    onComplete()
                } label: {
                    Circle()
                        .strokeBorder(
                            task.isCarryOver
                                ? DesignSystem.Colors.overdue
                                : DesignSystem.Colors.secondaryText,
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: hapticTrigger)
                .padding(.top, 2)
            }

            // Text content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(task.title)
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(
                        isCompleted
                            ? DesignSystem.Colors.secondaryText
                            : DesignSystem.Colors.primaryText
                    )

                // Location verification error (transient — shown until cleared)
                if locationVerificationFailed, let locationName = task.location?.name {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 10))
                        Text(locationAlwaysAuthorized ? "Must have been at \(locationName)" : "Must be at \(locationName) to complete")
                            .font(.system(.caption2))
                    }
                    .foregroundStyle(DesignSystem.Colors.overdue)
                } else if let loc = task.location {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                        Text(loc.name)
                            .font(.system(.caption2))
                    }
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                if let target = task.stepTarget {
                    // Step progress subtitle — cap display at target when completed
                    let current = isCompleted ? target : (stepCount ?? 0)
                    Text("\(current.formatted()) / \(target.formatted()) steps")
                        .font(.system(.caption, design: .default, weight: .regular))
                        .foregroundStyle(
                            isCompleted
                                ? DesignSystem.Colors.secondaryText
                                : task.blocksApps
                                    ? DesignSystem.Colors.accent
                                    : DesignSystem.Colors.secondaryText
                        )
                } else if task.isCarryOver, let day = task.originalDay, task.location == nil {
                    Text(task.isOnce ? "since \(day)" : "unfinished from \(day)")
                        .font(.system(.caption, design: .default, weight: .regular))
                        .foregroundStyle(task.isOnce ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.overdue)
                }
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .contentShape(Rectangle())
        .opacity(isCompleted ? 0.45 : 1.0)
    }
}
