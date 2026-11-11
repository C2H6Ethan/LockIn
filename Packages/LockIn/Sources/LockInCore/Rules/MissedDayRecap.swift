import Foundation

/// What the Missed-Day Recap shows (see GLOSSARY). Built from Day records only, never from live Tasks.
public struct MissedDayRecap: Equatable, Sendable {
    public static let lookbackDays = 60

    public struct MissedDay: Equatable, Sendable {
        public let day: DayKey
        public let undoneRequiredTaskTitles: [String]

        public init(day: DayKey, undoneRequiredTaskTitles: [String]) {
            self.day = day
            self.undoneRequiredTaskTitles = undoneRequiredTaskTitles
        }
    }

    /// Newest first.
    public let missedDays: [MissedDay]
    /// The Streak at the end of the last Kept Day before the oldest listed Missed Day.
    public let previousStreak: Int
    /// The Missed Day that ended that Streak; `nil` when there was no Streak to lose.
    public let streakBrokenOn: DayKey?
    /// Older unacknowledged Missed Days exist beyond the lookback.
    public let isTruncated: Bool

    public init(missedDays: [MissedDay], previousStreak: Int, streakBrokenOn: DayKey?, isTruncated: Bool) {
        self.missedDays = missedDays
        self.previousStreak = previousStreak
        self.streakBrokenOn = streakBrokenOn
        self.isTruncated = isTruncated
    }

    public static func pending(
        records: [DayKey: DayRecord],
        today: DayKey,
        acknowledgedThrough: DayKey?,
        firstDay: DayKey?,
        seed: StreakSeed?,
        calendar: Calendar
    ) -> MissedDayRecap? {
        let earliest = today.adding(days: -lookbackDays, in: calendar)
        let unseen = records.values
            .filter { $0.outcome == .missed && $0.day < today && $0.day > (acknowledgedThrough ?? .distantPast) }
            .sorted { $0.day > $1.day }
        let listed = unseen.filter { $0.day >= earliest }
        guard let oldest = listed.last else { return nil }

        let previous = Streak.through(oldest.day.adding(days: -1, in: calendar), records: records, firstDay: firstDay, seed: seed, calendar: calendar)
        return MissedDayRecap(
            missedDays: listed.map { MissedDay(day: $0.day, undoneRequiredTaskTitles: $0.undoneRequired.map(\.title)) },
            previousStreak: previous,
            streakBrokenOn: previous > 0 ? oldest.day : nil,
            isTruncated: unseen.count > listed.count
        )
    }
}

extension DayKey {
    static let distantPast = DayKey(year: 1, month: 1, day: 1)!
}
