# Current direction: an expedition game with a tactical interface

**Current checkpoint:** the complete Flutter screen migration is implemented,
including the expedition loop, management, archive, manual, settings/backups,
contracts, Spire, and share preview. It uses real state and tested calculations.
See the [implementation record and native previews](native-implementation-plan.md).
**Next milestone:** [validate the experience on a physical iPhone](device-validation.md).
Native widgets/Live Activity now use Night Watch fonts and colors, and launch
backgrounds use charcoal; the existing icon is retained. These native changes
need the signed Codemagic build and device review. The prototype's illustrative
mechanics remain separate from this migration.

**Launch direction selected: Night Watch.** The user explicitly chose its charcoal, brass and IBM Plex treatment for launch, praising its modern, distinctive game identity. It is now the prototype default. Preserve the approved low-friction flow. Survey Office and Woodcut remain available in [the comparison study](visual-directions/index.html) as possible later cosmetic directions; neither pricing nor packaging has been decided. The user also wants editable guild names and sigils. A small [guild identity editor](expedition-prototype/guild-identity.png) now demonstrates that at camp. See [launch identity and later cosmetics](launch-identity.md) for the confirmed decision, recommendations and repo findings.

The user has agreed to this direction: useful, optional camp play around expeditions that resolve while the player focuses elsewhere. The interaction reference is the [interactive expedition prototype](expedition-prototype/index.html), with a [three-screen overview](expedition-prototype/overview.png) and [scope, mechanics and visual decisions](expedition-prototype/README.md). It demonstrates a 25-minute run funding an upgrade, equipment comparisons, a quiet committed session, and a report that explains the result. This agreement establishes the direction; the purpose multipliers, scripted loot and sample save are still illustrative. The first native camp slice now implements the shared theme, guild identity, selectable existing facility projects, and disclosure navigation; the root README records that migration. The native dispatch, focus, and debrief now implement the same direction using the real resolver: three preparation disclosures, a quiet timer, and an outcome-led return with an expandable report. Roster, equipment, forge, and facilities now use the same bounded hierarchy, with real costs, equipment comparisons, and explicit purchase reviews. Automated coverage includes those management actions. Field log, the first-run manual, settings/backups, contracts, Spire, and share preview now follow the same system. Real iPhone lifecycle, Integrity, file handling, and sharing validation remain outstanding.

This is the active brief following feedback on the ledger and illustrated-camp studies. The user's stated preference is a mix of an expedition-party theme and a tactical-game interface, with light use of graphics. The user explicitly loves [the generated camp illustration](camp-study/camp-concept.png): it captures exactly the imagined people in the field. Keep it as the approved mood and art-direction reference. This does not establish canonical character appearances or require large illustrations on every screen.

The user confirmed that "strategy" means gameplay tradeoffs and planning. They also clarified that Telos primarily supports consistency and honesty through Integrity. Players should use the focus duration that works for them; the game should not pressure a consistent 25-minute Pomodoro user into longer work blocks. Gameplay changes below remain proposals, not implemented mechanics or silent revisions of the README.

## Settled constraints

- Keep the README's focus-first inversion and offline operation. Expeditions belong to committed focus sessions; active sessions expose no interactive gameplay or live reward reveals.
- Keep graphics light: sector geometry, class emblems, equipment silhouettes, routes, survey stakes, and slot layouts can remain code-native. Use the approved ink illustration to guide selected artwork and the world these symbols describe.
- Build a satisfying progression path for someone whose session length stays at 25 minutes. Consistency must continue to create useful opportunities even when expedition reach stays fixed.
- Use clearly bounded sections. Hide detail behind explicit expandable summaries; do not show an entire guild dashboard by default.
- Let numbers explain consequential choices. Avoid a field of equally weighted resource, XP, contract, and status panels.
- A tactical appearance must not imply nonexistent combat, damage, positioning, hazards, injury, or squad synergies.

## Planning, expedition, return

The user explicitly wants a fair amount of in-app play: strategy, planning, equipment decisions, and spending. Telos is a game meant to be put down, and its expeditions remain the main source of new progress. Simplifying the interface must not remove the enjoyable management layer.

