Telos deployment and product audit — October 27, 2026

**Verdict: close to a public release, but I would not deploy this exact revision yet.** The core product is coherent and the ordinary flows are well tested. The remaining work is reliability, release packaging, and feedback collection. A redesign, accounts, app blocking, or a subscription is not necessary to launch.

Audited commit: `627ebc7`, repository version `0.1.0+19`. The repository was clean at the start. This is an audit of source and local Flutter behavior, not a certification of the installed TestFlight binary. The owner subsequently confirmed that build **32** is latest and supplied a TestFlight screenshot showing six installed testers, four on build 32. The correspondence between that binary and this commit remains unverified. Codemagic settings, store metadata, and detailed crash reports were not inspected. Existing handoff documents referring to build 23 are stale.

**Evidence and limits**

| Check | Result |
|---|---|
| Flutter 3.47.5 / Dart 3.13.4, `flutter analyze --no-pub` | No issues found |
| `python tool/verify_ios.py` | Passed source wiring checks |
| `flutter test --no-pub --run-skipped --exclude-tags golden --reporter expanded` | 247 passed: 241 existing tests plus six audit probes temporarily placed under `test/` |
| Six focused audit probes | All confirmed the observed failure cases; retained separately in `2026-10-27-probes_test.dart` |
| `flutter test --no-pub --run-skipped test/golden_test.dart --reporter expanded` | All 15 visual preview tests passed against the existing images |
| Visual inspection | Reviewed camp, planning, countdown, and debrief images |
| Signed iOS build, physical iPhone/iPad, VoiceOver, notifications under Focus, native sharing | Not performed in this Windows audit |

The suite emitted a missed-tap warning in the small-screen planning test (`test/expedition_loop_test.dart:271`). The test still passes, so that interaction is not fully proved by its green result. Existing small-screen tests at increased text size are useful, but physical accessibility validation remains necessary. The iOS preflight checks structure and resources; it does not compile Swift, verify privacy manifests, or exercise platform APIs.

**Fix before public release**

