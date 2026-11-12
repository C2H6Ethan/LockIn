# 026: App Store listing

Status: todo

Depends on: 023, 024 (the screens and copy being shown are final). Lands before 022's App Store release step.

## Goal
A professional store page for 2.0.0. **The main work is new screenshots**: designed marketing images (a caption, a device frame, a background in the app's style), not bare screen captures. The text is a quick side check.

## 1. Screenshots (main task)

### What
- The first 3 decide the download, because they show in search results. Order and captions come from `docs/research/promotion.md` §5.3:
  1. "Your apps stay blocked until you do the thing": the system block screen in front of a blocked app.
  2. "Walk it off": a Step-Goal Task completing.
  3. "Show up": a Location Task completing.
  4. Then: Lock Mode, Streak with Streak Freeze, the widget, and "Free. No account. Nothing leaves your phone."
- **One claim per image**, a short caption that's readable at thumbnail size, in glossary terms (Blocklist, Bypass, Lock Mode, Streak Freeze).
- **Style:** the app's own look. Background `#0A0A0A`, text `#F5F5F0`, accent `#E8D5A3`, and SF Pro (the serif only if a shame line is quoted). A realistic device frame, with the screen slightly large in the frame. Images may run across into each other for a continuous strip, but each has to read on its own too.
- The last version used a Figma template. Reuse its layout ideas if it's still around, but don't depend on it.

### Sizes App Store Connect requires
- **iPhone 6.9"**: 1320 × 2868 portrait (other iPhone sizes are scaled from it).
- **iPad 13"**: 2064 × 2752. Needed because the app targets iPad (`TARGETED_DEVICE_FAMILY = 1,2`). **Decide first:** make iPad screenshots, or drop iPad support (iPhone-only apps still run on iPad in compatibility mode)?

### How (find the best way; Figma is a fallback only)
The Figma MCP has a monthly call limit that has probably been used up, so the pipeline must not rely on it. Recommended, to be confirmed while doing it:
1. **Capture the screens** on the simulator using the debug launch arguments (`-seed`, `-openEdit`, `-openBypass`, …, see `LockIn/App/DebugLaunch.swift`).
   - Clean status bar: `xcrun simctl status_bar <id> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`.
   - Add seeds for any state that's missing (a Step-Goal Task at 80 %, a completed Location Task, a 30-day streak).
   - **The system block screen can't be shown on the simulator** (no Screen Time). Take that capture on the iPhone.
2. **Compose the images in code**: an HTML/CSS template per image (caption, background, device frame with the capture inside), rendered to exact-size PNGs by headless Chrome or Playwright. It's repeatable, reviewable in git, and re-renders in seconds when a screen or caption changes.
   - Device frames: Apple's official product bezels (developer.apple.com/design/resources), which may be used in marketing images.
   - Alternatives to weigh: a SwiftUI renderer (`ImageRenderer`) in a small script target, or a paid tool (e.g. a screenshot generator site). Choose by result quality and how easy re-rendering is.
3. Keep the sources (templates, captures, render script) in `store/` at the repo root, and the output PNGs in `store/output/` (or gitignored if they're large).
4. Upload through the App Store Connect API (key on this Mac, see 022) or by hand.

### Tests first
- The render script fails on any image that isn't the exact required pixel size.
- A checklist read at thumbnail size (about 230 px wide): each caption is readable, and the claim is clear without the screen.

## 2. Store text (quick check)
- `../appstore-description.txt` is v2 copy and says things v3 contradicts or the review found wrong: "physically locks", "No workarounds" (Screen Time access can be turned off in iOS Settings), "Widgets: small and medium", "one recovery per week". It's missing Location Tasks. Rewrite it in glossary terms.
- Title, subtitle, keywords and promotional text: use the checked proposals in `promotion.md` §5.2 (title `Lock In: Block Apps Until Done`, 30 characters).
- What's New for 2.0.0: a short note for v2 users that their tasks, streak and Blocklist carry over.
- The privacy answers ("Data Not Collected") still hold. Check that HealthKit and location use is described correctly.

## Done when
- [ ] The iPhone set (and iPad set, or iPad support dropped) is rendered at the exact sizes and uploaded.
- [ ] The description, title, subtitle, keywords, promotional text and What's New are updated in App Store Connect.
- [ ] Looked at on a real App Store search result (TestFlight page or after release) and the first 3 read well.
