import LockInCore
import LockInPlatform
import SwiftUI

/// Opened from the Shield's "Earn a Bypass" notification (`lockin://bypass`).
struct BypassView: View {
    @State var model: BypassModel
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var counterSize = DesignSystem.Size.stepCounter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer()
            content
            Spacer()
            if case .active = model.state {
                PrimaryButton("Got it") { dismiss() }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
        .onAppear { model.appear() }
        .onDisappear { model.disappear() }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .walking(let steps, let goal):
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(steps, format: .number)
                    .font(DesignSystem.Typography.display(size: counterSize))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .accessibilityLabel("\(steps.formatted()) of \(goal.formatted()) steps")
                    .contentTransition(.numericText())
                    .animation(.default, value: steps)
                Text("of \(goal.formatted()) steps")
                    .font(.title3)
                    .accessibilityHidden(true)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text(model.status)
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.top, DesignSystem.Spacing.lg)
                Text("Walk \(goal.formatted()) steps to pause blocking for 15 minutes. Carry your iPhone: Apple Watch steps don't count here. Each Bypass today costs more steps.")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.top, DesignSystem.Spacing.sm)
            }
        case .active(let until):
            message("You gave in.", "Blocking resumes at \(until.formatted(date: .omitted, time: .shortened)).")
        case .nothingOwed:
            message("Nothing to bypass.", "Nothing is blocked right now.")
        case .unavailable:
            message("Can't count steps.", "This device has no step counter, so a Bypass can't be earned here.")
        case .motionDenied:
            message("Can't count steps.", "To earn a Bypass, open Settings → Privacy & Security → Motion & Fitness and turn on Lock In.")
        }
    }

    private func message(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }
}
