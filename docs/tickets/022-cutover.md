# 022: Cutover

Status: done (2026-11-12)
Depends on: 001–021
Signed off: all device checks passed on the iPhone 13 Pro and approved by the user, 2026-11-12. 2.0.0 (13) is on TestFlight.

## Scope
- Full device regression:
  - [x] Re-run every device checklist in tickets 004–019.
  - [x] Repeat 005's 3-day no-open test with all features enabled.
  - [x] Repeat 014's v2-to-v3 upgrade test on a second device or a fresh install.
- Bump the version to 2.0.0 and build to 13. Upload to TestFlight and test with existing users.
- Merge `rewrite` into `main`.
- Retire the v2 plan: moved to `../.claude/archive/lockin-app-v2-plan.md`.
- Follow-up: [027](027-remove-v2-import.md) removes the v2 import one release later. The App Store listing and release moved to the private marketing repo (`../marketing`, ticket M001).

## Device checklist (all pending checks from 001–020, in the order to run them)

Setup: Xcode → run the `LockIn` scheme on your iPhone. Check outcomes in Settings → long-press the version label → event log.

**Session 1: upgrade path (do this first, before anything else touches the App Group)**
- [x] 014: With v2 (from `main`) installed and set up, install `rewrite` over it. Tasks, Blocklist and Streak are intact, and the Shield works without re-picking apps. v2's old shield must not linger: shields drop as soon as the Required Tasks are done.

**Session 2: one sitting, about 20 minutes**
- [x] 001: The app installs and launches. Onboarding (012) asks for Screen Time access and notifications.
- [x] 004: A category-only Blocklist gets shielded, then cleared. Same for an app plus a website.
- [x] 013: The Shield shows LockIn copy for an app, a category and a website. "Earn access" delivers a notification that opens the walk screen.
- [x] 006: Completing the last Required Task removes the Shield within a second.
- [x] 015: Walk 100 steps, and the Shield lifts. Force-quit; after 15 minutes the Shield is back and "Bypass over." arrives. A second Bypass costs 200 steps.
- [x] 017: Create a Location Task. The place picker search works, and tapping the map moves the pin. Tapping the Task away from the place says "Not at … yet today."
- [x] 020: Add the small and medium widgets. They match Today, and completing a Task updates them.
- [x] 005: Deleting the only Task with a given Start Time removes its activity (event log: "stopped start-…").

**Session 3: background, over several days, without opening the app**
- [x] 005: The Shield goes up at midnight and at a Start Time, with the app force-quit, on 3 consecutive days. Also after a reboot.
- [x] 010: With Tasks undone, the reminder arrives each day. With everything done, it doesn't.
- [x] 016: With the app force-quit, walking past a step goal completes the Task and drops the Shield. The lag can be long while the phone is locked.
- [x] 017: Visit the place with the app closed, then tap the Task later the same Day, and it completes.

**Steps (from the step-counting research)**
- [x] Walk screen: shaking by hand for 30 s and a drill or other vibration count little or nothing. Swinging the phone at walking pace may count; that's accepted.
- [x] Walk screen: walk 100 steps. Note how fast the first update and the finish come. Walk with the screen locked and the phone in a pocket, then unlock: the count jumps to the full total. Try a bag and a stroller too.
- [x] With Motion & Fitness turned off in Settings, the walk screen says to allow it.
- [x] Step-Goal Task with Low Power Mode on, or Background App Refresh off: note whether it still completes in the background. It must complete when LockIn is opened.
- [x] With an Apple Watch and the phone left on a desk: today's total doesn't double, and the Task completes once the Watch syncs.

If the 010 check fails (no reminder from the extension), use the fallback described in ticket 010.
