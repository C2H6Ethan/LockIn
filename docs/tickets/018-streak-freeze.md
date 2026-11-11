# 018: Streak Freeze

Status: todo
Depends on: 009

## Goal
Save a Streak across exactly one Missed Day, from inside the recap.

## Terms
Streak Freeze, Missed-Day Recap, Kept Day

## Scope
- One Streak Freeze per ISO week (Monday start). It doesn't accumulate.
- The offer appears in the Missed-Day Recap only when exactly one Missed Day breaks the run, a Freeze is available, and the previous Streak is greater than 0.
- Button: "Use Streak Freeze to keep your N-day Streak" (accent color), placed above "Start today".
- Using it sets that DayRecord's outcome to `.frozen`, which counts as Kept. The Streak then continues, so after a frozen yesterday, today kept makes N + 2. The recap dismisses.
- There is no separate sheet, unlike v2.

## Tests first
- Offer eligibility: 1 Missed Day versus 2, Freeze used this week, and a previous Streak of 0.
- The Streak after freezing.
- The weekly reset happens at the ISO week boundary.
