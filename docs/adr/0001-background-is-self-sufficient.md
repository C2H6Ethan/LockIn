# The app never has to be opened for daily enforcement

Blocking, reminders and the day rollover must work for days on end without LockIn being opened. All daily behavior is therefore driven by repeating `DeviceActivity` schedules (handled in the DeviceActivityMonitor extension) and repeating local notifications. The main app only edits Tasks and settings and re-registers schedules idempotently, checking `DeviceActivityCenter().activities` rather than a saved "already registered" flag. v1/v2 recomputed state on app launch and foreground, so shields and reminders silently stopped whenever the user didn't open the app, which is exactly the failure this app exists to prevent.

## Consequences

- "Never has to be opened" refers to the user. The system waking the app in the background (HealthKit background delivery, CoreLocation region events) is allowed.
- Anything that decides whether to shield must run inside the DeviceActivityMonitor extension's memory and time budget.
- Notification text can't depend on state computed at runtime ("3 tasks left"), because the app isn't there to update it.
