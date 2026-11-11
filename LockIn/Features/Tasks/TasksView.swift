import LockInCore
import SwiftUI

/// Every Task, including ones not due today. Tapping one edits it.
struct TasksView: View {
    @State var model: TasksModel
    var onAddTask: () -> Void
    var onEditTask: (LockInTask) -> Void
    /// Changes whenever Tasks may have been edited elsewhere, e.g. in the Task form sheet.
    var dataVersion: Int

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if model.list.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("No tasks yet.").foregroundStyle(DesignSystem.Colors.primaryText)
                        Button("Add task", action: onAddTask)
                            .font(.body.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
                if !model.list.required.isEmpty {
                    SectionLabel("Required").padding(.bottom, DesignSystem.Spacing.xs)
                    ForEach(model.list.required) { row($0) }
                }
                if !model.list.optional.isEmpty {
                    SectionLabel("Optional")
                        .padding(.top, model.list.required.isEmpty ? 0 : DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.xs)
                    ForEach(model.list.optional) { row($0) }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddTask) {
                    Image(systemName: "plus").foregroundStyle(DesignSystem.Colors.accent)
                }
                .accessibilityLabel("Add task")
            }
        }
        .onAppear { model.reload() }
        .onChange(of: dataVersion) { model.reload() }
    }

    private func row(_ task: LockInTask) -> some View {
        let isPast = model.list.isPast(task)
        return Button { onEditTask(task) } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .foregroundStyle(isPast ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.primaryText)
                    Text(isPast ? model.describe(task) + " · past" : model.describe(task))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DesignSystem.Spacing.sm + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edit")
    }
}