| Phase | Meaningful play | Boundary |
|---|---|---|
| At camp | Pick a goal, compare destinations/jobs, assemble a squad, arrange equipment, recruit, and invest previously earned resources | Opening the app, changing a plan, or repeatedly tapping does not generate new expedition earnings |
| During focus | The committed expedition's time and Integrity determine its eventual resolution while the player works elsewhere | No mid-run choices, equipment changes, encounters to respond to, live loot, or reason to check in |
| On return | Receive the resolved expedition, understand what the plan achieved, inspect finds, and decide how to use the earnings | The next expedition is explicitly started by the player; no perpetual mission queue or reward stream between focus sessions |

Camp play turns the results of earlier focus into future capability. Instant equipment changes, crafting, and upgrades paid for with earned resources are compatible with this rule. Those actions give the player agency over what their effort becomes; the next expedition supplies new resources and discoveries. An uncommitted gap between focus sessions does not itself fund the guild.

Provide both a quick repeat path and deeper optional management. A saved plan can be dispatched again with little setup; a player who enjoys comparing builds can inspect the relevant numbers and make changes before committing. Do not impose a time limit, Integrity penalty, or shaming message on legitimate between-session planning. "At most one new planning decision" below refers to required friction on a routine dispatch, not a cap on strategic depth.

The management phase should have a satisfying stopping point: the find has been reviewed, an investment made or deferred, and the squad is ready. Further gains require another focus session. Avoid repeatable menu actions that manufacture rewards, real-time camp resource generators, expiring opportunities, or demands for a mid-session visit. These would work against the user's intended balance.

Make cause and effect readable on return: which choice influenced the resource mix, which equipment helped, what can now be afforded. Any explanation must reflect the actual resolver and not invent battles or events. Full calculations can expand on tap; the main debrief preserves the reward moment.

Locking the phone and working elsewhere is the intended ritual. V1 still uses the README's honesty model: it observes Telos screen time and reopens, not verified device-lock time or activity in other apps. The design must not promise stronger verification than the app performs.

## Visual strategy

Each illustration should answer a question. A sector profile can locate the chosen duration relative to the minimum and depth thresholds. Class emblems can identify party slots. Item silhouettes can distinguish equipment and show which slots are occupied. Survey stakes can preserve the player's history in a place. These roles can provide an expedition identity without bespoke character portraits.

Drawings share stroke weight, limited fill, a small set of symbols, and one accent for the player's current choice. Use neutral panel surfaces and clear section headings to delineate decisions. Focus detail on the part being edited; closed summaries retain selected values and any actionable constraints.

The illustration supplies a specific tone: practical travelers, worn equipment, strange old ruins, confident ink shapes, restrained color, and a modest pool of lantern light. These visual characteristics can carry into drawn equipment, camp structures, and diagrams without requiring a portrait for every recruit. The user likes this image; do not discard it based on the earlier graphics-lite preference.

The first study lacked delineation. Retain the second study's clear disclosure behavior and its approved world reference, while controlling how much artwork and information appears on each screen.

## Progression that respects a fixed session length

There is a structural tension in the current rules. Cinder needs 40 minutes, Riftline 60, and the Spire 90. No amount of 25-minute runs can meet those per-run minimums. This is more than slower progression. Short-session players can still earn resources, levels, gear, recruits, and upgrades, but their dispatch geography stops at Mosswood and Blackstone. Their finite prior-survey sequences also finish: fifteen lines in Mosswood and sixteen in Blackstone (ten more each were added for short-session players).

The former camp's `GuildState.nextGoal` helper prioritizes locked sectors without considering session length. The new native camp instead shows a saved, player-selected facility project; the helper remains in the code but no longer drives this screen. Contracts can also ask for long runs and full depth. These are places where the game can imply that a different work pattern is the path forward, even without explicit nagging. The existing reachability test deliberately permits duration exclusion; passing it would not establish that the 25-minute player's long-term experience is satisfying.

Recommended division of responsibilities:

| System | Job |
|---|---|
| Duration | Determines the reach and opportunity of this individual expedition |
| Resources and cumulative work | Support a guild that develops through repeated sessions of the player's chosen length |
| Integrity | Shapes the quality of a run using the existing integrity measurement |
| Player planning | Directs those earnings toward the equipment, people, and improvements they want next |

Keep longer uninterrupted expeditions meaningful, as the README requires. To support a fixed-duration player without changing that rule, develop reachable places as the guild grows: further local jobs, equipment plans, and useful roles, rather than only repeated increases to the same totals. A 25-minute player should gain new decisions and achieve lasting outcomes in those places. Distinct shorter-session milestones can coexist with distant destinations; they need actual content and mechanics, not a renamed progress bar.

