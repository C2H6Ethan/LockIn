# 016: Step-Goal Tasks

Status: done (device check pending)
Depends on: 007

## Goal
A Task that completes itself, in the background, once the Day's steps reach its target.

## Terms
Step-Goal Task

## Scope
- `Task.kind = .stepGoal(target)`, plus a form section (007).
- These Tasks can't be completed manually (same as v2).
- HealthKit read access to `stepCount`, requested when the first Step-Goal Task is created.
- `HKObserverQuery` with `enableBackgroundDelivery(.immediate)`. **Add the missing entitlement `com.apple.developer.healthkit.background-delivery`**, which v2 lacked.
- On each update: query today's steps. If the target is reached, complete the Task, re-evaluate the Shield and reload the widget.
- Note for ADR 0001: the system waking the app in the background is allowed. The rule is that the *user* never has to open it.
- HealthKit data is unavailable while the device is locked, so delivery can lag until unlock. That's acceptable.

## Acceptance criteria (device)
- [ ] With the app force-quit, walking past the target completes the Task and drops the Shield.

## Tests first
- The core function `stepGoalCompletions(tasks:, stepsToday:) -> Set<TaskID>`.

## Notes
- `LockInTask.kind` (`.standard` / `.stepGoal(target:)`) decodes as `.standard` when missing, so Tasks saved by earlier v3 builds still load.
- Core: `StepGoal.completions`, `LockInTask.canCompleteManually`, and `TaskDraft.stepTarget` (100–100,000).
- `Enforcement.recordSteps(_:)` only ever adds completions (steps only rise during a Day), then re-evaluates the Shield.
- `StepGoalObserver` registers in `didFinishLaunching` when a Step-Goal Task exists, so HealthKit background launches re-attach it. The first Step-Goal Task requests access and checks today's steps right away.
- `AppDelegate` now owns `AppEnvironment` (it's needed in `didFinishLaunching`).
- Entitlement `com.apple.developer.healthkit.background-delivery` added.
- v2 `stepTarget`s now import straight into `.stepGoal`.
- Widget reload is left to 020.
