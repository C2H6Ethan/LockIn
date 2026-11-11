# 017: Location Tasks

Status: done (device checks pending)
Depends on: 007

## Goal
A Task that can only be completed after visiting its place that Day.

## Terms
Location Task

## Scope
- `Task.kind = .location(Place(name, latitude, longitude))`, with a fixed 200 m radius.
- Form section: place search with `MKLocalSearchCompleter`, plus a draggable map pin (v2 Phases 29/30 on `main` for reference).
- Monitoring:
  - iOS 17 `CLMonitor`, one region condition per Location Task, with a shared iOS limit of 20.
  - "Always" authorization, requested when the first Location Task is created, with the Info.plist strings.
  - On entry, record a `Visit(day, taskId)` in the store.
- Completion: tapping is allowed only if a Visit exists for today, or a fresh location fix is within radius. Otherwise the row shows an error ("Not at {place} yet today.").
- The row shows a map-pin marker and the place name.

## Acceptance criteria (device)
- [ ] Visiting the place with the app closed, then tapping later, completes the Task.
- [ ] Tapping without a visit is rejected.

## Tests first
- The core function `canComplete(task:, visits:, currentLocation:, day:)`.
- A distance check at 199 m and at 201 m.

## Notes
- Core: `Coordinate` (haversine), `Place` (200 m), `VisitLog` (7 Days), and `LocationRule.canComplete`.
  - `TaskDraft.place` is limited to 20 places.
  - A Task has a step goal or a place, never both. v2 allowed both; on import the step goal wins.
- `PlaceMonitor` wraps one `CLMonitor("lockin.places")` in an actor.
  - Conditions are keyed by Task id. Unchanged places aren't re-added, which would reset their state.
  - It's synced from `didFinishLaunching` and after every change, and creates nothing while no Location Task exists.
- Region entry → `Enforcement.recordVisit` (logged). A visit never completes the Task by itself; the user still taps.
- Tapping a Location Task:
  - If there's a visit today, it completes at once.
  - Otherwise it takes a one-shot `CLLocationUpdate.liveUpdates` fix (accuracy ≤ 100 m, 15 s timeout). Within radius, it completes and records the visit. Otherwise the row says "Not at {place} yet today.", or "Couldn't find your location." when there's no fix.
- "Always" access is requested when the first Location Task is saved.
- Place picker: `MKLocalSearchCompleter` search; then tap the map to move the pin, with the 200 m circle shown. Tap-to-move replaces dragging: it's simpler in SwiftUI's `Map` and gives the same result.
- Not visually verified in the simulator (needs search and map interaction). Added to the device checks.
- `V2Leftovers` is gone, because v2 locations now import straight into `.location`.
