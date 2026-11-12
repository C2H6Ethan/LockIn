# 001: Scaffold the rewrite

Status: done
Depends on: none

## Goal
An empty but correctly wired project: one package that every target links, no v2 code left on the branch, and everything builds.

## Scope
- Create branch `rewrite` from `main`.
- Delete all v2 Swift sources from `LockIn/`, `DeviceActivityMonitor/`, `ShieldConfiguration/`, `ShieldAction/`, `LockInWidget/` and all of `LockInTests/`.
- Keep the targets, bundle IDs, Info.plists, entitlements, asset catalogs and App Group (`group.com.ethanbaumgartner.lockin`).
- Remove the pbxproj file-membership exceptions that shared sources between targets.
- Add a local Swift package at `Packages/LockIn/` with two libraries:
  - `LockInCore`: pure rules. Foundation only (ADR 0002).
  - `LockInPlatform`: thin adapters over Apple frameworks (ManagedSettings, DeviceActivity, UserNotifications, FamilyControls). It holds no rules and depends on `LockInCore`.
  - Test target `LockInCoreTests`, written with Swift Testing.
- Link both libraries into all five targets. The widget links `LockInCore` only.
- Swift 6 language mode everywhere. Deployment target iOS 17.
- `DesignSystem.swift` in the app with the tokens from `CLAUDE.md`.
- The app shows a placeholder screen. Each extension has a stub principal class that compiles.

## Acceptance criteria
- `xcodebuild` builds all targets for a device with zero warnings.
- `swift test` in `Packages/LockIn` runs (a single placeholder test is fine).
- The app installs and launches on a real device.
- `git grep -n "SharedStore\|habit"` finds nothing in sources.

## Tests first
- A placeholder `#expect(true)` that proves the test pipeline runs.
