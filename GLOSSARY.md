# LockIn

An iOS app that keeps distracting apps and websites blocked each day until the user's tasks for that day are done.

## Language

_Copy rule:_ on screen, capitalize named features (Blocklist, Bypass, Lock Mode, Streak Freeze, Screen Time) and keep everyday nouns lowercase (task, required, optional, streak, day): "Your 12-day streak ended." Code keeps the capitalized type names below.

**Task**:
Something the user commits to doing, on a recurring schedule or once.
_Avoid_: Habit, mission, todo

**Day**:
A single calendar day in the device's current time zone, midnight to midnight. Every rule in LockIn is evaluated per Day.

**Required Task**:
A Task that keeps the Shield up, from its Start Time, until it is completed.
_Avoid_: Blocking task

**Optional Task**:
A Task that is tracked but never causes a Shield and never affects the Streak.
_Avoid_: Non-blocking task

**Start Time**:
The time of day from which an incomplete Required Task puts up the Shield. Before its Start Time, the Task is due but not yet enforced.
_Avoid_: Blocking start time, lock time

**Due**:
A Task is due on a Day when its schedule includes that Day. Only due Tasks appear in Today.
_Avoid_: Active, scheduled

**Today**:
The set of Tasks due on the current Day, with their completion state.
_Avoid_: Today's tasks list, daily missions

**Blocklist**:
The apps, app categories and websites the user has chosen to be shielded.
_Avoid_: Selection, selected apps, groups

**Shield**:
The system block screen covering a blocked app or website while the user still owes Tasks for the Day. "Shield" is the code term (Apple's ManagedSettings name). On screen, say **blocking**: "Blocking on", "Blocks from 18:00 until done", "pause blocking".
_Avoid_: Lock, block screen, shame screen; "Shield" in user-facing copy

**Blocking status**:
The one line on Today that says whether blocking is on and why: "Blocking on · 3 required tasks left", "Blocking from 23:30", "Blocking off · Day kept", "Blocking resumes at 14:05", "Blocking can't start: allow Screen Time access". Code: `ShieldStatus`.
_Avoid_: Shield status, lock state

**Missed Day**:
A Day that ended with at least one due Required Task not completed. Its Tasks do not move to the next Day.
_Avoid_: Carryover, failed day

**Kept Day**:
Any Day that is not a Missed Day, including a Day with no Required Tasks due.

**Streak**:
The number of consecutive Kept Days up to the present, counted from the user's first Day or the most recent Missed Day.
_Avoid_: Chain, run

**Missed-Day Recap**:
A one-time summary, shown on the next app open, of the Missed Days since the user last looked and the Required Tasks left undone on each.
_Avoid_: Carryover, failure screen

**Streak Freeze**:
A weekly allowance the user can spend in the Missed-Day Recap to keep their Streak across exactly one Missed Day.
_Avoid_: Freeze token, skip

## Kinds of Task

**Step-Goal Task**:
A Task that completes itself once the Day's step count reaches its target.
_Avoid_: Steps task, HealthKit task

**Location Task**:
A Task that can only be completed after the user has visited its place on that Day.
_Avoid_: Location-verified task, geofence task

**Completes by**:
How a Task gets done, chosen once per Task: **Tapping** (the user ticks it off), **Steps** (a Step-Goal Task) or **Place** (a Location Task). Code: `LockInTask.Kind` (`.standard`, `.stepGoal`, `.location`).
_Avoid_: Task type, mode, verification

## Escaping and committing

**Bypass**:
A short window, earned by walking a number of steps, during which the Shield is lifted (on screen: blocking is paused) although Required Tasks remain. Each Bypass on a Day costs more steps than the last.
_Avoid_: Unblock, break, stepping, access window

**Lock Mode**:
A timed commitment during which the user can only make LockIn stricter: they can add to the Blocklist and add Tasks, but cannot remove, weaken or un-require anything.
_Avoid_: Strict mode, commitment mode
