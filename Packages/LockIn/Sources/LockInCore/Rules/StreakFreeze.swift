import Foundation

/// Streak Freeze (see GLOSSARY): one per ISO week, spent from the Missed-Day Recap on a single Missed Day.
public enum StreakFreeze {
    /// Available unless one was already used in `today`'s ISO week (Monday start). Doesn't accumulate.
    public static func isAvailable(lastUsed: DayKey?, today: DayKey, calendar: Calendar) -> Bool {
        guard let lastUsed else { return true }
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        let week: (DayKey) -> DateComponents = { iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.startOfDay(in: iso)) }
        return week(lastUsed) != week(today)
    }

    /// The Missed Day a Freeze can be spent on, or `nil` when the recap shouldn't offer one: only when exactly
    /// one Missed Day broke a Streak greater than 0 and a Freeze is available.
    public static func offer(recap: MissedDayRecap, lastUsed: DayKey?, today: DayKey, calendar: Calendar) -> DayKey? {
        guard recap.missedDays.count == 1, !recap.isTruncated, recap.previousStreak > 0,
              isAvailable(lastUsed: lastUsed, today: today, calendar: calendar)
        else { return nil }
        return recap.missedDays[0].day
    }

    /// Turns that Missed Day into a frozen one, which counts as Kept.
    public static func apply(to records: inout [DayKey: DayRecord], day: DayKey) {
        guard records[day]?.outcome == .missed else { return }
        records[day]?.outcome = .frozen
    }
}
