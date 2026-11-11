import Foundation
import Testing
@testable import LockInCore

struct ReviewPromptTests {
    @Test(arguments: [(6, false, false), (7, false, true), (30, false, true), (7, true, false), (0, false, false)])
    func requestsOnceAtSevenDays(streak: Int, alreadyRequested: Bool, expected: Bool) {
        #expect(ReviewPrompt.shouldRequest(streak: streak, alreadyRequested: alreadyRequested) == expected)
    }

    @Test func flagSurvivesARoundTrip() throws {
        var s = Settings()
        s.hasRequestedReview = true
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        #expect(decoded.hasRequestedReview)
    }
}
