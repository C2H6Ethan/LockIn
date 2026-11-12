# 027: Remove the v2 import

Status: todo
Depends on: 2.0.0 live on the App Store for one release (do this in the release after 2.0.0, not sooner).

## Goal
Once users have moved to 2.0.0, the one-time v2 import is dead code. Remove it, and the old v2 data it reads.

## Scope
- Delete `LockInCore/Import/V2Import.swift` and `LockInPlatform/V2Migration.swift`, and their tests (`V2ImportTests.swift`, `LockInTests/V2MigrationTests.swift`).
- Remove the `runIfNeededInAppGroup` calls in `AppEnvironment.live()` and `DeviceActivityMonitorExtension`.
- On launch, delete the unprefixed v2 keys from the App Group once: `tasks`, `completionLog`, `streakData`, `selectedApps`, `selectedWebDomains`, `reminderNever`, `reminderHour`, `reminderMinute`, `hasCompletedOnboarding`, plus the import marker. Only touch keys without the `v3.` prefix.
- Clear v2's ManagedSettings store if v2 used a named one, so no v2 shield can linger.

## Trade-off
Someone who skips 2.0.0 and installs the next release straight over v2 starts fresh: no tasks, streak or Blocklist. Check App Store Connect's version adoption before starting; if a meaningful share is still on 1.x, wait another release.

## Tests first
- Core: nothing imports v2 types (the build is the test).
- App: on a store seeded with v2 keys and `v3.` keys, the cleanup removes exactly the v2 keys and leaves every `v3.` key.
