# 023: UX restructure

Status: done (2026-11-12)
Depends on: 001–021. Lands before 022's TestFlight step.

## Goal
Make LockIn obvious at a glance and quick to use, without losing its minimalism: Today says whether blocking is on and why, Tasks are one tap away, the Task form is short, and every screen holds up under Dynamic Type and VoiceOver.

## Terms
Shield, Today, Task, Required Task, Optional Task, Start Time, Due, Bypass, Lock Mode, Kept Day, Step-Goal Task, Location Task, Blocklist.
New (added to GLOSSARY.md): **Completes by**, **Blocking status**. User-facing copy says *blocking*, never "Shield".

## Scope

### Today
- A **blocking status** line under the title, from core `ShieldStatus.current(...)` (below). One line, secondary color, accent only when it asks for action:
  - `Blocking on · 2 required tasks left`
  - `Blocking from 23:30`: Required Tasks remain, none enforced yet.
  - `Blocking resumes at 14:05`: a Bypass is active.
  - `Blocking off · Day kept`
  - `No required tasks today`
  - `Blocking can't start: allow Screen Time access ›` (tappable, accent)
  - `Nothing to block: choose your Blocklist ›` (tappable, accent)
  - A second line while Lock Mode is on: `Locked until Fri 14:00`.
- Editing without long-press. Tapping the marker completes a Task; tapping the title opens the form. The context menu stays (Edit, plus Complete or Undo).
- Step-Goal Tasks show progress (`5,210 of 8,000 steps`) when today's total is known and fall back to `8,000 steps` when it isn't (locked phone, access denied, nothing read yet). The app reads the total; Today never asks HealthKit itself.
- The success haptic fires only for the tick that drops the Shield, with a brief `Blocking off · Day kept` status change. Other ticks get `.selection`.
- Empty state: one line and the add action, plus `3 tasks on other days ›` when Tasks exist but none are due.

### Tasks
- A Tasks screen lists every Task: Required first, then Optional, each sorted by title, with past one-time Tasks last and dimmed. Tapping a row edits it. It reuses the current Settings sort, moved to core.
- Settings loses its Tasks section.
- Navigation (decision below): **A**, a push from Today, or **B**, a three-tab `TabView`. Either way `lockin://today`, `lockin://bypass` and every debug launch arg keep working.

### Task form
- Order: name, Required, Repeat (days or one Day), **Completes by**, Start Time (Required Tasks only; the row is removed, not hidden by opacity).
- **Completes by** is one segmented choice: `Tapping` / `Steps` / `Place`. It maps 1:1 onto `LockInTask.Kind`. The "step goal or a place, not both" validation goes away because it can no longer happen.
- The keyboard doesn't cover the form on open: focus the name only for a new Task, and scroll so the Required row stays visible above the keyboard.
- When Save is disabled, the reason shows under the name (e.g. "Give the task a name."), not only after typing.
- Optional Tasks save without a Start Time.

### Settings
- Lock Mode moves to the top. Starting it opens a sheet, not a confirmationDialog. The sheet lists `LockMode.durations` (1, 3, 7, 14, 30 days) with the end date for each, says plainly that it can't be ended early, and confirms with a button that names the date ("Lock until Fri, Nov 20").
- Sections: Lock Mode, Blocking (Blocklist, Screen Time access), Reminder, About.

### Shield and copy
- Shield secondary button: "Earn access" → "Earn a Bypass", in `ShieldCopy`.
- Replace "Shield" in all user-facing copy with blocking wording: "Blocks from 18:00 until done." (form), "Walk 200 steps to pause blocking for 15 minutes." (walk screen), "Blocking is back on." (notification), "Nothing is blocked right now." (walk screen, nothing owed). `ShieldCopy`'s shame messages and headers already avoid the word.
- One casing rule across all copy (decision below). Apply it to the recap, widget, onboarding, Settings, form and Shield.
- Rewrite the step-counting lines (walk screen, unavailable device, Step goal footnote) for plain reading.

### Accessibility and visual
- Secondary color (decision below): `#6B6B6B` → `#8A8A8A` (5.7:1) in `Palette`, `DesignSystem` and CLAUDE.md.
- No `.system(size:)` on user-facing text. Use text styles plus `@ScaledMetric` for the Bypass counter, onboarding and Bypass headlines, the location marker and the widget number.
- Accessibility sizes: Today rows wrap, the status line wraps, the weekday picker switches to full names in a vertical list, and the form stacks labels above controls.
- VoiceOver: the status line is the first element after the title. Task rows read "Read 20 pages, Required, not done" with a "Complete" action and an "Edit" custom action. Step progress is spoken as "5,210 of 8,000 steps".
- Missing Screen Time access shows on Today (status line), not only in Settings.

### Out of scope
- Any change to rules in `ShieldDecision`, `LockPolicy`, Bypass pricing or Streak math.
- Liquid Glass (iOS 26 only; LockIn supports iOS 17).
- Custom UI on the Shield.

