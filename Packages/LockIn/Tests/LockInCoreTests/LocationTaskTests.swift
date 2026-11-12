import Foundation
import Testing
@testable import LockInCore

struct LocationTaskTests {
    let today = day("2026-11-10")
    let gym = Place(name: "Gym", latitude: 47.3769, longitude: 8.5417)

    let gymTask: LockInTask

    init() {
        var t = task("Gym")
        t.kind = .location(Place(name: "Gym", latitude: 47.3769, longitude: 8.5417))
        gymTask = t
    }

    /// A point `meters` due north of the place.
    func north(_ meters: Double) -> Coordinate {
        Coordinate(latitude: gym.latitude + meters / 111_194.9, longitude: gym.longitude)
    }

    @Test func distanceMatchesHaversine() {
        #expect(abs(gym.coordinate.distance(to: north(1000)) - 1000) < 1)
    }

    @Test func withinRadiusCompletes() {
        #expect(LocationRule.canComplete(task: gymTask, visits: VisitLog(), currentLocation: north(199), day: today))
    }

    @Test func outsideRadiusDoesNot() {
        #expect(!LocationRule.canComplete(task: gymTask, visits: VisitLog(), currentLocation: north(201), day: today))
    }

    @Test func noFixAndNoVisitDoesNot() {
        #expect(!LocationRule.canComplete(task: gymTask, visits: VisitLog(), currentLocation: nil, day: today))
    }

    @Test func aVisitTodayCompletesWithoutAFix() {
        var visits = VisitLog()
        visits.record(gymTask.id, on: today, calendar: calendar())
        #expect(LocationRule.canComplete(task: gymTask, visits: visits, currentLocation: nil, day: today))
    }

    @Test func yesterdaysVisitDoesNotCount() {
        var visits = VisitLog()
        visits.record(gymTask.id, on: day("2026-11-09"), calendar: calendar())
        #expect(!LocationRule.canComplete(task: gymTask, visits: visits, currentLocation: north(5000), day: today))
    }

    @Test func otherKindsAreNotGated() {
        #expect(LocationRule.canComplete(task: task("Read"), visits: VisitLog(), currentLocation: nil, day: today))
    }

    @Test func visitLogKeepsAWeek() {
        var visits = VisitLog()
        visits.record(gymTask.id, on: day("2026-11-01"), calendar: calendar())
        visits.record(gymTask.id, on: today, calendar: calendar())
        #expect(!visits.hasVisited(gymTask.id, on: day("2026-11-01")))
        #expect(visits.hasVisited(gymTask.id, on: today))
    }

    @Test func locationTasksAreTappableAndRoundTrip() throws {
        #expect(gymTask.canCompleteManually)
        #expect(gymTask.place == gym)
        #expect(try JSONDecoder().decode(LockInTask.self, from: JSONEncoder().encode(gymTask)) == gymTask)
    }

    @Test func draftCarriesThePlace() {
        var d = TaskDraft(task: gymTask, today: today)
        #expect(d.place == gym)
        #expect(d.completesBy == .place)
        d.completesBy = .tickOff
        #expect(d.makeTask(existing: gymTask, today: today)?.kind == .standard)
    }

    @Test func atMostTwentyPlaces() {
        let others = (0..<20).map { i -> LockInTask in
            var t = task("P\(i)")
            t.kind = .location(Place(name: "P\(i)", latitude: Double(i), longitude: 0))
            return t
        }
        var d = TaskDraft()
        d.title = "One more"
        d.completesBy = .place
        d.place = gym
        #expect(d.validate(otherTasks: others, today: today) == [.tooManyPlaces])
    }
}
