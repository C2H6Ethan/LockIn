# 015: Bypass

Status: done (device checks pending)
Depends on: 013

## Goal
Earn a short break from the Shield by walking. Each Bypass on a Day costs more.

## Terms
Bypass, Shield

## Scope
- Keep v2's behavior. Check the exact numbers against `StepsChallengeViewModel` and `Constants` on `main`:
  - Step cost is 100 × (Bypasses used today + 1), capped at 1,000.
  - The window lasts 15 minutes.
- `lockin://bypass` opens the walk screen, which counts live steps with CoreMotion (`CMPedometer`).
- Starting a window:
  - Store a Bypass (id, start, end).
  - Clear the Shield.
  - Register a `bypass-end` activity (from end to end + 15 minutes, one-shot).
  - At the end, the extension re-evaluates `ShieldDecision`, which now takes an active Bypass into account.
- Race safety: v2 had a bug where a stale callback could cut short a later Bypass. Every callback checks the current Bypass id and end time before acting.
- Notification at the end: "Bypass over." This replaces v2's "Break's over".
- One name only. No unblock, stepping, break or access window.

## Acceptance criteria (device)
- [ ] The Shield lifts for 15 minutes and returns with the app force-quit.
- [ ] A second Bypass costs 200 steps.

## Tests first
- `ShieldDecision` with an active or expired Bypass.
- The step-cost table.
- A stale `bypass-end` callback for an older window is ignored.

## Notes
- Core: `BypassLog` (step cost, 15-minute window, today's count, pruned to two Days); `ShieldDecision.shouldShield` takes it.
- `bypass-end-<epoch seconds>` is a one-shot DeviceActivity schedule from the end to end + 16 minutes. It's part of `ScheduledActivity.desired` while a Bypass is pending, so the idempotent registrar owns it like every other activity.
- Race safety: `BypassLog.expire(endingAt:now:)` acts only when the callback's end matches the current window. A callback up to 60 s early still ends it, so an early fire can't leave the Shield down. A stale callback just re-evaluates.
- Starting a Bypass while one is active cuts the old one short, so there is only ever one window.
- "Bypass over." is posted only if the Shield actually came back up.
- The Shield's "Earn access" notification now says how many steps the next Bypass costs.
- Walk screen states: walking, active ("You gave in." from v2), nothing owed, steps unavailable. Debug: `-openBypass`.
- v2's onboarding "Earn your way in" step isn't brought back. The Shield's button and the walk screen explain it where it matters.
