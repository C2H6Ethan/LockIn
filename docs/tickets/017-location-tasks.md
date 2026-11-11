# 017: Location Tasks

Status: todo
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
