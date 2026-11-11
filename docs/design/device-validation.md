# Night Watch: physical iPhone pass

Status: **not run**. The Windows Flutter checks and Android debug build do not
validate iOS execution. The owner uses Codemagic to build and distribute through
TestFlight. Build 33 (October 28) carries the audit's reliability fixes; build 34
(PR #12) is the submission candidate and the build to run this pass on. See the
[Codemagic handoff](codemagic-handoff.md).

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
| Cancel during the first 30 seconds | Returns to camp without a log entry or rewards; completion alert is cancelled. The next feedback draft's usage line counts it as cancelled. | Not run |
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

## Added in build 34

| Case | Expected result | Result |
|---|---|---|
| Restore a backup over an established guild | The review says a copy is kept first. After confirming, the notice says the replaced guild is in Local backups, and a `telos-before-restore-*.json` file is in On My iPhone › Telos. | Not run |
| Restore that kept copy | The original guild returns exactly: name, sigil, balances, roster, gear, log. Its own replacement is kept as a second copy. | Not run |
| Restore over a guild with no expeditions | No copy is kept, and the review doesn't promise one. | Not run |
| Pick a hand-edited backup naming gear that doesn't exist | Shown as not a Telos backup or unreadable; the current guild is unchanged. | Not run |
| Accept a suggested plan, then change the squad | The plan sentence above the squad disappears. | Not run |
| Third full expedition, with the music offer already answered | The feedback card appears at camp once. "No thanks" removes it for good, across relaunches. | Not run |
| "Write an email" on that card | Mail opens a draft to telos@dahvio.com with the three questions, the build and iOS version, and a usage line of counts only. With no mail account, the address is copied and a notice says so. | Not run |

## Added for iPad

On an iPad, or a phone on its side, the phone layout sits in a centred
640-point column with darker margins (`lib/widgets/wide_layout.dart`).
Check on an iPad, or the iPad simulator if there is no device.

| Case | Expected result | Result |
|---|---|---|
| Camp, dispatch, a run and its report, portrait | One centred column; nothing stretches to the edges. The camp and sector illustrations show the whole scene, heads included. | Not run |
| Rotate to landscape and back, mid-run and at camp | The column stays centred; the timer and its end time are unaffected. | Not run |
| Split View and Slide Over at each width | Narrow panes use the full pane, as on a phone; wide ones show the column. | Not run |
| Bottom sheets and dialogs (duration picker, project choice, guild identity, recall) | They open inside the column, not across the whole screen. | Not run |
| Keyboard while naming the guild or writing an intention | The field stays above the keyboard. | Not run |
| Share an expedition card from the report | The share sheet points at the share control. | Not run |

All items above remain unverified on a physical iPhone. Record failures with the
screen/route, reproduction steps, expected and actual behavior, and a screenshot
or device log. Automated evidence and native previews are in the
[implementation record](native-implementation-plan.md).
