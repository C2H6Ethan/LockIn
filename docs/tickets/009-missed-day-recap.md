# 009: Missed-Day Recap

Status: todo
Depends on: 008

## Goal
On the next open after one or more Missed Days, show a one-time recap so the user knows exactly what slipped.

## Terms
Missed Day, Missed-Day Recap, Streak

## Design (agreed)
- Full-screen cover with `.interactiveDismissDisabled(true)`. It is shown before Today and dismissed only by the bottom button.
- It counts as seen only on the button tap. If the app is killed mid-read, it shows again.
```
  Your 12-day Streak ended.

  You missed 3 days since Sat, Nov 8.

  YESTERDAY
  ○   Read 20 pages
  ○   Go for a walk

  SUNDAY, NOV 9
  ○   Morning workout

  SATURDAY, NOV 8
  ○   Read 20 pages
  ○   Stretch
  ○   Journal
      2 more
  ┌──────────────────────────────────┐
  │           Start today            │
  └──────────────────────────────────┘
```
- Copy:
  - Headline: "Your N-day Streak ended." If the previous Streak was 0, use "You missed yesterday." or "You missed N days." instead.
  - Subline: "You missed yesterday." or "You missed N days since {Weekday, Mon d}." Hidden when it would repeat the headline.
  - Day label: "YESTERDAY", otherwise "SUNDAY, NOV 9", with the year added when it differs from the current one.
  - Button: "Start today".
- Typography:
  - Headline: `.largeTitle` semibold.
  - Subline: `.body` in the secondary color.
  - Day labels: `.footnote` semibold, uppercased, tracking 0.6, secondary color.
  - Task titles: `.body` in the primary color, with a 14pt stroked circle marker in the secondary color in a 22pt column.
  - "N more": `.subheadline` medium in the accent color.
  - Button: accent fill with background-colored text.
- **No serif and no red.** It's a factual record, not a shame screen.
- Newest first. The 7 newest Days are shown in full; older ones collapse into "N earlier Missed Days", which expands in place. Each Day shows 5 Tasks, then "N more".
- Only Required Tasks are listed, using the snapshot titles from the DayRecord.
- Lookback capped at 60 Days. Beyond that, show "Earlier Missed Days not shown."
- Accessibility:
  - Dynamic Type everywhere; at accessibility sizes the whole screen scrolls.
  - Day labels are `.isHeader`.
  - The streak reads "Streak was 12, now 0."
  - One `.warning` haptic on appear.
- New tokens: `Typography.sectionLabel`, `Spacing.rowMarker = 22`.
- A slot is reserved for the Streak Freeze offer (018).

## Core contract
```swift
struct MissedDayRecap { missedDays: [MissedDay]; previousStreak: Int; streakBrokenOn: DayKey?; isTruncated: Bool }
struct MissedDay { day: DayKey; undoneRequiredTaskTitles: [String] }
func pendingMissedDayRecap() -> MissedDayRecap?
func acknowledgeMissedDayRecap(through: DayKey)
```

## Tests first
- No Missed Days since the last acknowledgement returns nil.
- Three Missed Days come back newest first with snapshot titles.
- `previousStreak` and `streakBrokenOn` are correct across a Kept Day between Missed Days.
- Acknowledging through Day X still surfaces a Day X+1 that ends later.
- 61 Missed Days sets `isTruncated`.