One candidate gameplay addition is choosing the purpose of a local expedition. For a reachable Blackstone run, extraction might favor alloy, survey work might favor intel at a materials cost, and salvage work might trade some steady resources for more gear-finding opportunity. Those are proposed policies, not existing mechanics. Their tradeoffs must depend on the player's current goals so that one is not always best. Use the current sector/squad/equipment systems as the foundation, and add at most one new planning decision to a routine dispatch.

Existing contracts and facilities are useful foundations. Curate or let the player choose goals compatible with their available time. Make one selected, attainable project prominent, such as an equipment plan or outpost improvement. Let longer-session objectives remain available without making them the compulsory next target. A saved expedition setup should stay fast to repeat, so planning does not become a chore before every Pomodoro.

Consistency should accumulate permanently. Missed days, ordinary breaks between sessions, and returning after time away should not erase progress. Integrity remains a within-run mechanic; it should not become a calendar streak or an additional penalty for working in short blocks.

This proposal does not promise that 25-minute players can see every existing deep-sector story or the Spire ending. Under the present minimums they cannot. If access to the same complete story becomes a requirement, it would need a separately agreed change to expedition access or story distribution. The current recommendation first preserves the meaningful difference between session lengths while making shorter-session play richer.

## Existing player tradeoffs, verified in the repo

The engine contains planning ingredients: sector resource biases and item pools, class duration windows, limited squad and gear slots, gear modifiers, resource spending, and contracts that can change the next useful expedition. These are mostly numerical optimization rather than a developed tactical encounter system. The current screen shows combined modifiers, but does little to compare the consequence of one choice against another.

One concrete example uses the same available 45 minutes and the same squad:

| Destination | Resource emphasis | Depth at 45 minutes | Gear-finding attempts |
|---|---|---|---|
| Blackstone Hollow | Alloy | 100% | 2 |
| The Cinder Archive | Intel | 75% | 1 |

Both qualify for non-scrap loot: their minimums are 25 and 40 minutes. The attempt count comes from `ExpeditionEngine.resolve`: one base attempt, another at 100% nominal depth, and another at 140%. Each attempt can fail; none guarantees a piece or a rare rarity. The displayed `rareChanceFor` value is the chance per attempt of obtaining *a gear item*, followed by a separate rarity selection. Describing it as a guaranteed rare-item chance or a whole-expedition probability would be misleading.

Evidence: `lib/data/content.dart` (sector rates, nominal durations, class windows, gear); `lib/services/expedition_engine.dart` (yield, attempts, per-attempt chance, rarity selection, averaged squad bonuses); `lib/screens/dispatch_screen.dart` (`_Projection`); `lib/services/contracts.dart` (existing goal generation).

This is a more useful design test than a generic "Fits 45 min" label. Can the player understand why they might deliberately choose either destination? Does changing one member or item clearly show the opportunity cost? No actual loot should be revealed in advance.

## Proposed interaction focus

Treat the session length as the player's real-world constraint. Make the next screen help them spend that available time deliberately. For example, a player seeking intel to open a sector may favor Cinder; someone seeking alloy or more gear attempts may prefer Blackstone. A selected existing goal can contextualize the comparison without adding a new currency or reward multiplier.

Keep the core preparation order: intent, duration, destination, squad. Expand one step at a time. The destination view can show a sparse sector profile and a compact comparison of its consequences. The squad view can show party/gear slots and the effect of a proposed swap. Full formulas, history, flavor, and the rest of the guild stay in secondary views.

A new objective selector, route choice, stance system, hazards, or class-combination rules would be a gameplay proposal requiring balancing and an explicit README update. None is implemented or assumed here. First make existing meaningful choices understandable; then assess whether the underlying decisions remain too shallow.

## Acceptance questions

Can someone identify their next action without reading every section? Can they name the meaningful consequence of the sector or squad they selected? Does each coded drawing communicate a place, an object, or a decision rather than occupy space? Can they finish planning and put the phone away promptly?

Also evaluate a player who stays at 25 minutes for months: can they still unlock choices, complete attainable projects, and develop their guild? Balance proposed rewards against actual protected time and Integrity, checking both repeated short runs and longer runs. A UI mockup cannot establish that this progression is fair or durable.
