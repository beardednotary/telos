# Night Watch: physical iPhone pass

Status: **not run**. The Windows Flutter checks and Android debug build do not
validate iOS execution. The owner uses Codemagic to build and distribute through
TestFlight; the latest existing build is 23. Use the next signed candidate from
that workflow for this pass. See the [Codemagic handoff](codemagic-handoff.md).
No new TestFlight build has been produced by the local preparation.

Record the commit/build, iPhone model, iOS version, text size, notification
permission, and any enabled Focus mode. Keep an exported copy of an established
guild before testing replacement. Use a fresh save as well as an established
guild with equipment, contracts, and past expeditions.

## Two real focus sessions

| Case | Exercise | Expected result | Result |
|---|---|---|---|
| 25-minute session | Pick a reachable sector and a facility project, inspect the squad, dispatch, lock within the grace period, and work elsewhere until the scheduled end. | Clear setup, no need to check in, one completion alert if allowed, one debrief, one banked haul. Returning after the end does not lower Integrity. A reachable camp investment remains available to the short-session player. | Not run |
| Longer session | Choose an unlocked destination and a 45/60/90-minute duration that meets its minimum. Background and lock, intentionally reopen once mid-run, then leave it until after completion. | End time remains anchored to dispatch. The reopen costs 4 percentage points plus any billable foreground time; no extra penalty for time spent away. No management or loot is available mid-run. | Not run |

Capture the completed report and balances before/after. Relaunch after receiving
each report: earnings and XP must not be paid twice. Repeating a dispatch must
remain an explicit player action. These two runs assess the experience, not the
long-term balance of a player who always stays at 25 minutes.

## Lifecycle and native integration

| Case | Expected result | Result |
|---|---|---|
| First dispatch with notifications denied | The timer still starts and completes; the app does not repeatedly request permission. | Not run |
| Lock, incoming call, app switch, then resume | Timer uses the stored end time. Integrity follows Telos foreground time and reopens; it does not claim to observe other apps. | Not run |
| Terminate after backgrounding, reopen before/after the end | The same expedition resumes or resolves once. Its end time and record survive the restart. | Not run |
| Cancel during the first 30 seconds | Returns to camp without a log entry or rewards; completion alert is cancelled. | Not run |
| Recall after grace but before sector minimum | Confirmation explains scraps; time is recorded, credits only, no gear/alloy/intel. | Not run |
| Rapid dispatch or receive taps | One active expedition or one banked result. | Not run |
| Shortcut/quick action from camp or a management sheet | Opens the active session, closes management, and cannot start a second run while one is live. | Not run |
| Lock-screen activity and notification return | Correct destination/end time; no live loot. Cancel/recall/receipt clears the activity and pending alert. | Not run |

## Layout, identity, and files

- Check small and large text sizes, the keyboard, VoiceOver reading order, and
  Reduce Motion. Primary actions must remain reachable in dispatch, equipment,
  the manual, restore review, and share preview.
- Rename the guild and change its sigil. Relaunch, export, then restore the copy:
  identity and equipment must survive. A signed Spire Charter keeps its original
  guild name.
- Export to Files outside the app folder, copy that JSON back into Telos's folder,
  refresh the local list, and check the comparison. Cancel preserves the current
  guild; confirm replaces it. Corrupt files stay disabled. A saved live session
  or pending return does not reopen on restore.
- Preview and share an expedition image. Confirm the exported PNG is 1080 × 1350,
  shows the selected run's numbers, and contains no task or reflection text.
  Cancelling the native sheet should leave the app usable.
- Check light/dark device appearance, the launch transition, home-screen icon,
  widgets, and Live Activity alongside Night Watch. Widget/Live Activity colors
  and fonts and the launch backgrounds are now updated in native source; their
  rendered appearance needs this device check. The existing app icon is retained.

All items above remain unverified on a physical iPhone. Record failures with the
screen/route, reproduction steps, expected and actual behavior, and a screenshot
or device log. Automated evidence and native previews are in the
[implementation record](native-implementation-plan.md).
