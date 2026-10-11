# Native Night Watch implementation

The Night Watch Flutter screens are implemented: camp and guild identity,
dispatch/focus/return, roster/equipment, forge, facilities, field log, manual,
settings/backups, contracts, Spire, and share preview. The native loop uses real
save data and the expedition resolver. Physical iPhone validation remains; see
the [device pass](device-validation.md). Native widgets/Live Activity now use the
Night Watch fonts and palette, and launch backgrounds use charcoal. Their source
wiring is checked locally; rendering and compilation still require the cloud build.

The prototype remains the interaction and appearance reference. Its example save, static clock, scripted find and provisional purpose multipliers are not production rules.

## 1. Foundation, camp and guild identity

This is the first implementation slice and should be reviewable in the real app before the remaining screens are migrated.

- Bundle IBM Plex Sans and IBM Plex Sans Condensed with their licenses, register them in `pubspec.yaml` and the license registry, and retain JetBrains Mono for numbers.
- Update the shared styling in `lib/theme/telos_theme.dart` with the Night Watch palette, readable type roles, neutral panels and brass actions. Audit shared components and existing secondary screens when changing these values; their current use of mono and display styles is not interchangeable.
- Add reusable bounded disclosure sections, summary rows, primary/secondary actions and equipment/identity sheets. One open disclosure should keep the relevant selection and constraints visible when closed.
- Rebuild `HomeScreen` around guild identity, the approved camp illustration, one useful next project, optional management details and obvious dispatch/repeat actions. Existing roster, forge, facilities, contracts, field log, settings/backup and conditional Spire access must remain reachable through management destinations. Collapsing the dashboard must not remove those capabilities.
- Reuse the existing rename/save operation, preserving player-selected casing.
- Add a stable guild sigil ID and default for old saves. Carry it through serialization and backup/restore, then expose the camp name/sigil editor. Keep guild emblems separate from sector and adventurer-class marks.
- Use the approved illustration as a guild mood image, not a literal portrait of the selected squad. The text and symbols must represent actual roster state.

Done when an existing save loads correctly, a name/sigil edit survives a restart and backup round trip, the camp is legible on a small phone, and dispatch/repeat and all existing management destinations remain usable.

## 2. Dispatch, focus and return with actual game state

- Port the preparation disclosures for intent, duration, destination and squad. Keep explicit summaries and visible validation. Preserve custom durations, class windows, squad limits, equipment effects and repeat dispatch behavior.
- Make the real consequences of destination and squad choices understandable using the existing engine. Do not copy the prototype's Extraction/Survey multipliers into production until they have a separately reviewed balance and content design.
- Preserve active-session routing, elapsed-time calculation, Integrity measurement, recall/cancel behavior, notifications, lock-screen integration and resume behavior. The quiet appearance must work around the existing lifecycle, not replace it with the static demo clock.
- Rework the debrief around the actual outcome. Rare loot may be the focal point when found; common/no-gear runs, early recalls, level changes and story discoveries need honest equivalents. Keep all earnings and journal content accessible, and preserve one-time reward banking.
- Keep the reveal finite and skippable. Update the README's visual/typographic and debrief-pacing sections explicitly as the accepted implementation changes those rules.

Done when one actual focus session and a repeat session complete the whole loop, using real data, without duplicated earnings, inaccessible outcomes or opportunities to manage the guild during a live expedition.

## 3. Complete and validate the launch experience

- Bring roster/equipment, forge, facilities, log, onboarding, settings and relevant system surfaces into the same visual language. Shared palette changes alone do not establish consistent hierarchy.
- Exercise small screens, long guild/member names, larger text, empty/new saves and established saves. Keep primary actions reachable and closed summaries useful.
- Run the repository's engine/economy, flow, backup, cancel, redeploy, notification/lock-screen and relevant contract checks. Add targeted coverage for guild identity persistence and the new disclosure/navigation behavior. Review golden changes deliberately.
- Validate on an iPhone: app backgrounding, screen lock, resuming, interruptions, local notifications and Integrity behavior. Desktop/browser previews cannot establish those behaviors.
- Review a real 25-minute experience alongside a longer run. Check that camp has an attainable goal for the short-session player and does not continually direct them toward a duration-gated destination.

