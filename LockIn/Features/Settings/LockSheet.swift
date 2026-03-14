import SwiftUI

struct LockSheet: View {

    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDays: Int = 7

    private let durationOptions: [(label: String, days: Int)] = [
        ("1 day", 1),
        ("3 days", 3),
        ("7 days", 7),
        ("14 days", 14),
        ("30 days", 30),
    ]

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                Text("Lock In")
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .padding(.top, DesignSystem.Spacing.lg)

                // Subheader
                Text("Prevent changes to your tasks for a set period.")
                    .font(.system(.subheadline))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                // Duration chip row
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Duration")
                        .font(.system(.subheadline))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(durationOptions, id: \.days) { option in
                                let isSelected = selectedDays == option.days
                                Button {
                                    selectedDays = option.days
                                } label: {
                                    Text(option.label)
                                        .font(.system(.subheadline, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(
                                            isSelected
                                                ? DesignSystem.Colors.background
                                                : DesignSystem.Colors.secondaryText
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.md)
                                        .padding(.vertical, DesignSystem.Spacing.sm)
                                        .background(
                                            isSelected
                                                ? DesignSystem.Colors.accent
                                                : DesignSystem.Colors.secondaryText.opacity(0.12)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Warning text
                Text("You won't be able to delete tasks, turn off app blocking, or remove blocked apps during this period.")
                    .font(.system(.caption))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                Spacer()

                // Lock button
                Button {
                    viewModel.activateLock(days: selectedDays)
                    dismiss()
                } label: {
                    Text("Lock")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                }

                // Cancel button
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
}
