# 020: Widget

Status: todo
Depends on: 008

## Goal
A home-screen glance at today's progress and the Streak.

## Scope
- Small and medium sizes. Show the Required Tasks done out of the total, and the Streak. Medium also lists the undone Required Task titles.
- Read-only `LockInCore` and store. No ManagedSettings.
- The timeline has entries at midnight and at each Start Time. The app calls `WidgetCenter.reloadAllTimelines()` after any completion or Task change.
- Uses the design tokens.

## Tests first
- The core function `widgetSnapshot(tasks:, completions:, records:, now:)`.
