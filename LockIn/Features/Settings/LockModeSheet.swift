import LockInCore
import SwiftUI

/// Starts or extends Lock Mode: pick a duration, see when it ends, confirm with a button that names the date.
struct LockModeSheet: View {
    let model: SettingsModel
    @State private var days = 7
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Lock Mode")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, DesignSystem.Spacing.xl)
                    Text("Until it ends, Lock In can only get stricter. You can add tasks and add to the Blocklist, but not delete, weaken or remove anything.")
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .padding(.top, DesignSystem.Spacing.md)
                    Text("It can't be ended early.")
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .padding(.top, DesignSystem.Spacing.sm)

                    VStack(spacing: 0) {
                        ForEach(LockMode.durations, id: \.self) { option($0) }
                    }
                    .padding(.top, DesignSystem.Spacing.lg)
                }
            }
            Text("Turning off Screen Time access in iOS Settings can't be prevented.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .padding(.vertical, DesignSystem.Spacing.md)
            PrimaryButton("Lock until \(dayText(model.lockedUntil(ifLockedFor: days)))") {
                model.lock(days: days)
                dismiss()
            }
            SecondaryButton("Cancel") { dismiss() }
                .frame(maxWidth: .infinity)
                .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.background)
        .sensoryFeedback(.selection, trigger: days)
    }

    private func option(_ value: Int) -> some View {
        let selected = value == days
        return Button { days = value } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(value == 1 ? "1 day" : "\(value) days")
                    .foregroundStyle(selected ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
                    .fontWeight(selected ? .semibold : .regular)
                Spacer(minLength: DesignSystem.Spacing.sm)
                Text("until \(dayText(model.lockedUntil(ifLockedFor: value)))")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: DesignSystem.Size.hitArea + 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// "Wed, Nov 18"
    private func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