## Tests first
- `ShieldStatus.current(now:tasks:completions:bypasses:lockMode:screenTimeAllowed:blocklistIsEmpty:calendar:)`, as a table test:
  - No Required Tasks due → `.noRequiredTasks`.
  - All Required done → `.down`.
  - Owed Tasks → `.up(left:)`, counting every incomplete Required Task due today.
  - Owed Tasks with an active Bypass → `.bypassed(until:)`.
  - Only future Start Times → `.startsAt(earliest)`.
  - Screen Time not allowed → `.needsScreenTime`, overriding everything else.
  - Empty Blocklist → `.needsBlocklist`.
  - `lockedUntil` is set only while Lock Mode is active.
- Invariant: whenever access is allowed and the Blocklist isn't empty, `status.isShieldUp == ShieldDecision.shouldShield(...)` over every case above.
- Copy: each status maps to the exact strings above, none containing "Shield" (`ShieldStatus.text`), with singular and plural handled ("1 required task left").
- `TodayModel`: ticking the last owed Task increments `shieldDrops`; any other tick, an un-tick, or an Optional Task leaves it. (A counter, not a `droppedShield` flag, because `.sensoryFeedback` fires on a value change and a flag would stay `true` after the first drop.)
- `TaskDraft.completesBy`: round-trips each `Kind`. Optional drafts save with `startTime == nil`. `.stepGoalAndPlace` is gone, and drafts from Tasks that have both can't exist.
- `TaskList.sorted(_:today:)` (moved from `SettingsModel`): Required before Optional, by title, past one-time Tasks last.
- `StepProgress` from the stored total: known today, unknown, or from another Day (treated as unknown).
- Keep green: `swift test` (146 core tests), `xcodebuild test` on the iPhone 15 simulator, and a device build (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`).

## Acceptance (simulator screenshots, before and after)
- [x] Today: blocking on, blocking from, blocking off, Bypass active, Lock Mode active, no Screen Time access, empty, and accessibility XXL.
- [x] Tasks, the Task form (new, Optional, steps, place, locked), Settings, the Lock Mode sheet, the walk screen, the recap and onboarding.
- [x] `grep -rn "system(size" LockIn LockInWidget` returns only `DesignSystem.Typography.display(size:)`: the step counter needs a size no text style has, so it's one helper fed by `@ScaledMetric`.

## Notes
- Step progress needs today's total persisted: `v3.stepsToday` (`DayKey` + total), written by `Enforcement.recordSteps`. It's a new App Group key and needs no migration.
- Debug: new launch args `-seedBypass`, `-seedLocked`, `-seedEmpty`, `-seedNoScreenTime` and `-openTasks`, in `DebugLaunch` and `DebugSeed`.

## Built
- Core: `ShieldStatus`, `TaskList`, `TaskDraft.CompletesBy`, `StepsToday` + `StepGoal.progress`. 169 core tests.
- App: Today (status line, marker/title split, step ring, drop haptic, empty state), Tasks screen, short Task form with Save reason, Settings with Lock Mode first and `LockModeSheet`, walk screen copy and scaled counter, blocking wording everywhere, `#8A8A8A`.
- `AppEnvironment.refreshSteps` now calls back after every read (was: only on completion), so step progress updates live.
- Debug: `-seedFrom` and `-seedDone` in addition to the args listed in Notes. Seeded launches treat Screen Time as allowed, since the simulator can't approve it.
- The design prototype (`PrototypeScreens.swift`, `-prototype`) is removed now the real screens exist.
- More debug args: `-openLockSheet`, `-openEdit <title>`, `-seedOnboarding`.
- Fixed a crash from 017: `PlaceMonitor`'s `CLMonitor` name `lockin.places` raised "Monitor name is not valid" on launch whenever a Location Task existed. Now `lockinPlaces`.

## Decisions
1. Navigation: **push from Today.** Today stays the root; the top bar has Settings (leading), Tasks and + (trailing). No tab bar. *(decided 2026-11-11)*
2. Secondary color: **`#8A8A8A`.** *(decided 2026-11-11)*
3. Shield secondary button: **"Earn a Bypass".** *(decided 2026-11-11)*
4. Casing: **named features are capitalized** (Bypass, Blocklist, Lock Mode, Streak Freeze, Screen Time); **everyday nouns are lowercase** (task, required, optional, streak, day). Examples: "Your 12-day streak ended.", "Blocking on · 2 required tasks left". Code and GLOSSARY.md keep their capitalized type names. *(decided 2026-11-11)*
5. Glossary: **Completes by** (Tapping · Steps · Place) and **Blocking status** added. *(decided 2026-11-11)*
6. On-screen wording: **blocking**, not "Shield" (users read "shield" as protection). Code keeps `Shield…` names, which match Apple's API. *(decided 2026-11-11)*