The first useful checkpoint is an installable camp-and-identity slice. The milestone is the complete native loop. App Store submission or a new TestFlight release comes after implementation and validation; no release is part of this plan execution yet.

## Keep the gameplay work explicit

The interface overhaul improves clarity and identity. It does not by itself solve the fixed-25-minute player's long-term content ceiling. Maintain a separate gameplay workstream for reachable projects, local jobs, equipment decisions and recurring short-session opportunities. Use the native loop to assess which existing tradeoffs are already meaningful before adding more mechanics.

Candidate expedition purposes need authored goals, meaningful opportunity costs and balance checks across repeated short and longer sessions. Duration remains the player's constraint; Integrity remains the existing within-run honesty system. New IAP, cosmetic stores and guild affiliations are later work under the launch identity brief, not dependencies of this migration.

## References

- [Chosen direction](current-direction.md)
- [Night Watch interactive prototype](expedition-prototype/index.html)
- [Launch identity and later cosmetics](launch-identity.md)
- Root `README.md`, the authority for existing game behavior
- `lib/main.dart`: shared theme and root state routing
- `lib/theme/telos_theme.dart`, `lib/widgets/terminal.dart`: shared visual foundation
- `lib/screens/home_screen.dart`, `dispatch_screen.dart`, `session_screen.dart`, `debrief_screen.dart`: the native loop
- `lib/state/guild_controller.dart`, `lib/models/guild_state.dart`, `lib/services/backup.dart`: guild persistence and session outcomes

The first native slice is implemented: shared Night Watch tokens and bundled
fonts, illustrated camp, mutually exclusive disclosures, real selectable
facility projects, persistent guild names/sigils, and existing management and
dispatch/repeat paths. Migration defaults preserve older saves, and the signed
Spire Charter remains historical. The prototype's purpose multipliers and
scripted rewards were not copied into the game.

Native previews: [camp](../../test/goldens/home.png),
[guild identity](../../test/goldens/guild-identity.png), and
[small phone](../../test/goldens/home-small.png). These are Flutter test renders,
not device screenshots. Focused tests cover save/restart/backup, editor
cancel/save/validation, project selection, disclosure behavior, management
navigation, larger text with a keyboard, and the existing expedition loop.

The expedition slice adds three preparation disclosures, a shared resource
forecast, a quiet focus screen, and an outcome-led debrief with optional report
and reflection. Gear marks are drawn in code. The original balance, duration
gates, class windows, Integrity formula, and platform services remain.
Simultaneous dispatch/resolution calls are guarded, and externally started
runs close any open management routes.

Loop previews: [dispatch](../../test/goldens/dispatch.png),
[focus](../../test/goldens/session.png),
[gear return](../../test/goldens/debrief.png),
[ordinary haul](../../test/goldens/debrief-no-gear.png), and
[early recall on a small phone](../../test/goldens/debrief-recalled-small.png).

The management slice adds member-by-member field kits, a bounded vault, recipe
tiers, and facility/recruiting/sector-access disclosures. Only one section per
screen opens at a time. Existing costs, unlock gates, class windows, and resource
bonuses are preserved; reviews show costs and remaining balances before spending.
Equipment comparisons show both gains and losses for the selected slot. Swapping
the second slot now replaces that slot instead of evicting the first item, and
stale or missing-item assignments are rejected. Purchases guard repeated taps
while saving, melting still requires an explicit destructive action, and equipped
items remain protected. The camp project can be changed without spending.

