import SwiftUI

/// The one filled button style: accent fill, background-colored text, full width.
struct PrimaryButton: View {
    let title: String
    var isWorking = false
    let action: () -> Void

    init(_ title: String, isWorking: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isWorking = isWorking
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isWorking ? 0 : 1)
                if isWorking { ProgressView().tint(DesignSystem.Colors.background) }
            }
            .font(.body.weight(.medium))
            .foregroundStyle(DesignSystem.Colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.accent, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        }
        .disabled(isWorking)
    }
}

/// Plain secondary text button, for "Skip" and similar.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(.body)
            .foregroundStyle(DesignSystem.Colors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
    }
}
