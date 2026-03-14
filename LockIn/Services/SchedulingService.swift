import DeviceActivity
import Foundation
import UserNotifications

final class SchedulingService {

    static let shared = SchedulingService()

    private let center = DeviceActivityCenter()

    /// Starts the weekly DeviceActivity monitor (Mon 00:00 → Sun 23:59, repeating).
    /// Safe to call on every launch — no-ops if already active.
    func scheduleWeeklyMonitorIfNeeded() {
        let defaults = UserDefaults(suiteName: Constants.AppGroup.id) ?? .standard
        guard !defaults.bool(forKey: Keys.weeklyScheduleActive) else { return }

        // Calendar weekday: 1=Sun, 2=Mon … 7=Sat
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, weekday: 2),  // Mon 00:00
            intervalEnd:   DateComponents(hour: 23, minute: 59, weekday: 1), // Sun 23:59
            repeats: true
        )

        do {
            try center.startMonitoring(
                DeviceActivityName(Constants.DeviceActivity.weeklySchedule),
                during: schedule
            )
            defaults.set(true, forKey: Keys.weeklyScheduleActive)
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
