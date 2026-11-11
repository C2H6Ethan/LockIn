# 022: Cutover

Status: todo
Depends on: 001–021

## Scope
- Full device regression:
  - [ ] Re-run every device checklist in tickets 004–019.
  - [ ] Repeat 005's 3-day no-open test with all features enabled.
  - [ ] Repeat 014's v2-to-v3 upgrade test on a second device or a fresh install.
- Bump the version to 2.0.0 and build to 13. Upload to TestFlight and test with existing users.
- Merge `rewrite` into `main`.
- Delete the retired v2 plan (`../.claude/plan/lockin-app.md`) and archive notes.
- Open a follow-up to remove the v2 import and old keys one release later.
