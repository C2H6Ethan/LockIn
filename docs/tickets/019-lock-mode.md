# 019: Lock Mode

Status: todo
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
