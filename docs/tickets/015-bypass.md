# 015: Bypass

Status: todo
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
