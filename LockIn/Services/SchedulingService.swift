import DeviceActivity
import Foundation
import UserNotifications

final class SchedulingService {

    static let shared = SchedulingService()

    private let center = DeviceActivityCenter()

    /// Starts a daily DeviceActivity monitor (00:00 → 23:59, repeating every day).
    /// Fires `intervalDidStart` at midnight so the extension can reapply shields for the new day.
    /// Migrates from the old weekly schedule on first call.
    func scheduleDailyMonitorIfNeeded() {
        let defaults = UserDefaults(suiteName: Constants.AppGroup.id) ?? .standard

        // Migrate: stop old weekly schedule if it was active
        if defaults.bool(forKey: Keys.weeklyScheduleActive) {
            center.stopMonitoring([DeviceActivityName(Constants.DeviceActivity.weeklySchedule)])
            defaults.removeObject(forKey: Keys.weeklyScheduleActive)
            defaults.removeObject(forKey: Keys.dailyScheduleActive)   // force re-register
            defaults.synchronize()
        }

        guard !defaults.bool(forKey: Keys.dailyScheduleActive) else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),   // midnight
            intervalEnd:   DateComponents(hour: 23, minute: 59), // end of day
            repeats: true
        )

        do {
            try center.startMonitoring(
                DeviceActivityName(Constants.DeviceActivity.dailySchedule),
                during: schedule
            )
            defaults.set(true, forKey: Keys.dailyScheduleActive)
            defaults.synchronize()
        } catch {
            // Will retry on next launch
        }
    }

    /// Cancels any pending daily reminder, then re-schedules it if needed.
    /// Call on every `.active` scene transition and after each task completion.
    /// Always schedules in the future — if reminder time has already passed today, schedules tomorrow.
    func rescheduleReminderIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Constants.DailyReminder.notificationID])

        guard let reminderTime = SharedStore.shared.dailyReminderTime else { return }

        let incomplete = SharedStore.shared.incompleteBlockingTasks
        guard !incomplete.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't lose your streak."
        let count = incomplete.count
        content.body = "\(count) task\(count == 1 ? "" : "s") left today."
        content.sound = .default

        let reminderComps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let triggerDate = nextReminderTriggerDate(
            reminderHour: reminderComps.hour ?? Constants.DailyReminder.defaultHour,
            reminderMinute: reminderComps.minute ?? 0,
            now: Date()
        )
        let triggerComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

        let request = UNNotificationRequest(
            identifier: Constants.DailyReminder.notificationID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private enum Keys {
        static let weeklyScheduleActive = "weeklyScheduleActive"
        static let dailyScheduleActive  = "dailyScheduleActive"
    }
}

/// Returns the next Date at which the reminder should fire.
/// If `reminderHour:reminderMinute` has already passed (or is exactly now) for today,
/// returns that time tomorrow. Otherwise returns it today.
func nextReminderTriggerDate(reminderHour: Int, reminderMinute: Int, now: Date) -> Date {
    let cal = Calendar.current
    var comps = cal.dateComponents([.year, .month, .day], from: now)
    comps.hour = reminderHour
    comps.minute = reminderMinute
    comps.second = 0
    let todayTrigger = cal.date(from: comps)!
    if todayTrigger > now {
        return todayTrigger
    }
    return cal.date(byAdding: .day, value: 1, to: todayTrigger)!
}
