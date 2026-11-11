import Foundation
import Testing
@testable import LockInCore

struct LockPolicyTests {
    typealias V = LockPolicy.Violation
    static let base = LockInTask(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "Gym",
                                 schedule: .weekly([.monday, .wednesday]), requirement: .required,
                                 startTime: TimeOfDay(hour: 18, minute: 0)!, createdOn: DayKey("2026-11-01")!)
    static func with(_ change: (inout LockInTask) -> Void) -> LockInTask {
        var t = base
        change(&t)
        return t
    }
    static let gym = Place(name: "Gym", latitude: 47.37, longitude: 8.54)

    static let table: [(String, LockInTask?, LockInTask?, [V])] = [
        // Allowed
        ("add a Task", nil, base, []),
        ("edit the title", base, with { $0.title = "Lift" }, []),
        ("optional → required", with { $0.requirement = .optional }, base, []),
        ("add a weekday", base, with { $0.schedule = .weekly([.monday, .wednesday, .friday]) }, []),
        ("earlier Start Time", base, with { $0.startTime = TimeOfDay(hour: 9, minute: 0) }, []),
        ("remove the Start Time", base, with { $0.startTime = nil }, []),
        ("raise a step target", with { $0.kind = .stepGoal(target: 5000) }, with { $0.kind = .stepGoal(target: 8000) }, []),
        ("add a place", base, with { $0.kind = .location(gym) }, []),
        ("unchanged", base, base, []),
        // Disallowed
        ("delete a Task", base, nil, [.deleteTask]),
        ("required → optional", base, with { $0.requirement = .optional }, [.makeOptional]),
        ("remove a weekday", base, with { $0.schedule = .weekly([.monday]) }, [.removeWeekdays]),
        ("swap a weekday", base, with { $0.schedule = .weekly([.monday, .thursday]) }, [.removeWeekdays]),
        ("later Start Time", base, with { $0.startTime = TimeOfDay(hour: 20, minute: 0) }, [.laterStartTime]),
        ("add a Start Time", with { $0.startTime = nil }, base, [.laterStartTime]),
        ("lower a step target", with { $0.kind = .stepGoal(target: 8000) }, with { $0.kind = .stepGoal(target: 5000) }, [.lowerStepTarget]),
        ("remove a step goal", with { $0.kind = .stepGoal(target: 8000) }, base, [.changeKind]),
        ("add a step goal", base, with { $0.kind = .stepGoal(target: 8000) }, [.changeKind]),
        ("move a place", with { $0.kind = .location(gym) }, with { $0.kind = .location(Place(name: "Gym", latitude: 47.0, longitude: 8.0)) }, [.changePlace]),
        ("remove a place", with { $0.kind = .location(gym) }, base, [.changePlace]),
        ("change a one-time Day", with { $0.schedule = .once(DayKey("2026-11-12")!) }, with { $0.schedule = .once(DayKey("2026-11-13")!) }, [.changeOnceDay]),
        ("one-time → weekly", with { $0.schedule = .once(DayKey("2026-11-12")!) }, base, [.changeOnceDay]),
        ("weekly → one-time", base, with { $0.schedule = .once(DayKey("2026-11-12")!) }, [.removeWeekdays]),
        ("two at once", base, with { $0.requirement = .optional; $0.startTime = TimeOfDay(hour: 21, minute: 0) }, [.makeOptional, .laterStartTime]),
    ]

    @Test(arguments: table)
    func taskChanges(name: String, old: LockInTask?, new: LockInTask?, expected: [V]) {
        #expect(LockPolicy.violations(from: old, to: new) == expected, "\(name)")
        #expect(LockPolicy.allows(from: old, to: new) == expected.isEmpty, "\(name)")
    }

    @Test func setsMayOnlyGrow() {
        #expect(LockPolicy.allowsSetChange(from: [1, 2], to: [1, 2, 3]))
        #expect(LockPolicy.allowsSetChange(from: [1, 2], to: [1, 2]))
        #expect(!LockPolicy.allowsSetChange(from: [1, 2], to: [1, 3]))
    }

    @Test func everyViolationExplainsItself() {
        for v in V.allCases { #expect(!v.message.isEmpty) }
    }
}

struct LockModeTests {
    let now = Date(timeIntervalSince1970: 1_794_000_000)

    @Test func startsAndEnds() {
        var mode = LockMode()
        #expect(!mode.isActive(at: now))
        mode.lock(days: 3, now: now)
        #expect(mode.isActive(at: now.addingTimeInterval(3 * 86_400 - 1)))
        #expect(!mode.isActive(at: now.addingTimeInterval(3 * 86_400)))
    }

    @Test func canBeExtendedButNeverShortened() {
        var mode = LockMode()
        mode.lock(days: 7, now: now)
        let end = mode.lockedUntil
        mode.lock(days: 1, now: now)
        #expect(mode.lockedUntil == end)
        mode.lock(days: 14, now: now)
        #expect(mode.lockedUntil == now.addingTimeInterval(14 * 86_400))
    }

    @Test func durationsMatchV2() {
        #expect(LockMode.durations == [1, 3, 7, 14, 30])
    }
}
