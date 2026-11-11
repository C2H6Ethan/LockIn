import LockInCore
import SwiftUI

/// The Missed-Day Recap: a calm, factual record of what slipped. No serif, no red.
struct RecapView: View {
    @State var model: RecapModel
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text(model.headline)
                        .font(.system(.largeTitle, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .accessibilityLabel([model.headline, model.accessibilityStreak].compactMap { $0 }.joined(separator: " "))
                    if let subline = model.subline {
                        Text(subline)
                            .font(.body)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.xl)

                ForEach(model.visibleDays, id: \.day) { missed in
                    daySection(missed)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                }

                if model.hiddenDayCount > 0 {
                    Button("\(model.hiddenDayCount) earlier missed days") {
                        withAnimation { model.showsAllDays = true }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                }

                if model.recap.isTruncated {
                    Text("Earlier missed days not shown.")
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .padding(.top, DesignSystem.Spacing.md)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignSystem.Colors.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignSystem.Spacing.md) {
                if let label = model.freezeLabel {
                    Button(label) {
                        model.useFreeze()
                        onDone()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .multilineTextAlignment(.center)
                }
                PrimaryButton("Start today") {
                    model.acknowledge()
                    onDone()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.background)
        }
        .interactiveDismissDisabled(true)
        .sensoryFeedback(.warning, trigger: true)
    }

    private func daySection(_ missed: MissedDayRecap.MissedDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(model.label(for: missed.day))
                .padding(.bottom, DesignSystem.Spacing.sm)
            ForEach(model.visibleTitles(for: missed), id: \.self) { title in
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                    Circle()
                        .strokeBorder(DesignSystem.Colors.secondaryText, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                        .frame(width: DesignSystem.Spacing.rowMarker)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            let hidden = model.hiddenTitleCount(for: missed)
            if hidden > 0 {
                Button("\(hidden) more") { withAnimation { model.expand(missed.day) } }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.leading, DesignSystem.Spacing.rowMarker + DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
        }
    }
}
