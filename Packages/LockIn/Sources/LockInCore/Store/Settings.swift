import Foundation

/// User preferences that aren't Tasks or the Blocklist.
public struct Settings: Hashable, Codable, Sendable {
    public static let defaultReminderTime = TimeOfDay(hour: 20, minute: 0)!

    /// `nil` means the reminder is off.
    public var reminderTime: TimeOfDay?
    public var hasCompletedOnboarding: Bool
    /// The Day onboarding finished. Day records (008) start here.
    public var firstDay: DayKey?
    /// A Streak imported from v2 (014).
    public var streakSeed: StreakSeed?
    /// The newest Missed Day the user has seen in the Missed-Day Recap.
    public var recapAcknowledgedThrough: DayKey?

    public init(reminderTime: TimeOfDay? = Settings.defaultReminderTime, hasCompletedOnboarding: Bool = false, firstDay: DayKey? = nil, streakSeed: StreakSeed? = nil) {
        self.reminderTime = reminderTime
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.firstDay = firstDay
        self.streakSeed = streakSeed
    }

    /// Missing fields fall back to defaults so older documents keep decoding.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reminderTime = c.contains(.reminderTime) ? try c.decode(TimeOfDay?.self, forKey: .reminderTime) : Settings.defaultReminderTime
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        firstDay = try c.decodeIfPresent(DayKey.self, forKey: .firstDay)
        streakSeed = try c.decodeIfPresent(StreakSeed.self, forKey: .streakSeed)
        recapAcknowledgedThrough = try c.decodeIfPresent(DayKey.self, forKey: .recapAcknowledgedThrough)
    }
}
