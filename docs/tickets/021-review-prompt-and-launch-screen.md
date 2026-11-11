# 021: Review prompt and launch screen

Status: done
Depends on: 008

## Scope
- Request an App Store review the first time the Streak reaches 7. Store the flag in the **App Group** settings (v2 used standard defaults).
- Launch screen: `UILaunchScreen` with a `#0A0A0A` background, so there's no white flash.

## Tests first
- `shouldRequestReview(streak:, alreadyRequested:)`.

## Notes
- `ReviewPrompt.shouldRequest` (core) and `Settings.hasRequestedReview` (App Group).
- Today asks via `requestReview` on `.onChange(of: streak, initial: true)`, so it fires when a completion or the midnight rollover first makes the Streak 7 or more. `TodayModel.consumeReviewRequest()` sets the flag, so it fires only once.
- The launch screen was already right: `UILaunchScreen` uses the `LaunchBackground` color (#0A0A0A) and `LaunchLogo`, kept from v2. No change needed.
