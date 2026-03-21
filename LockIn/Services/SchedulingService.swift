import DeviceActivity
import Foundation
import UserNotifications

final class SchedulingService {

    static let shared = SchedulingService()

    private let center = DeviceActivityCenter()

    /// Starts a daily DeviceActivity monitor (00:00 → 23:59, repeating every day).
    /// Fires `intervalDidStart` at midnight so the extension reapplies shields for the new day.
    /// Must only be called after FamilyControls authorization is granted.
    func scheduleDailyMonitorIfNeeded() {
        let defaults = UserDefaults(suiteName: Constants.AppGroup.id) ?? .standard
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
            // Authorization not yet granted — will retry on next launch once granted
        }
    }

    /// Registers one DeviceActivity schedule per unique blockingStartTime across all tasks.
    /// Fires `intervalDidStart` at each start time so the extension applies shields without
    /// requiring the user to open the app.
    /// Safe to call on every foreground — stops old start-time monitors and re-registers fresh.
    /// Must only be called after FamilyControls authorization is granted.
    func scheduleBlockingStartTimeMonitors(for tasks: [Task]) {
        let defaults = UserDefaults(suiteName: Constants.AppGroup.id) ?? .standard

        // Stop previously registered start-time monitors
        let previousMinutes = defaults.array(forKey: Keys.activeStartTimeMinutes) as? [Int] ?? []
        let previousNames = previousMinutes.map {
            DeviceActivityName("\(Constants.DeviceActivity.startTimePrefix).\($0)")
        }
        if !previousNames.isEmpty {
            center.stopMonitoring(previousNames)
        }

        // Collect unique start times (in minutes since midnight) from all tasks
        let uniqueMinutes = Set(tasks.compactMap { task -> Int? in
            guard let comps = task.blockingStartTime,
                  let hour = comps.hour, let minute = comps.minute else { return nil }
            return hour * 60 + minute
        })

        var registeredMinutes: [Int] = []
        for totalMinutes in uniqueMinutes {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: totalMinutes / 60, minute: totalMinutes % 60),
                intervalEnd:   DateComponents(hour: 23, minute: 59),
                repeats: true
            )
            let name = DeviceActivityName("\(Constants.DeviceActivity.startTimePrefix).\(totalMinutes)")
            do {
                try center.startMonitoring(name, during: schedule)
                registeredMinutes.append(totalMinutes)
            } catch {
                // Authorization not yet granted — will retry on next foreground once granted
            }
        }

        defaults.set(registeredMinutes, forKey: Keys.activeStartTimeMinutes)
        defaults.synchronize()
    }

    /// Schedules a one-shot DeviceActivity monitor that expires when the bypass window closes.
    /// The DeviceActivityMonitor extension re-applies shields in `intervalDidEnd`, even if
    /// LockIn is suspended.
    func scheduleBypassExpiry(duration: TimeInterval) {
        center.stopMonitoring([DeviceActivityName(Constants.DeviceActivity.bypassExpiry)])

        let now = Date()
        let expiry = now.addingTimeInterval(duration)
        let cal = Calendar.current
        let startComps = cal.dateComponents([.hour, .minute, .second], from: now)
        let endComps   = cal.dateComponents([.hour, .minute, .second], from: expiry)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd:   endComps,
            repeats: false
        )

        try? center.startMonitoring(
            DeviceActivityName(Constants.DeviceActivity.bypassExpiry),
            during: schedule
        )
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
        static let dailyScheduleActive    = "dailyScheduleActive"
        static let activeStartTimeMinutes = "activeStartTimeMinutes"
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
