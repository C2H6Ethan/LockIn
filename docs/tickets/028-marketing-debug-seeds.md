# 028: Debug seeds for marketing Captures, and times in the user's locale

Status: done
Depends on: nothing. Asked for by marketing ticket M001 (App Store screenshots), which captures the app on the simulator with `-seed` launch arguments. Approved by the founder 2026-11-12.

## Goal
1. The App Store screenshots need app states that `-seed` can't produce yet. Add them as Debug-only launch arguments, next to the existing ones in `DebugSeed.swift` and `DebugLaunch.swift`. No UI, copy or Release-build change for these.
2. Times of day follow the user's locale. Today a US user sees "blocks from 23:30" and "Blocking resumes at 21:52" next to Lock Mode's "9:43 PM".

## Seeds
Each one goes through the same path the real data takes (the store, `StepsToday`, `VisitLog`, the `StepCounter` protocol), so the screen shows what a real user would see. None of them writes a completion directly unless stated.

1. **`-seedSteps <n>`**: `StepsToday.total = n`. With `-seedSteps 8412`, Walk (8,000 steps) shows as done because its target is met, not because the log says so.
2. **`-seedStepsRise <from> <to> <seconds>`**: after launch, the step total rises from `from` to `to` over `seconds`, through the same update path as HealthKit. Walk ticks itself off on camera (for the "Walk it off" screenshot, the App Preview and TikTok Clips).
3. **`-seedVisited`**: Climbing (the Location Task) is due every day, and its visit to Minimum Boulder is recorded for today, so Today shows it ready to tick off. With `-seedDone` as well, it's also completed.
4. **`-seedPedometer <n>`**: replaces the `StepCounter` with a fake that reports available and counts up from `n` by about 2 steps a second. The Bypass walk screen then shows real progress on the simulator instead of "Can't count steps."
5. **`-seedStreak <n>`**: the Streak shows `n` days (sets `streakSeed.count`). For a 30-day Streak screenshot.

## Times in the user's locale
- `TimeOfDay.description` and `ShieldStatus` format with `String(format: "%02d:%02d")`, so they're 24-hour everywhere. Show times through the locale instead (`Date.FormatStyle` with `.hour().minute()`, or a `TimeOfDay` formatter that takes a `Locale`): "11:30 PM" in en_US, "23:30" in de_CH.
- Covers the Blocking status line ("Blocking from …", "Blocking resumes at …"), the "blocks from …" line under a Task, the Tasks list, the reminder time and the blocking screen's copy if it shows a time.
- Keep `description` for logs and identifiers if anything relies on it (`ScheduledActivity` uses its own `%02d%02d`, which must not change).

## Tests first
One test per seed, in `LockInTests`, each launching `DebugSeed.applyIfRequested` (or the fake counter) with the arguments injected:
- `-seedSteps 8412`: Walk counts as complete in Today; `-seedSteps 5210`: it doesn't.
- `-seedStepsRise 7600 8100 2`: before the end the total is below 8,000; after it, Walk is complete.
- `-seedVisited`: Climbing is due today and `VisitLog.hasVisited(climbing, today)` is true; with `-seedDone`, it's completed.
- `-seedPedometer 300`: the fake counter is available and its first update is 300, and later updates are higher.
- `-seedStreak 30`: the Streak on Today is 30.
- Core: the Blocking status for a 23:30 Start Time reads "Blocking from 11:30 PM" with `Locale(identifier: "en_US")` and "Blocking from 23:30" with `de_CH`. Same for "Blocking resumes at …".

To make the arguments injectable, `DebugSeed` may take the argument list as a parameter (defaulting to `ProcessInfo.processInfo.arguments`).

## Out of scope
- The blocking screen. The simulator has no Screen Time; the founder captures it on the iPhone.
- The widget. Captured from the Home Screen by the founder.
