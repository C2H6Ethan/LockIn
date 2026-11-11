# 006: Today screen

Status: done (device check pending)
Depends on: 005

## Goal
The main screen. Completing the last Required Task drops the Shield instantly.

## Terms
Today, Required Task, Optional Task, Shield

## Scope
- List the Required Tasks first (no header), then the Optional Tasks under an `OPTIONAL` section label. Each row shows a title, a completion marker, and the Start Time if it's in the future ("from 18:00").
- Tap to complete or uncomplete. Every change writes to the store, re-evaluates `ShieldDecision`, applies or clears the Shield, and (once 020 lands) reloads the widget.
- Empty state: "No tasks today." plus an "Add Task" call to action (opens 007).
- A Streak placeholder is wired in 008.
- Design: typography and whitespace only, tokens from `DesignSystem.swift`.
- Use a view model built on `@Observable`, with the store injected (no singletons).

## Acceptance criteria
- On device: completing the last due Required Task removes the Shield within a second.
- Uncompleting it brings the Shield back (if its Start Time has passed).

## Tests first
- View-model tests with the in-memory store and a fake `ShieldApplier`: completion toggles the store, and the shield is applied or cleared per `ShieldDecision`.

## Notes
- Debug builds accept a `-seed` launch argument that fills the store with sample Tasks (`LockIn/App/DebugSeed.swift`).
- Debug links (Screen Time permission, Blocklist, event log) live in a temporary toolbar menu until 011/012.
- Day rollover while the app is open is handled by `UIApplication.significantTimeChangeNotification`.
