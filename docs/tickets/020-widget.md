# 020: Widget

Status: done
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

## Notes
- Core: `WidgetSnapshot.make` / `read(from:)` and `refreshDates` (later Start Times today, then midnight).
- The widget reads the App Group store only. Colors come from `LockInCore.Palette`, the same tokens `DesignSystem` uses.
- Small: "TODAY", done/total (accent when kept, "Free day" when nothing is Required), and the Streak. Medium adds up to 4 undone titles ("+N more"). Tapping opens `lockin://today`.
- Reloads: `Enforcement.refresh` calls `WidgetCenter.reloadAllTimelines()` (injectable). Every change — app edits, completions, steps, Bypass, the monitor's midnight run — passes through refresh, so a separate call in the app isn't needed.
- Not visually verified: the simulator can't place widgets from the command line. Device check: add both sizes to the Home Screen.
