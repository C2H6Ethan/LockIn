# 004: Blocklist and shield adapter

Status: todo
Depends on: 003

## Goal
The user picks a Blocklist, and one adapter applies or clears the Shield for **every** part of it. This is the class of bug that broke v2: its background code ignored categories.

## Terms
Blocklist, Shield

## Scope
- `Blocklist`: `FamilyActivitySelection` (apps, categories, web domains) plus up to 50 custom domains. Persisted via 003.
- `ShieldApplier` in `LockInPlatform`, using a named store `ManagedSettingsStore(named: .init("lockin.shield"))`.
  - `apply(blocklist)` sets `shield.applications`, `shield.applicationCategories` (`.specific`), `shield.webDomains`, `shield.webDomainCategories` (`.specific`) and `webContent.blockedByFilter` for the custom domains.
  - `clear()` resets all of them.
- Picker screen (`FamilyActivityPicker`) plus a custom-domain editor in the app, reachable from a temporary debug button. Settings (011) and Onboarding (012) reuse it.
- The app and all extensions use this one applier. No other code touches ManagedSettings.

## Acceptance criteria
- On device: a category-only Blocklist gets shielded and then cleared.
- On device: an app plus website Blocklist gets shielded and then cleared.

## Tests first
- A mapping test through a `ShieldSettings` protocol fake: every Blocklist field lands in its ManagedSettings counterpart, and `clear()` empties every field. This is the regression test for v2's category bug.
