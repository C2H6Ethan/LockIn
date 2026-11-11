import LockInCore
import LockInPlatform
import SwiftUI

/// Opened from the Shield's "Earn access" notification (`lockin://bypass`).
struct BypassView: View {
    @State var model: BypassModel
    @Environment(\.dismiss) private var dismiss

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
                    .font(.system(size: 88, weight: .semibold).monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .contentTransition(.numericText())
                    .animation(.default, value: steps)
                Text("of \(goal) steps")
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text(model.status)
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.top, DesignSystem.Spacing.lg)
                Text("Walk to lift the Shield for 15 minutes. Keep your iPhone on you: Apple Watch steps don't count here. Each Bypass today costs more.")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.top, DesignSystem.Spacing.sm)
            }
        case .active(let until):
            message("You gave in.", "Shield back at \(until.formatted(date: .omitted, time: .shortened)).")
        case .nothingOwed:
            message("Nothing to bypass.", "No Required Tasks are holding the Shield up right now.")
        case .unavailable:
            message("Steps unavailable.", "This device can't count steps, so it can't earn a Bypass.")
        case .motionDenied:
            message("Steps unavailable.", "Allow Motion & Fitness for Lock In in Settings → Privacy & Security to earn a Bypass.")
        }
    }

    private func message(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }
}
