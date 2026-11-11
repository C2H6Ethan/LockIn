import Testing
@testable import LockInCore

@Test func appGroupIdentifierIsStable() {
    #expect(AppGroup.id == "group.com.ethanbaumgartner.lockin")
}
