import SwiftUI

struct TaskRowView: View {

    let task: TodayTask
    let onComplete: () -> Void
    var stepCount: Int? = nil   // non-nil only for step goal tasks

    @State private var isCompleting = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Left icon — step icon for step tasks, checkbox for manual tasks
            if task.stepTarget != nil {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        task.blocksApps
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.secondaryText
                    )
                    .frame(width: 22, height: 22)
                    .padding(.top, 2)
            } else {
                Button {
                    guard !isCompleting else { return }
                    isCompleting = true
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
                .sensoryFeedback(.success, trigger: isCompleting)
                .padding(.top, 2)
            }

            // Text content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(task.title)
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                if let target = task.stepTarget {
                    // Step progress subtitle
                    let current = stepCount ?? 0
                    Text("\(current.formatted()) / \(target.formatted()) steps")
                        .font(.system(.caption, design: .default, weight: .regular))
                        .foregroundStyle(
                            task.blocksApps
                                ? DesignSystem.Colors.accent
                                : DesignSystem.Colors.secondaryText
                        )
                } else if task.isCarryOver, let day = task.originalDay {
                    Text(task.isOnce ? "since \(day)" : "unfinished from \(day)")
                        .font(.system(.caption, design: .default, weight: .regular))
                        .foregroundStyle(task.isOnce ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.overdue)
                }
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .contentShape(Rectangle())
    }
}
    