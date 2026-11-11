# 013: Shield appearance and action

Status: done (device checks pending)
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

## Notes
- Kept v2's layout: the primary button "Lock In" closes the Shield, and the secondary "Earn access" posts a notification deep-linking to `lockin://bypass`. Closing should be the easy, prominent choice.
- Title: a random line from v2's set. Subtitle: a random v2 header plus up to three owed Required Tasks ("+N more").
- Colors live in `LockInCore.Palette`, shared by `DesignSystem` and the extension.
- `ShieldDecision.owedTasks` gives the Shield the same answer as enforcement.
- Notification taps route through `AppDelegate` and `DeepLinkRouter`. Until 015, both links land on Today.
