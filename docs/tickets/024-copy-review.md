# 024: Copy review

Status: done (device read-through pending)

## Goal
Every line of on-screen text says plainly what happens, in the user's words. Found on device: "Your Blocklist stays blocked until it's done." The list itself isn't blocked; the apps on it are.

## Terms
Blocklist (the list, never "blocked" itself), How it's done (was "Completes by"), Tick off (was "Tapping"), Start Time, Required Task, Optional Task.

## Scope
| Where | Before | After |
|---|---|---|
| Task form, Required on | Your Blocklist stays blocked until it's done. | The apps on your Blocklist stay blocked until this is done. |
| Task form, Required off | Tracked, but never blocks anything. | Shows on Today, but never blocks anything. |
| Task form, section | Completes by: Tapping / Steps / Place | How it's done: Tick off / Steps / Place |
| Task form, Tick off | Tick it off on Today when it's done. | You tick it off yourself on Today. |
| Task form, Steps | Done by itself once Apple Health counts this many steps today. If it doesn't count: … | Ticks itself off when you've walked this many steps today. (Second line:) Steps not counting? In the Health app, tap your profile, then Apps → Lock In, and turn on Steps. |
| Task form, Place | You can tick it off once you've been there today. | You can only tick it off after you've been there today. |
| Task form, Start time off | Blocks from midnight until done. | Your apps are blocked all day until this is done. Turn on to start blocking later. |
| Task form, Start time on | Blocks from 18:00 until done. | Your apps are blocked from 18:00 until this is done. |
| Today and Tasks subtitles | from 18:00 | blocks from 18:00 |
| Today, empty state | Add a task. Until your required tasks are done, your Blocklist stays blocked. | Add a task. Each day, the apps on your Blocklist stay blocked until your required tasks are done. |
| Onboarding, first task | … Until your required tasks are done, your Blocklist stays blocked. | Something you'll do every day. The apps on your Blocklist stay blocked until it's done. |
| Settings, Lock Mode on | Only stricter changes until then. | Until then, you can only make Lock In stricter. |
| Lock Mode sheet | Turning off Screen Time access in iOS Settings can't be prevented. | Lock In can't stop you from turning off Screen Time access in iOS Settings. |
| Place picker | Counts within 150 m. | You need to be within 150 m of the pin. |
| VoiceOver, Step-Goal row | Completes at your step goal | Ticks itself off at your step goal |

Reviewed and kept: the blocking status lines, Bypass screen, Missed-Day Recap, Lock Mode violations, form errors, Settings rows, reminders, Shield copy, widget.

## Tests first
- Subtitle tests expect "blocks from 18:00" (Today, Step-Goal, Tasks).
- Core `CompletesBy` tests use `.tickOff`.

## Device check
- [ ] Read every screen on the phone once more (onboarding, Today, Tasks, the form in all three "How it's done" choices, Settings, Lock Mode, Bypass, Recap, Shield) and note any line that still needs a second read.