Management previews: [roster](../../test/goldens/roster.png),
[member kit](../../test/goldens/member-kit.png),
[equipment comparison](../../test/goldens/equipment-compare.png),
[forge](../../test/goldens/forge.png),
[recipe review](../../test/goldens/recipe.png),
[facilities](../../test/goldens/facilities.png), and
[upgrade review](../../test/goldens/upgrade.png).

Validation on 2026-10-11:

- `flutter analyze`: no issues.
- `flutter test --run-skipped --exclude-tags golden`: 162 tests passed,
  including the economy instrument.
- `flutter test --run-skipped --update-goldens test/golden_test.dart`:
  all fifteen preview tests passed, producing 31 native renders. Archive,
  manual, settings/restore, contracts, Spire, and sharing were visually reviewed
  alongside the earlier camp and management previews. A fixed return time keeps
  the focus preview repeatable.
- `flutter build apk --debug`: succeeded. Local installable artifact:
  `build/app/outputs/flutter-apk/app-debug.apk`.
- The Android build reports upcoming support changes for the repository's
  existing Gradle, Android Gradle Plugin, and Kotlin versions. They did not
  block this build; toolchain migration is separate from the interface work.

New coverage checks forecast/resolver agreement, real destination tradeoffs,
concurrent dispatch and reward banking, all return states, saved reflection,
small screens and larger text, external-launch routing, and two complete
25-minute expedition cycles through the controller/UI using simulated elapsed
time. That last test is not a physical-device focus session.

Management coverage checks slot-specific replacement, ownership and restart,
comparison gains and losses, cancellation without spending, rapid purchase taps,
real crafting and melting, protected equipped gear, facility costs, roster versus squad capacity,
recruiting and sector gates, and 320-pixel screens with 1.6× text and long names.

The archive and support slice adds read-only full expedition records, a four-page
first-run manual (five in review), and settings with identity, save/restore, and
help disclosures. Backup reviews derive their comparison from the actual save,
reject unsupported format versions, and preserve a cancel path. File/export
failures appear with a retry path. Restores clear any in-progress session or
pending return while keeping already-banked history. Older records cannot name
equipment that has since been melted, so the report gives the missing count.

Contracts now reveal rewards one order at a time, the Spire pairs its contribution
with an optional charter, and a share preview explains which data leaves the app.
The exported card remains 1080 × 1350 and omits task and reflection text. The
preview controls respect text scaling; the fixed image composition has its own
type sizes.

Additional coverage checks read-only history, sub-minute recalls, onboarding
navigation/completion, export failure and repeated taps, restore cancellation and
save/restart, unsupported backups, contract payment exactly once, the historical
charter, and private share previews on 320-pixel screens with 1.6× text.

New previews: [field log](../../test/goldens/field-log.png),
[expedition record](../../test/goldens/expedition-record.png),
[manual](../../test/goldens/manual.png),
[settings](../../test/goldens/settings.png),
[restore review](../../test/goldens/backup-restore.png),
[contracts](../../test/goldens/contracts.png),
[Spire](../../test/goldens/spire.png), and
[share preview](../../test/goldens/share-preview.png).

Remaining milestone work is the [physical iPhone validation pass](device-validation.md),
including a real 25-minute session and a longer session with backgrounding, lock,
interruptions, and notification return. Native file handling and sharing also
need device checks; their widget tests use an in-memory adapter or preview only.
No TestFlight or store release has been made.

Codemagic preparation on 2026-10-11 preserves the existing automatic versioning
(latest TestFlight build 23) and signing workflow. Native font resource checks
verify SwiftUI's actual PostScript names, App Group consistency, and shared build
version variables. Backup sharing now supplies a screen-relative popover anchor,
and backup directory enumeration is asynchronous. The existing export test also
checks that the anchor has positive size and lies inside the visible screen.
See the [build handoff](codemagic-handoff.md), `tool/preflight.py`, and
[ready-to-paste tester notes](testflight-notes.txt).
