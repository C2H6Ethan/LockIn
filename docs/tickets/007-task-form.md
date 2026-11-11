# 007: Task form

Status: done
Depends on: 006

## Goal
One form for creating and editing a Task. It replaces v2's duplicated AddTaskSheet and EditTaskSheet.

## Terms
Task, Required Task, Optional Task, Start Time, Due

## Scope
- Fields: title, Required/Optional, schedule (weekday picker or a single Day), and Start Time (none, or 15-minute steps up to 23:30).
- Validation in core (`TaskDraft.validate()`):
  - The title is non-empty.
  - A weekly schedule has at least one weekday.
  - A one-time Day is today or later.
  - There are at most 15 distinct Start Times across all Tasks.
- Delete with confirmation.
- Saving or deleting applies immediately, including dropping the Shield today. Lock Mode (019) will later restrict this.
- After saving, sync the `ScheduleRegistrar` and re-evaluate the Shield.
- A sheet with `.large` detent, `presentationBackground` set to the background color, and the drag indicator hidden.
- Step-goal and location sections are added by 016 and 017.

## Acceptance criteria
- Creating a Required Task due now with a past Start Time raises the Shield immediately.
- Changing a Start Time re-registers activities.

## Tests first
- One `TaskDraft.validate()` test per rule.
- Converting a draft to a Task and back is lossless for edits.

## Notes
- Edit is reached by long-pressing a Task on Today (context menu). Settings' All Tasks list (011) will also open it.
- Debug builds accept `-openNewTask` to open the form on launch.
