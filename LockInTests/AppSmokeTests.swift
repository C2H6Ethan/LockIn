import CoreFoundation
import Testing
@testable import LockIn

@MainActor
@Test func appModuleLoads() {
    #expect(DesignSystem.Spacing.md == 16)
}
