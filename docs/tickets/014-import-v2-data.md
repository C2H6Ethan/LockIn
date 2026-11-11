# 014: Import v2 data

Status: todo
Depends on: 012

## Goal
Existing users keep their Tasks, Streak and Blocklist when updating. If anything is unreadable, they get a clean onboarding instead of a crash.

## Scope
- Runs once, on launch, when `v3.schemaVersion` is absent and the v2 key `tasks` exists.
- Mapping:
  - `tasks`: title, `recurrence` becomes `schedule`, `blocksApps` becomes `requirement`, and `blockingStartTime` becomes `startTime` (rounded to 15 minutes, capped at 23:30). `stepTarget` and `location` are kept for 016/017.
  - `selectedApps` and `selectedWebDomains` become the Blocklist.
  - `reminderHour`, `reminderMinute` and `reminderNever` become the reminder setting.
  - `streakData.currentStreak` and `lastCompletedDate` become the `streakSeed`.
  - `hasCompletedOnboarding` carries over. The first Day becomes the import Day.
- Everything else is dropped. v2 keys are left untouched (removed in a later release). On success, write `v3.schemaVersion`.
- Any decode failure means skip the import, log it, and show onboarding. Never crash.

## Acceptance criteria (device)
- [ ] Install a v2 build from `main` and set it up, then install the rewrite over it. Tasks, Blocklist and Streak are intact, and the Shield works without re-picking apps.

## Tests first
- Fixtures shaped like v2 JSON (taken from v2's `Task.swift` and `SharedStore` on `main`, with synthetic values): a full mapping test.
- A Start Time of 23:50 becomes 23:30.
- Corrupt `tasks` leads to no import and onboarding.
- The import runs only once.
