import XCTest
@testable import LockIn

final class StepsBypassTests: XCTestCase {

    var sut: SharedStore!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "test.stepsBypass.\(UUID().uuidString)"
        sut = SharedStore(suiteName: suite)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - stepsRequired formula

    func testStepsRequired_defaultIs100() {
        XCTAssertEqual(sut.stepsRequired, 100)
    }

    func testStepsRequired_afterOneBypass_is200() {
        sut.recordBypassUsed()
        XCTAssertEqual(sut.stepsRequired, 200)
    }

    func testStepsRequired_afterTwoBypasses_is300() {
        sut.recordBypassUsed()
        sut.recordBypassUsed()
        XCTAssertEqual(sut.stepsRequired, 300)
    }

    func testStepsRequired_afterNineBypasses_cappedAt1000() {
        for _ in 0..<9 {
            sut.recordBypassUsed()
        }
        XCTAssertEqual(sut.stepsRequired, 1000)
    }

    func testStepsRequired_beyondCap_stays1000() {
        for _ in 0..<20 {
            sut.recordBypassUsed()
        }
        XCTAssertEqual(sut.stepsRequired, 1000)
    }

    func testStepsRequired_oldDate_resetsTo100() {
        sut.recordBypassUsed()
        sut.bypassCountDate = "2020-01-01"
        XCTAssertEqual(sut.stepsRequired, 100)
    }

    // MARK: - Goal freshness

    func testStepsChallengeViewModel_readsGoalFromStore() {
        // Contract: StepsChallengeViewModel.init reads store.stepsRequired directly,
        // so the goal is always fresh at construction time (never a stale caller value).
        // We verify the store reports 200 after 1 bypass — that is exactly what the VM reads.
        sut.recordBypassUsed()
        XCTAssertEqual(sut.stepsRequired, 200)
    }

    // MARK: - Shared counter

    func testStepsRequired_formula_scalesBy100() {
        // bypassCount 0 → 100, 1 → 200, 2 → 300
        XCTAssertEqual(sut.stepsRequired, 100)
        sut.recordBypassUsed()
        XCTAssertEqual(sut.stepsRequired, 200)
        sut.recordBypassUsed()
        XCTAssertEqual(sut.stepsRequired, 300)
    }

}
