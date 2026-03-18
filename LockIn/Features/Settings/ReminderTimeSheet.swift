import SwiftUI
import UserNotifications

struct ReminderTimeSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var isEnabled: Bool
    @State private var pickerTime: Date
    @State private var notificationsDenied = false

    init() {
        let stored = SharedStore.shared.dailyReminderTime
        _isEnabled = State(initialValue: stored != nil)
        _pickerTime = State(initialValue: stored ?? Self.defaultTime)
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Daily Reminder")
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .padding(.top, DesignSystem.Spacing.lg)

                Text("Get a nudge if your tasks aren't done by a set time.")
                    .font(.system(.subheadline))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                Toggle(isOn: $isEnabled) {
                    Text("Remind me")
                        .font(.system(.body))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                .tint(DesignSystem.Colors.accent)

                if isEnabled {
                    DatePicker(
                        "",
                        selection: $pickerTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(DesignSystem.Colors.accent)
                    .colorScheme(.dark)
                }

                Spacer()

                Button(action: {
                    _Concurrency.Task {
                        if isEnabled {
                            let settings = await UNUserNotificationCenter.current().notificationSettings()
                            if settings.authorizationStatus == .notDetermined {
                                try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                            }
                        }
                        SharedStore.shared.dailyReminderTime = isEnabled ? pickerTime : nil
                        SchedulingService.shared.rescheduleReminderIfNeeded()
                        dismiss()
                    }
                }, label: {
                    Text("Save")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                })

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

    private static var defaultTime: Date {
        var comps = DateComponents()
        comps.hour = Constants.DailyReminder.defaultHour
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}
