# 008: Day records and Streak

Status: todo
Depends on: 007

## Goal
A permanent record of how each Day ended, written even if the app isn't opened, and the Streak computed from those records.

## Terms
Day, Kept Day, Missed Day, Streak

## Scope
- `DayRecord`:
  - `day`
  - `requiredDue: [TaskSnapshot(id, title)]`, snapshotted when the Day ends
  - `completedRequired: Set<TaskID>`
  - `outcome`: `.kept`, `.missed` or `.frozen` (018)
- Finalising: `finalizeDays(through: yesterday)` writes a record for every un-finalised Day since the user's first Day. It is idempotent, and the first writer wins.
  - The DeviceActivityMonitor extension calls it on the `day` activity's `intervalDidStart` (midnight).
  - The app calls it on launch and foreground, to fill gaps.
  - Gap Days that neither caught are finalised from the current Tasks. This is best effort, and documented in code.
- First Day: the Day onboarding completed (012), stored in settings.
- Streak:
  - It counts consecutive Kept Days going back from yesterday.
  - Today is added once today is kept (all due Required Tasks done, or none due).
  - A Day with no Required Tasks is Kept.
  - `.frozen` counts as Kept.
  - A `streakSeed (count, asOf)` from the import (014) extends the run backwards.
- Show the Streak on Today.

## Acceptance criteria
- After 2 days without opening the app (with day 1 kept and day 2 missed), opening shows Streak 0 and two correct records.

## Tests first
- The user's example: Tasks done on day 1, no Required Tasks on day 2, done on day 3 gives Streak 3 on day 3 after completion and 2 before.
- One Missed Day resets the Streak to 0.
- Finalising twice yields identical records.
- Editing a Task after its Day ended does not change that Day's snapshot.
- Streak seed: a seed of 12 as of yesterday plus today kept gives 13.
