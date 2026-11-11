# 019: Lock Mode

Status: done
Depends on: 011

## Goal
A timed commitment during which LockIn can only get stricter. There is no weaselling out.

## Terms
Lock Mode, Blocklist, Required Task

## Scope
- Start from Settings with a duration. Reuse the durations from v2's `LockSheet` on `main`. It can't be ended early. Settings and the form show "Locked until {date}".
- Core `LockPolicy.allows(change: from:to:) -> Bool`:
  - **Allowed:**
    - Add Tasks.
    - Optional to Required.
    - Add weekdays.
    - Make a Start Time earlier, or remove it (no Start Time means enforced from midnight).
    - Raise a step target.
    - Add Blocklist items.
    - Edit a title.
    - Change the reminder.
  - **Disallowed:**
    - Delete a Task.
    - Required to Optional.
    - Remove weekdays.
    - Make a Start Time later, or add one to a Task that had none (that moves enforcement later than midnight).
    - Lower a step target.
    - Change or remove a Location.
    - Remove Blocklist items.
    - Change a one-time Task's Day.
- The UI hides or disables disallowed controls and explains why in one secondary line.
- Known limit, documented in-app: revoking Screen Time authorization in iOS Settings can't be prevented.

## Tests first
- An exhaustive table test of `LockPolicy` for every field change listed above.

## Notes
- Core: `LockMode` (`v3.lockMode`), which can be extended but never shortened or ended. `LockPolicy.violations(from:to:)` returns typed violations, each with a message; `allows` means there are none. The table test covers every allowed and disallowed change.
- Decisions beyond the ticket's list:
  - Swapping weekdays is a removal.
  - Weekly ↔ one-time switches are disallowed.
  - Adding a place to a standard Task is allowed (stricter).
  - Adding or removing a step goal is disallowed, because walking could replace the actual Task.
- Blocklist: `LockPolicy.allows(from: Blocklist, to:)` in the platform maps every token set and the custom domains onto the core rule "sets may only grow".
- UI:
  - The form shows "Locked until …" and why Save is disabled, and hides Delete.
  - Blocklist rows can't be swiped away, and Save refuses removals made in the picker, with a message.
  - Settings has a Lock Mode section with a duration dialog, "Extend", and the known Screen Time limit stated.