1. **P1 — A bad save is silently discarded and then overwritten.** `lib/services/persistence.dart:17` catches every decoding error and returns a new guild. `GuildController.boot()` then calls `_noteOpen()` (`lib/state/guild_controller.dart:79`), which immediately saves it. The probe seeded a corrupt JSON save and confirmed that boot replaced the original value. One malformed field or a future incompatible migration can therefore become permanent progress loss without a recovery choice. Preserve the original bytes, validate and migrate the schema, keep a last-known-good copy, and present recovery instead of silently resetting. Check write outcomes and surface persistence failures. For the primary game save, prefer an atomic file or transactional store with a recoverable prior generation. The SharedPreferences maintainers explicitly caution against relying on it for critical data because return from a write does not guarantee disk persistence. [Package documentation](https://pub.dev/packages/shared_preferences/versions/2.5.5)

2. **P1 — Notification failures can break the core session flow.** `_startRun()` creates the active run and starts its ticker before awaiting notification scheduling, and saves only afterward (`lib/state/guild_controller.dart:328`). A simulated scheduling exception left `hasActiveRun == true` with no saved run; retrying did nothing because an active run already existed. The dispatch error text nevertheless says the squad is still at camp (`lib/screens/dispatch_screen.dart:118`). Two other probes confirmed that an initialization failure leaves `ready == false`, and a cancellation failure prevents a completed run from being banked (`lib/state/guild_controller.dart:417`). These are injected failures, not evidence that testers have experienced them. Treat notifications as recoverable side effects: durably commit valid timer/reward state, then schedule or cancel alerts with error handling and retry. A denied permission is a separate, ordinary state. Add regression coverage for platform exceptions and failed persistence, including relaunch after each boundary.

3. **P1 — Finish the privacy and support release surface.** Settings has a short privacy explanation but no privacy-policy link or feedback/contact action (`lib/screens/backup_screen.dart:255`). Apple requires an accessible privacy-policy link inside the app and in App Store Connect even for an offline app. Add a hosted policy covering local notes, guild data, optional export/sharing, backup retention/deletion, and any future diagnostics. Verify the store privacy answers against the actual bundled SDKs. Confirm that a real support URL exists in App Store Connect; its current value was not accessible here. [App Review Guidelines, 5.1.1](https://developer.apple.com/app-store/review/guidelines/), [Support URL requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)

4. **P1 release verification — No app-owned privacy manifest is present in the iOS source.** `ios/Shared/WidgetStore.swift:36` directly uses App Group `UserDefaults`, and the shared source is compiled into the app and widget. Neither target has a `PrivacyInfo.xcprivacy` resource in the checked-in project. Apple's documentation requires declaring required-reason APIs used by your own code; the reason for same-App-Group defaults is `1C8F.1`. Add the appropriate target resources and inspect the exported archive's privacy report. Dependency manifests alone do not document this custom native call. A cloud build could inject resources, so this is a confirmed source omission and an artifact check, not a claim that the existing TestFlight build was rejected. [Required-reason API declarations](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [UserDefaults reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

5. **P2 — The 500-run history limit can erase earned Spire progress.** The controller trims history (`lib/state/guild_controller.dart:483`), while total focus minutes and Spire floors are calculated from that history (`lib/models/guild_state.dart:205`, `:235`). In the probe, 500 runs totaling 12,500 minutes yielded one earned floor. Finishing another 10-minute run removed an older 25-minute record: the total fell to 12,485 and the floor count fell from one to zero. Equal-duration sessions eventually stop adding floors altogether. Store lifetime counters independently of retained detail records, migrate existing saves, and ensure counters never decrease when history is trimmed. The log already labels its limited history; the permanent Spire promise still needs a separate counter. At four sessions a day, the cap is reached in about 125 active days.

6. **P2 — Backup validation accepts references that can crash after restore.** `Backup.decode()` checks the envelope/version and that the roster is nonempty, but does not validate content identifiers (`lib/services/backup.dart:67`). A backup containing unknown equipped gear was accepted; resolving that gear subsequently threw. Validate class/sector/gear IDs, ownership, unique IDs, reasonable numeric ranges, and required roster state before allowing replacement. Preserve the previous save automatically until the restored guild has loaded successfully. This is a local data-integrity defect, not evidence of a remote compromise.

7. **P2 — Five minutes is offered but cannot be started.** The custom-duration slider allows five minutes (`lib/screens/dispatch_screen.dart:162`). The shortest destination requires ten (`lib/data/content.dart:85`), so the app disables dispatch with “No destination fits.” Prefer a useful five-minute focus option with an appropriately modest outcome, or make the picker start at the actual minimum. This is an ordinary visible mismatch and is worth fixing before launch.

8. **P3 — Suggested-plan text can become stale.** `_usePlan()` stores a sentence naming the squad and the forecast benefit. Changing squad membership does not clear/recalculate that sentence (`lib/screens/dispatch_screen.dart:551`). The existing dispatch preview shows a recommendation naming KAEL and MIRA while only MIRA is selected. Clear the recommendation on manual edits or derive it from the current plan, including equipment changes.

If Android is also in scope, its release build currently uses the debug signing configuration (`android/app/build.gradle.kts:41`). Configure production signing before Play distribution. This is separate from the iOS/TestFlight decision.

**What is already working well**

The brass/charcoal design, illustrations, and typography form a recognizable product. Camp has a clear primary action and a concrete next upgrade. Setup defaults, repeat dispatch, automatic equipment assignment into empty slots, and optional details reduce decision overhead. The quiet timer supports the promise of putting the phone down. Debrief reveals make returning meaningful without demanding attention mid-session. Reduced-motion handling, semantic timer text, larger-text tests, guarded duplicate operations, backup review, and share cards that omit task/reflection text are good foundations.

Keep the free experience complete: unlimited timers, all useful durations, existing progression, history, backup/export, and native completion alerts. Preserve the absence of ads, purchased currency, XP boosts, streak repair, paid timer slots, and attention-seeking mid-session prompts.

**What the TestFlight sessions tell us**

The owner's screenshot confirms that “sessions” refers to TestFlight's usage metric. It does not establish that someone completed a 25-minute focus timer. Repeated use is encouraging but is not yet proof of retention, satisfaction, or timer completion. With this app, one focus block can also involve starting, returning, and checking a report. No written feedback is ambiguous. [Apple's tester metric definitions](https://developer.apple.com/help/app-store-connect/reference/testflight/testflight-tester-information/)

| Installed build shown | Testers | Session counts displayed |
|---|---:|---|
| 32 (latest, per owner) | 4 | 19, 5, 3, and a dash |
| 28 | 1 | 3 |
| 18 | 1 | A dash |

All six are anonymous public-link testers. Crash and feedback cells display dashes throughout. Treat dashes as no count displayed, not as proof of zero activity or crash-free operation. The screenshot does not establish the session reporting window or whether those counts are limited to each tester's currently installed build. Installation/update dates are not a daily return history. Three of the four testers currently on build 32 show repeated use; that is a reason to continue the beta, not enough evidence for a retention rate or willingness to pay. Because these testers are anonymous, an in-app feedback invitation is more practical than assuming they can be contacted by email. At this scale, add that feedback path and a voluntary summary before committing to a full analytics service.

The app records install time, cold app opens, distinct open days, onboarding timestamps, and expedition history locally. Nothing currently sends that bookkeeping to you. `appOpens` counts boot calls, not every foreground resume. `daysActive` counts distinct days opened, not a D7 retention percentage. Backups include task intentions and reflections, so asking everyone for their entire save would collect more personal material than needed.

The lowest-complexity next step is a user-controlled **Share diagnostics** action with a preview. Include build/OS, days since install, days used, completed/cancelled/recalled session counts, duration buckets, and notification permission status; omit task notes, reflections, guild/member names, exact activity times, and raw saves. Some proposed counters do not exist yet: cancellations currently leave no record, for example. Add a permanent **Send feedback** link in Settings and one dismissible invitation after the third completed expedition, shown at camp.

Use three concrete questions, rather than “Any feedback?”:

- “Did Telos help you start a piece of work you otherwise would have delayed?”
- “What was confusing or irritating during your last session?”
- “What made you come back—or what stopped you?”

For the next cohort, record denominators and build: installed → first completed focus → third completed focus → another completed focus on a later day. Use both a seven-day return window and distinct focus days, since work patterns vary. Do not optimize time spent inside this particular app. Five to ten short observed conversations are a practical next experiment, not a statistical proof. TestFlight also supports screenshot feedback and separate crash feedback; inspect both for the candidate build. [Apple's feedback instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback)

**Product enhancements in priority order**

| Priority | Change | Why it fits Telos |
|---|---|---|
| First | Recovery and reliable session state | Protects the work users already invested |
| First | Feedback/contact and minimal voluntary diagnostics | Turns silent beta activity into actionable evidence |
| Next | A satisfying continuing path for 10–25-minute users | Three of five sectors require 40/60/90-minute blocks; more resources never overcome those gates |
| Next | Make the first useful upgrade unmistakable | Reinforces the work → reward → next project loop already present |
| Later | A quiet weekly summary of protected time and optional reflections | Shows value without streak pressure or repeated notifications |
| Later | More camp identity and collectible story content | Deepens attachment and creates an appropriate paid-content surface |

The short-session issue is a product tradeoff, not an accidental balance defect: the design deliberately reserves deeper places for longer runs. It nevertheless narrows the audience. Consider additional shallow routes, finite stories, camp restoration milestones, or an accumulated-progress journey alongside the existing long-block expeditions. Extend the free path before selling expansions. The current simulation confirms 25-minute users cannot visit sectors 3–5; it is an optimistic model that sends the whole roster and omits several real spending choices, so its unlock-day figures are not retention predictions.

**Monetization recommendation: sell attachment to the guild and its world.**

Start with one permanent supporter pack after the reliability fixes and a round of feedback. Keep the store in Settings or camp, preview the exact contents, and make all purchases optional. Suggested prices below are hypotheses in USD, not validated willingness to pay.

| Offer | Concrete contents | Initial hypothesis | Recommendation |
|---|---|---|---|
| Supporter pack | Extra sigils, one alternate camp illustration, cosmetic share-card frames | $4.99–$7.99 once | Best first experiment; small scope and no balance change |
| Cosmetic collections | Camp banners, alternate camp scenes, portraits, icon variants | $1.99–$3.99 each | Add only if users show interest in identity/customization |
| Story/region expansion | New places, journals, art, and equivalent-power discoveries earned by focusing | $4.99–$9.99 once | Stronger long-term offer; give short sessions meaningful content too |
| Optional tip | Support development with no gameplay benefit | Small selectable amounts | Useful secondary option; do not rely on it for predictable revenue |
| Physical field journal or art prints | A real companion to the fiction and work ritual | Validate demand before inventory | Truly outside the app; use a low-inventory experiment later |

An adjacent example is Spirit City, which offers a supporter pack, cosmetic packs, and location expansions. That establishes a recognizable offer structure, not proof that Telos users will buy it. [Publisher's DLC listings](https://store.steampowered.com/dlc/2113850/Spirit_City_Lofi_Sessions/)

I would defer a subscription until there is a credible recurring service or content schedule. The present offline app has a more natural permanent-purchase proposition. Never sell faster progression, better random-drop odds, rescued Integrity, or access to ordinary timer functionality. Purchased regions should expand variety without becoming the optimal way to earn resources.

For the initial iOS digital packs, plan for StoreKit non-consumables, verified entitlements, restore purchases, offline access after purchase, refund handling, and reinstall/device-change behavior. A JSON backup must not mint paid entitlements. Use the applicable purchase route for tips; external digital-payment linking differs by storefront and should be assessed when choosing launch regions. Physical goods use a separate checkout. [Apple purchase rules](https://developer.apple.com/app-store/review/guidelines/)

For scale perspective only: 1,000 engaged users × a hypothetical 5% buyer rate × $4.99 is $249.50 gross for those first purchases, before fees, taxes, and costs. It is not monthly recurring revenue. Start small enough that this experiment is useful even if revenue is modest; expand production only after actual purchase interest.

**Release decision after remediation**

Require a signed archive from the reviewed commit and record its actual TestFlight build number. Complete the existing `docs/design/device-validation.md` pass on that exact build: fresh install and upgrade retaining a guild; denied notifications; a real locked 25-minute session and a longer one; force quit and resume; cancellation and recall; one-time reward banking; widgets/Shortcuts/Live Activities; Files export/import; sharing on iPhone and iPad; large text and VoiceOver. Explicitly verify completion alerts under Focus and the signed capabilities; setting a Dart interruption level alone is not device evidence. Check the archive's privacy resources and store support/privacy URLs.

Ship a small public release once those checks and the P1 fixes are complete, with the data-integrity and duration defects addressed as well. Better feedback collection can accompany that release. Monetization can follow; it does not need to hold up a reliable free launch.

Only this report and its observational probes were added. Application source, assets, dependencies, signing, and deployment configuration were not changed or published.
