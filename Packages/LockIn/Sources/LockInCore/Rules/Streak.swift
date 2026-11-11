import Foundation

/// A Streak carried over from v2, valid through `asOf`.
public struct StreakSeed: Hashable, Codable, Sendable {
    public let count: Int
    public let asOf: DayKey

    public init(count: Int, asOf: DayKey) {
        self.count = count
        self.asOf = asOf
    }
}

public enum Streak {
    /// Consecutive Kept Days going back from yesterday, plus today once today is kept (see GLOSSARY: Streak).
    public static func current(
        records: [DayKey: DayRecord],
        today: Today,
        firstDay: DayKey?,
        seed: StreakSeed?,
        calendar: Calendar
    ) -> Int {
        guard let firstDay else { return 0 }
        var count = today.isKept ? 1 : 0
        var day = today.day.adding(days: -1, in: calendar)
        while day >= firstDay {
            guard let record = records[day], record.countsAsKept else { return count }
            count += 1
            day = day.adding(days: -1, in: calendar)
        }
        // Reached the first Day without a break: an imported Streak that ended the Day before continues.
        if let seed, seed.asOf == firstDay.adding(days: -1, in: calendar) {
            count += seed.count
        }
        return count
    }
}
