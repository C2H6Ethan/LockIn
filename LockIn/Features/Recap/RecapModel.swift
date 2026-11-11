import Foundation
import LockInCore
import Observation

/// Copy and state for the Missed-Day Recap. Shown once, until the user taps "Start today".
@MainActor
@Observable
final class RecapModel: Identifiable {
    static let fullyShownDays = 7
    static let fullyShownTitles = 5

    let recap: MissedDayRecap
    var showsAllDays = false
    private(set) var expandedDays: Set<DayKey> = []

    private let store: LockInStore
    private let calendar: Calendar
    private let now: () -> Date

    init(recap: MissedDayRecap, store: LockInStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.recap = recap
        self.store = store
        self.calendar = calendar
        self.now = now
    }

    /// A model if there are unseen Missed Days, otherwise `nil`.
    static func pending(store: LockInStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) -> RecapModel? {
        let settings = store.read(.settings)
        guard let recap = MissedDayRecap.pending(
            records: store.read(.dayRecords),
            today: DayKey(now(), calendar: calendar),
            acknowledgedThrough: settings.recapAcknowledgedThrough,
            firstDay: settings.firstDay,
            seed: settings.streakSeed,
            calendar: calendar
        ) else { return nil }
        return RecapModel(recap: recap, store: store, calendar: calendar, now: now)
    }

    private var yesterday: DayKey { DayKey(now(), calendar: calendar).adding(days: -1, in: calendar) }
    private var count: Int { recap.missedDays.count }

    var headline: String {
        if recap.previousStreak > 0 { return "Your \(recap.previousStreak)-day streak ended." }
        return missedSentence(withSince: false)
    }

    /// Hidden when it would repeat the headline.
    var subline: String? {
        recap.previousStreak > 0 ? missedSentence(withSince: true) : nil
    }

    private func missedSentence(withSince: Bool) -> String {
        guard let newest = recap.missedDays.first, let oldest = recap.missedDays.last else { return "" }
        if count == 1 {
            return newest.day == yesterday ? "You missed yesterday." : "You missed \(format(newest.day, uppercase: false))."
        }
        return withSince ? "You missed \(count) days since \(format(oldest.day, uppercase: false))." : "You missed \(count) days."
    }

    func label(for day: DayKey) -> String {
        day == yesterday ? "YESTERDAY" : format(day, uppercase: true)
    }

    private func format(_ day: DayKey, uppercase: Bool) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted).weekday(.wide).month(.abbreviated).day()
        if day.year != DayKey(now(), calendar: calendar).year { style = style.year() }
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = Locale(identifier: "en_US")
        let text = day.startOfDay(in: calendar).formatted(style)
        return uppercase ? text.uppercased() : text
    }

    var visibleDays: [MissedDayRecap.MissedDay] {
        showsAllDays ? recap.missedDays : Array(recap.missedDays.prefix(Self.fullyShownDays))
    }

    var hiddenDayCount: Int { recap.missedDays.count - visibleDays.count }

    func visibleTitles(for day: MissedDayRecap.MissedDay) -> [String] {
        expandedDays.contains(day.day) ? day.undoneRequiredTaskTitles : Array(day.undoneRequiredTaskTitles.prefix(Self.fullyShownTitles))
    }

    func hiddenTitleCount(for day: MissedDayRecap.MissedDay) -> Int {
        day.undoneRequiredTaskTitles.count - visibleTitles(for: day).count
    }

    func expand(_ day: DayKey) {
        expandedDays.insert(day)
    }

    var accessibilityStreak: String? {
        recap.previousStreak > 0 ? "Streak was \(recap.previousStreak), now 0." : nil
    }

    // MARK: Streak Freeze

    private var today: DayKey { DayKey(now(), calendar: calendar) }

    /// The Missed Day a Streak Freeze can be spent on, if the recap offers one.
    var freezeOffer: DayKey? {
        StreakFreeze.offer(recap: recap, lastUsed: store.read(.settings).streakFreezeUsedOn, today: today, calendar: calendar)
    }

    var freezeLabel: String? {
        freezeOffer.map { _ in "Use Streak Freeze to keep your \(recap.previousStreak)\u{2011}day Streak" }
    }

    /// Spends this week's Freeze on the offered Missed Day, then acknowledges the recap.
    func useFreeze() {
        guard let day = freezeOffer else { return }
        var records = store.read(.dayRecords)
        StreakFreeze.apply(to: &records, day: day)
        store.write(records, to: .dayRecords)
        var settings = store.read(.settings)
        settings.streakFreezeUsedOn = today
        store.write(settings, to: .settings)
        acknowledge()
    }

    /// Marks every listed Day as seen. Only called from the button, so a killed app shows the recap again.
    func acknowledge() {
        guard let newest = recap.missedDays.first?.day else { return }
        var settings = store.read(.settings)
        settings.recapAcknowledgedThrough = max(newest, settings.recapAcknowledgedThrough ?? newest)
        store.write(settings, to: .settings)
    }
}
