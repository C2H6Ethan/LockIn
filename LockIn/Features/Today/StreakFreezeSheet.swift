import SwiftUI

struct StreakFreezeSheet: View {

    let onUse: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Spacer()

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("You slipped.")
                        .font(.system(.largeTitle, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    Text("You have one weekly recovery.\nUse it and lock in — or let the streak go.")
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Button {
                        onUse()
                    } label: {
                        Text("Lock in. Use recovery.")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                    }

                    Button {
                        onDecline()
                    } label: {
                        Text("Reset my streak")
                            .font(.system(.subheadline))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .interactiveDismissDisabled(true)
    }
}
