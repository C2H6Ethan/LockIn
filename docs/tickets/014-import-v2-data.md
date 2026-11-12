# 014: Import v2 data

Status: done
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

## Notes
- Pure mapping in `LockInCore/Import/V2Import.swift`; reading v2 defaults and writing v3 in `LockInPlatform/V2Migration.swift`.
- Runs from `V2Migration.runIfNeededInAppGroup`, called explicitly at startup by the app and by the monitor extension, so whichever process starts first after the update imports. The user doesn't have to open the app (ADR 0001). It used to run hidden inside `Enforcement.live`, which made a factory call write data.
- Triggers when `v3.schemaVersion` is absent and v2 left `tasks` or `hasCompletedOnboarding`. `schemaVersion` is written on every outcome, including failure, so a broken import is never retried over v3 data.
- One-time Tasks: dropped if v2 shows them completed; otherwise due today (v2 showed them from their start date until done).
- Only today's completions are imported. Earlier history isn't needed, because the Streak continues via the seed.
- Streak seed: v2's `currentStreak` continues if `lastCompletedDate` is yesterday. If it's today, the seed is `currentStreak - 1` as of yesterday, and today's imported completions keep today. Anything older means the Streak was already broken.
- An unreadable `selectedApps` keeps the Tasks and leaves the apps to be re-picked (logged).
- **Found while doing this:** v2 shielded through the *default* ManagedSettings store. `ShieldApplier.update` now empties that legacy store on every call, otherwise v2's shields could stay up forever after the update.
- Step targets and locations are kept in `v3.v2Leftovers` for 016/017.
