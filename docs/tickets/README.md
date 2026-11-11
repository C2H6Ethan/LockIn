# Rewrite tickets

The v3 rewrite of LockIn, one vertical slice per ticket. Work happens on the `rewrite` branch, and each ticket leaves the app building and shippable.

**Before starting a ticket:** read `GLOSSARY.md` and `docs/adr/`. Use glossary terms in code (types, functions, copy) exactly.
**While working:** write the tests listed under "Tests first" before the implementation.
**When done:** set `Status: done` in the ticket and in the table below.

| # | Ticket | Status |
|---|---|---|
| 001 | [Scaffold the rewrite](001-scaffold.md) | done (device install pending) |
| 002 | [Core rules: Task, Due, Today, Shield decision](002-core-rules.md) | done |
| 003 | [Shared store](003-shared-store.md) | done |
| 004 | [Blocklist and shield adapter](004-blocklist-and-shield-adapter.md) | done (device checks pending) |
| 005 | [Background enforcement](005-background-enforcement.md) | done (device checks pending) |
| 006 | [Today screen](006-today-screen.md) | done (device check pending) |
| 007 | [Task form](007-task-form.md) | done |
| 008 | [Day records and Streak](008-day-records-and-streak.md) | done |
| 009 | [Missed-Day Recap](009-missed-day-recap.md) | done |
| 010 | [Reminder](010-reminder.md) | done (device spike pending) |
| 011 | [Settings](011-settings.md) | todo |
| 012 | [Onboarding](012-onboarding.md) | todo |
| 013 | [Shield appearance and action](013-shield-appearance-and-action.md) | todo |
| 014 | [Import v2 data](014-import-v2-data.md) | todo |
| 015 | [Bypass](015-bypass.md) | todo |
| 016 | [Step-Goal Tasks](016-step-goal-tasks.md) | todo |
| 017 | [Location Tasks](017-location-tasks.md) | todo |
| 018 | [Streak Freeze](018-streak-freeze.md) | todo |
| 019 | [Lock Mode](019-lock-mode.md) | todo |
| 020 | [Widget](020-widget.md) | todo |
| 021 | [Review prompt and launch screen](021-review-prompt-and-launch-screen.md) | todo |
| 022 | [Cutover](022-cutover.md) | todo |

v2 reference: the old implementation stays readable on `main` until 022. Read it for copy and behavior details, never copy its structure.
