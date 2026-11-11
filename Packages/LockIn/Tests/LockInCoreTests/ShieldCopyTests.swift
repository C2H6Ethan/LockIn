import Foundation
import Testing
@testable import LockInCore

struct ShieldCopyTests {
    @Test func subtitleListsUpToThreeOwedTasksUnderAHeader() {
        var rng = SeededGenerator(seed: 1)
        let text = ShieldCopy.subtitle(owed: ["Read", "Gym", "Journal", "Walk"], using: &rng)
        let lines = text!.split(separator: "\n").map(String.init)
        #expect(ShieldCopy.headers.contains(lines[0]))
        #expect(Array(lines.dropFirst()) == ["• Read", "• Gym", "• Journal", "+1 more"])
    }

    @Test func noOwedTasksMeansNoSubtitle() {
        var rng = SeededGenerator(seed: 1)
        #expect(ShieldCopy.subtitle(owed: [], using: &rng) == nil)
    }

    @Test func titleIsOneOfTheShameMessages() {
        var rng = SeededGenerator(seed: 7)
        #expect(ShieldCopy.shameMessages.contains(ShieldCopy.title(using: &rng)))
    }

    @Test func owedTasksAreOnlyThoseAlreadyEnforced() {
        let cal = calendar()
        let read = task("Read")
        let gym = task("Gym", startTime: time(18))
        let owed = ShieldDecision.owedTasks(at: instant("2026-11-10", 12), tasks: [read, gym], completions: CompletionLog(), calendar: cal)
        #expect(owed.map(\.title) == ["Read"])
    }
}

struct DeepLinkTests {
    @Test func parsesKnownLinks() {
        #expect(DeepLink(url: URL(string: "lockin://today")!) == .today)
        #expect(DeepLink(url: URL(string: "lockin://bypass")!) == .bypass)
        #expect(DeepLink(url: URL(string: "lockin://nope")!) == nil)
        #expect(DeepLink(url: URL(string: "https://bypass")!) == nil)
        #expect(DeepLink.bypass.url == URL(string: "lockin://bypass"))
    }
}

/// Deterministic generator for tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
