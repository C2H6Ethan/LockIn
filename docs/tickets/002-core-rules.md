# 002: Core rules: Task, Due, Today, Shield decision

Status: todo
Depends on: 001

## Goal
All daily rules as pure, fully tested functions in `LockInCore`. No UI and no persistence.

## Terms
Task, Required Task, Optional Task, Start Time, Due, Day, Today, Shield

## Scope
- `DayKey`: a calendar Day (year, month, day) built from a `Date` plus a `Calendar`/`TimeZone`. Comparable, Codable as `yyyy-MM-dd`.
- `TimeOfDay`: hour and minute in 15-minute steps, with 23:30 as the latest allowed value.
- `Task`:
  - `id`
  - `title`
  - `schedule`: `.weekly(Set<Weekday>)` or `.once(DayKey)`
  - `requirement`: `.required` or `.optional`
  - `startTime: TimeOfDay?` (nil means midnight)
  - `kind`: `.plain` for now; `.stepGoal` and `.location` arrive in 016/017
- `task.isDue(on: DayKey)`.
- `Today`: due Tasks for a Day plus completion state, ordered Required first, then Optional.
- `ShieldDecision.shouldShield(at: Date, tasks:, completions:, calendar:) -> Bool`. It is true when any due Required Task whose Start Time has passed is incomplete. Bypass (015) is added later as an extra input.
- `ScheduledActivity` planning: `desiredActivities(tasks:, settings:) -> Set<ScheduledActivity>`. It returns a day activity plus one per distinct Start Time. Reminder (010) and Bypass (015) add theirs later.

## Acceptance criteria
- No `import` other than Foundation in `LockInCore`.
- Every rule below is covered by a test.

## Tests first
- Weekly Task is due only on its weekdays. A once Task is due only on its Day.
- An Optional Task never causes a Shield.
- A Required Task before its Start Time does not shield, and at or after it does.
- No Start Time means the Task shields from 00:00.
- All Required Tasks completed means no Shield. No Required Tasks due means no Shield.
- DST-change days and a timezone change keep weekday logic correct.
- `desiredActivities` dedupes identical Start Times.
