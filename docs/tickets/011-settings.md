# 011: Settings

Status: done
Depends on: 010

## Goal
One place for everything that isn't Today.

## Scope
- All Tasks: every Task, including those not due today. Required first, Optional under `OPTIONAL`. Each row shows its schedule and Start Time, and tapping opens the Task form (007).
- Blocklist editor (004).
- Reminder time and Off (010).
- Lock Mode entry point, added in 019.
- A hidden event-log screen (005), for example via a long-press on the version label.
- The version label.

## Acceptance criteria
- Every change syncs the `ScheduleRegistrar` and re-evaluates the Shield.

## Tests first
- View-model tests: changing the reminder time updates the settings document and `desiredActivities`.

## Notes
- Also has a "Screen Time access" row showing authorization status, with a tap to request it. It's useful whenever access is revoked.
- The event log opens with a long-press on the version label.
- The foreground refresh moved from `LockInApp` into `RootView`, so it always runs before the recap check (records first, then the recap).
- Debug builds: `-openSettings` pushes Settings on launch.
