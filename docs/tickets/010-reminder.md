# 010: Reminder

Status: todo
Depends on: 008

## Goal
One daily reminder at a user-chosen time, sent **only if** Required Tasks are still undone, with the real count, and without the app being opened.

## Terms
Required Task, Due

## Scope
- **Spike first (on a real device):** confirm that the DeviceActivityMonitor extension can post a `UNNotificationRequest` from `intervalDidStart`. Record the result here.
- If the spike succeeds:
  - Add a `reminder` activity from the reminder time to 23:59, repeating, to `desiredActivities`.
  - On start, the extension counts due, incomplete Required Tasks. If there are any, it posts "N tasks left" (exact copy to be decided in the ticket, without the serif), deep-linking to Today.
- If the spike fails: fall back to a repeating `UNCalendarNotificationTrigger` with static copy ("Did you finish your tasks?"), and note in ADR 0001's consequences that the reminder can't be conditional.
- Setting: a reminder time (15-minute steps, at most 23:30) or Off. The default is 20:00.
- Notification permission is requested in onboarding (012).

## Acceptance criteria (device)
- [ ] With Tasks undone and the app force-quit for 2 days, a reminder arrives each day.
- [ ] With all Tasks done, no reminder arrives.

## Tests first
- The core function `reminderContent(tasks:, completions:, day:) -> String?` returns nil when nothing is owed, and the correct count otherwise.
