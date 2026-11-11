# 021: Review prompt and launch screen

Status: todo
Depends on: 008

## Scope
- Request an App Store review the first time the Streak reaches 7. Store the flag in the **App Group** settings (v2 used standard defaults).
- Launch screen: `UILaunchScreen` with a `#0A0A0A` background, so there's no white flash.

## Tests first
- `shouldRequestReview(streak:, alreadyRequested:)`.
