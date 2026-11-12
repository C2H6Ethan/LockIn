# 012: Onboarding

Status: done
Depends on: 011

## Goal
A first-run flow that ends with blocking working.

## Scope
- Steps follow v2's `OnboardingView` on `main` (reuse its copy), split into one small view per step:
  1. Welcome
  2. Screen Time explainer, then `AuthorizationCenter.requestAuthorization(for: .individual)`
  3. Pick Blocklist (004)
  4. Create a first Task (007)
  5. Notification permission
  6. Done
- Health and Location permission steps are added by 016 and 017, only when the user creates such a Task.
- On finish: store the first Day (008) and `hasCompletedOnboarding`, then sync the `ScheduleRegistrar`. Registration happens on the **first** launch, unlike v2.
- If Screen Time authorization is denied: an explanation plus a retry. The flow can't finish without it.

## Acceptance criteria
- On a fresh install, onboarding leads to the Shield being up for the first Task without relaunching.

## Tests first
- Flow state-machine tests: step order, and the denied-authorization branch.

## Notes
- Steps: welcome, how blocking works (requests Screen Time access, retries until allowed), Blocklist (skippable), first Task via the shared Task form (skippable), notifications, done.
- v2's Health and walking-Bypass explainer steps return with 015/016, and only appear when relevant.
- `PrimaryButton` and `SecondaryButton` in `LockIn/Components` are shared with the recap.
