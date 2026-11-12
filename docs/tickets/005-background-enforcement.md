# 005: Background enforcement

Status: done
Depends on: 004

## Goal
The Shield goes up and comes down correctly for days on end **without the app being opened** (ADR 0001). This is the ticket that fixes the bug that motivated the rewrite.

## Terms
Day, Start Time, Shield

## Scope
- `ScheduleRegistrar` in `LockInPlatform`:
  - Diffs `desiredActivities` (002) against `DeviceActivityCenter().activities`. It starts missing activities and stops stale ones.
  - It is idempotent. There is **no** saved "already registered" flag.
  - Activities:
    - `day`: 00:00–23:59, repeating.
    - `start-HHmm`: from each distinct Start Time to 23:59, repeating.
  - The 23:30 cap means every interval is at least 29 minutes (iOS needs at least 15).
  - Called on app launch, on scene foreground, and after every Task, Blocklist or settings change.
  - It never swallows errors. Failures go to the event log.
- DeviceActivityMonitor extension: on `intervalDidStart` of any activity, load the store, ask `ShieldDecision`, then apply or clear via `ShieldApplier`. Nothing else.
- Event log: a 200-entry ring buffer in the store (timestamp, source, event). The extension writes one entry per callback. A hidden debug screen shows it (moves into Settings in 011).
- Keep the extension light, because its memory limit is tight: no SwiftUI or WidgetKit imports, and decode only the documents it needs.
- After this ticket, in-app completion (006) re-evaluates the Shield immediately through the same `ShieldDecision`.

## Acceptance criteria (on a real device, recorded in this ticket)
- [ ] The Shield goes up at midnight and at a Start Time, with the app force-quit, over **3 consecutive days** without opening the app. Verified through the event log afterwards.
- [ ] After a device reboot the schedules still fire.
- [ ] Deleting the only Task with a given Start Time removes its activity.
- [ ] The total number of activities stays at most 20 in the worst case (Start Times capped at 15 distinct values in 007).

## Tests first
- Registrar diff tests with a fake `DeviceActivityCenter`: missing activities are started, stale ones stopped, and a second run with no changes does nothing.
- Activity naming round-trips `TimeOfDay` to `start-HHmm` and back.

## Notes
- `Enforcement.refresh(reason:)` in `LockInPlatform` does sync + Shield + log. The app calls it on launch, on every foreground and after every change. The DeviceActivityMonitor extension calls it on every `intervalDidStart`.
- The extension also re-syncs schedules, so the set heals itself at midnight even if the app is never opened (for example, when a one-time Task's Day passes).
- The registrar stops every activity that isn't desired, which also removes v2's `com.ethanbaumgartner.lockin.*` activities after the update.
- The event log is reachable from the temporary debug home (moves into Settings in 011).
