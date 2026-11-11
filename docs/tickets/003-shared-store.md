# 003: Shared store

Status: todo
Depends on: 002

## Goal
One versioned persistence layer in the App Group that every target reads and writes the same way.

## Scope
- `LockInStore` protocol in `LockInCore`, with an in-memory implementation for tests.
- `AppGroupStore` (UserDefaults suite `group.com.ethanbaumgartner.lockin`) in `LockInPlatform`.
  - Call `synchronize()` after every write.
  - All keys are prefixed `v3.` so they never collide with v2 data (014 imports from the old keys).
  - Store `v3.schemaVersion`.
- Documents (Codable JSON):
  - tasks
  - completions `[DayKey: Set<TaskID>]`, pruned to the last 120 Days
  - settings
  - Blocklist (004)
  - day records (008)
  - event log (005)
- No getters with side effects. Reads are pure; writes are explicit.

## Acceptance criteria
- A round trip of every document through `AppGroupStore` is lossless.
- An unknown or corrupt document decodes to an empty default and is logged. It never crashes.

## Tests first
- Round-trip tests against the in-memory store and against a throwaway UserDefaults suite.
- Corrupt JSON returns the default.
- Pruning keeps exactly 120 Days.
