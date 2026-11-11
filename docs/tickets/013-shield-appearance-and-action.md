# 013: Shield appearance and action

Status: todo
Depends on: 005

## Goal
The system Shield looks like LockIn, and its button leads into the app.

## Scope
- ShieldConfiguration extension:
  - Background color, title and subtitle from design tokens, using Apple's template only (never custom UI; see `CLAUDE.md`).
  - Copy names the number of Required Tasks left, if cheap to compute from the store.
- ShieldAction extension:
  - Primary button "Earn access" posts a notification deep-linking `lockin://bypass`. Until 015 lands, the link opens Today.
  - Secondary button: close.
- Deep-link routing in the app.

## Acceptance criteria (device)
- [ ] The Shield shows LockIn branding for apps, categories and websites.
- [ ] Tapping "Earn access" delivers a notification that opens the app.

## Tests first
- Deep-link parser tests.
