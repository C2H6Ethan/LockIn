# LockIn — Claude Instructions

## Project

An iOS app that keeps distracting apps and websites shielded each day until the user's Required Tasks are done. Minimalist design.

LockIn v3 (2.0.0) lives on `main`; the rewrite branch was merged in ticket 022. v2 is in git history before that merge.

## Before starting any session

1. Read `GLOSSARY.md`. Use its terms exactly in code, copy and conversation, and never the words it lists under _Avoid_.
2. Read `docs/adr/`.
3. Open `docs/tickets/README.md` and find the next `todo` ticket whose dependencies are done.
4. Confirm the ticket with the user before writing code. Work on one ticket at a time.
5. Write the ticket's "Tests first" before the implementation.
6. When it's done, set `Status: done` in the ticket and in the README table.

If a decision changes the domain language, update `GLOSSARY.md`. If it's hard to reverse, surprising, and the result of a real trade-off, add an ADR.

## Architectural rules

- **The user never has to open the app for daily enforcement** (ADR 0001). Shields, the day rollover and reminders are driven by repeating DeviceActivity schedules handled in the DeviceActivityMonitor extension.
  - `ScheduleRegistrar` re-syncs schedules idempotently against `DeviceActivityCenter().activities`.
  - Never use an "already registered" flag.
- **All rules live in `LockInCore`** (ADR 0002). It is a framework-free Swift package library linked by every target.
  - Apple-framework adapters live in `LockInPlatform` and hold no rules.
  - Extensions and views contain no business logic.
- **One `ShieldApplier`** is the only code that touches ManagedSettings. It must map every Blocklist field: apps, categories, web domains and custom domains.
- **All cross-target data goes through the App Group** `group.com.ethanbaumgartner.lockin` via `UserDefaults(suiteName:)`, with keys prefixed `v3.`.
  - Call `synchronize()` after every write.
  - No other IPC.
- **Never write custom UI inside shield extensions.** The system shield is Apple's template. Anything interactive lives in the main app, opened via a `lockin://` deep link.
- **No singletons.** Inject the store and adapters.

## Stack

- Swift 6 language mode, SwiftUI, iOS 17+.
- Swift Testing for `LockInCore` tests.
- Frameworks: `FamilyControls`, `DeviceActivity`, `ManagedSettings`, `HealthKit`, `CoreLocation`, `CoreMotion`, `WidgetKit`.
- Storage: App Group `UserDefaults` with Codable JSON documents. No CoreData or SwiftData.
- Five targets: the main app, the DeviceActivityMonitor, ShieldConfiguration and ShieldAction extensions, and the widget.

## Design

- Colors: background `#0A0A0A`, text `#F5F5F0`, secondary `#8A8A8A`, accent `#E8D5A3`.
- SF Pro. The `.serif` design variant is for shame messages only.
- No cards and no borders: typography and whitespace only.
- All constants live in `DesignSystem.swift`.
