# Rewrite tickets

The v3 rewrite of LockIn, one vertical slice per ticket. Work happens on the `rewrite` branch, and each ticket leaves the app building and shippable.

**Before starting a ticket:** read `GLOSSARY.md` and `docs/adr/`. Use glossary terms in code (types, functions, copy) exactly.
**While working:** write the tests listed under "Tests first" before the implementation.
**When done:** set `Status: done` in the ticket and in the table below.

| # | Ticket | Status |
|---|---|---|
| 001 | [Scaffold the rewrite](001-scaffold.md) | done |
| 002 | [Core rules: Task, Due, Today, Shield decision](002-core-rules.md) | done |
| 003 | [Shared store](003-shared-store.md) | done |
| 004 | [Blocklist and shield adapter](004-blocklist-and-shield-adapter.md) | done |
| 005 | [Background enforcement](005-background-enforcement.md) | done |
| 006 | [Today screen](006-today-screen.md) | done |
| 007 | [Task form](007-task-form.md) | done |
| 008 | [Day records and Streak](008-day-records-and-streak.md) | done |
| 009 | [Missed-Day Recap](009-missed-day-recap.md) | done |
| 010 | [Reminder](010-reminder.md) | done |
| 011 | [Settings](011-settings.md) | done |
| 012 | [Onboarding](012-onboarding.md) | done |
| 013 | [Shield appearance and action](013-shield-appearance-and-action.md) | done |
| 014 | [Import v2 data](014-import-v2-data.md) | done |
| 015 | [Bypass](015-bypass.md) | done |
| 016 | [Step-Goal Tasks](016-step-goal-tasks.md) | done |
| 017 | [Location Tasks](017-location-tasks.md) | done |
| 018 | [Streak Freeze](018-streak-freeze.md) | done |
| 019 | [Lock Mode](019-lock-mode.md) | done |
| 020 | [Widget](020-widget.md) | done |
| 021 | [Review prompt and launch screen](021-review-prompt-and-launch-screen.md) | done |
| 022 | [Cutover](022-cutover.md) | done |
| 023 | [UX restructure](023-ux-restructure.md) (lands before 022's TestFlight step) | done |
| 024 | [Copy review](024-copy-review.md) | done |
| 025 | [Focus and input feedback](025-focus-and-input-feedback.md) | done |
| 026 | App Store listing: moved to the private marketing repo (`../marketing`, ticket M001); the app repo stays code-only | moved |
| 027 | [Remove the v2 import](027-remove-v2-import.md) (the release after 2.0.0) | todo |

v2 reference: the old implementation stays readable on `main` until 022. Read it for copy and behavior details, never copy its structure.
