import SwiftUI

struct LocationUpgradeSheet: View {

    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Spacer()

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Auto-complete when you arrive.")
                        .font(.system(.largeTitle, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    Text("Allow location access in the background and LockIn will mark your task complete the moment you show up — no tap needed.")
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Button {
                        onUpgrade()
                    } label: {
                        Text("Allow Always")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.primaryText)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text("Not now")
                            .font(.system(.body))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }
}
