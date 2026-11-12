# 025: Focus and input feedback

Status: done

## Goal
The keyboard goes away when the user is done typing and never comes back by itself. Every tap on a control is clearly felt and seen.

## Found on device
1. The Return key on the task name (the blue ✓) added a new line instead of closing the keyboard. A multi-line `TextField` turns Return into a newline and never calls `onSubmit`.
2. Coming back from the place picker, or from the date popover for a one-time task, put the cursor back in the name and scrolled to the top. UIKit gives focus back to the field that had it when a sheet or popover opened.
3. A selected day was only slightly brighter than an unselected one.

## Scope
- Task name: a newline is stripped and closes the keyboard.
- Task form: touching or changing any other control (Required, Repeat, days, date, How it's done, Start time) closes the keyboard, and the place picker opens only after the keyboard is closed. Nothing is left focused to be restored.
- Day picker: a selected day is a filled accent circle with a dark letter (like a ticked-off task's marker), animated, with a selection haptic on every change.
- Audit of every other input:
  - Place search: Search submits, and focus there is intended.
  - Blocklist website field: Return adds the site and keeps the keyboard up for the next one, which is intended.
  - No other text fields.

## Tests first
None automatable: focus and haptics need a real device (no UI test target). Covered by the device checks below.

## Device checks
- [ ] Type a task name and tap ✓: the keyboard closes, and the name stays on one line.
- [ ] Type a name, then without closing the keyboard choose Place, pick a place and come back: the form shows the place, there's no keyboard, and it doesn't jump to the top.
- [ ] Same with Once → tap the date → pick a day.
- [ ] Tap each day: it fills or empties, with a light tap felt each time.
