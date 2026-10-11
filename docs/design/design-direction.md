# Telos: a guild ledger

**Revision status:** this first proposal was rejected as too dense and insufficiently game-like. The second study explored progressive disclosure and produced a camp illustration the user loves as the world reference. Continue with [the current expedition/tactical brief](./current-direction.md), including the requirement to support consistent short sessions. The material below is retained as the earlier study, not the current recommendation.

Design proposal, 10 October 2026. Reviewed local commit `8f481c0`, the README, theme, screen and widget implementations, game content, and saved golden images. Also reviewed the three supplied Claude Design boards: Plant the stake, Time tape, and Orders. This is a visual/product design review, not a runtime or correctness audit. The golden images are saved fixtures, not verified screenshots of the posted TestFlight build.

**Recommendation: use Orders as the interaction foundation, preserve visible numbers, and use the existing survey language to give the interface a world.**

The user's preference is simplicity, text, and numbers over differently colored blocks. The proposed identity is a guild's working ledger: quiet, precise, a little strange. It should feel like preparing an expedition and reading its return, with the minimum interface needed to do either.

Open [the local comparison board](./review.html) for four screen studies. It includes switches between the existing Syne and an optional Bitter heading treatment, and between light and dark surfaces. It uses illustrative data and is not a functioning version of the game. [The exported overview](./review.png) shows the initial light/Syne treatment; [the dark overview](./review-dark.png) shows the same layout on dark surfaces.

## What is already distinctive

The README's central rule is the design constraint: opening the app does not advance the game. The deliberate countdown, one notification, return-time reveal, duration/class relationships, and next-unlock target are worth protecting.

The authored world is more specific than generic fantasy: survey stakes left by an earlier company, signed-in tools, stocked caches, a library fire treated as weather, and an unfinished Spire. The gear has equally useful detail: the Cinder Key is always warm; the Deep Lamp burns on something other than oil. Use these particulars as the visual brief. They suggest measured marks, practical equipment, records, and strange relics.

The current app has already invested in this: sector scenes, sigils, class emblems, a Spire drawing, and a finite debrief reveal. Those are assets to develop. The current checkout also bundles JetBrains Mono and Syne. The system-font criticism cannot be assumed to describe this checkout, and the screenshots actually posted to Reddit have not been supplied.

## What currently obscures it

| Finding | Evidence | Design consequence |
|---|---|---|
| Almost every subject uses the same card grammar | `Section` in `lib/widgets/terminal.dart`; home, roster, forge, facilities | A recruit, a rare item, a journal entry, and a statistic have similar visual weight. |
| Administrative data gets the first attention | Home opens with guild XP and three large resource totals; squad management is much farther down | The first screen explains accounting sooner than it establishes the expedition. |
| The people are mostly names and tiny symbols | `_MemberBand` in `lib/screens/roster_screen.dart` | Little opportunity to recognize who went out or share their return. Give their names and roles meaningful placement before adding portraits. |
| Many labels are small, tracked, and faint | `T.micro` is 11; `T.dim` is `#6B7280` | Important explanations recede. Calculated contrast is 3.67:1 on `T.card` and 4.05:1 on `T.black`. Both are below the 4.5:1 normal-text benchmark. |
| Narrative competes with report scaffolding | Debrief's scene, statistic card, and long journal precede the yield and salvage | The saved 844px-high debrief has no loot visible before scrolling. Keep the reveal order, but shorten the initial summary so its payoff is discoverable. |
| Navigation follows a long dashboard | Home places roster/facilities/forge/log after contracts, next target, and protected time | Frequent between-run actions require scrolling through secondary information. |

These are hierarchy and presentation issues. Replacing one named font with another will not resolve them on its own. Nor can an interface establish which tool authored its code; the useful response to the criticism is a more coherent and specific experience.

## What to take from the three alternatives

| Direction | Keep | Revise |
|---|---|---|
| **3a: Plant the stake** | The player's accumulated marks belong to a place. This is Telos-specific, and already supported by `SectorScene`. | Let the scene punctuate a screen. A large drawing with leader lines crowds out the numbers and becomes difficult with text scaling. A new door opening or room discovered needs actual persistent game state if depicted as a permanent change. |
| **3b: Time tape** | Time has physical scale, and sector minimums can be understood spatially. | Time must not automatically determine the destination. A 90-minute trip to Mosswood remains a valid resource choice. Exact journal timestamps are not currently stored: presenting an event at minute 21 would invent chronology. The moving tape also makes the session more watchable. |
| **3c: Orders** | Human phrasing, quiet surfaces, an explicit relationship between the user's work and the expedition, a debrief that sounds like someone returned. | Keep currencies and yields as aligned numbers. Make editable fields obvious and large enough to tap. Avoid putting the entire UI inside a long sentence. Character-specific replies require authored voice; current generic journal entries should not silently become quotations from a particular member. |

The proposed design uses 3c's premise with a conventional, legible order form, a small version of 3a's survey scene, and an optional duration ruler informed by 3b. It does not combine all three navigation systems.

## Visual rules

### Surfaces and color

Use a continuous neutral page with whitespace and thin separators. No colored section backgrounds, tinted resource boxes, or routine left-edge accent bars. A single filled primary action supplies enough mass. A warm paper appearance is a candidate, not an assumption that light mode is required; the board includes a dark version. The active session stays dark.

| Role | Light | Dark | Use |
|---|---|---|---|
| Canvas | `#F0EDE5` | `#171D1A` | Continuous screen surface |
| Primary text | `#202720` | `#E9E2CE` | Names, body, numbers |
| Secondary text | `#60675E` | `#A5B0A2` | Readable explanations and metadata |
| Accent | `#8A491E` | `#D3A75C` | Selection, the latest survey stake, a rare find |
| Divider | `#CACCC0` | `#3E5144` | Decorative separation only |
| Danger | `#A43E35` | `#EC9A8E` | Destructive action or an actionable problem |

Name resources and rarities in text; do not require cyan/amber/green recognition. A future sector accent can tint its drawing, but should not recolor the entire interface. Selected controls have a check, underline, or filled state as well as color. Interactive boundaries must remain identifiable; decorative divider colors are not control outlines.

The proposed dark primary and secondary text have calculated canvas contrast of 13.23:1 and 7.60:1. Verify every actual text/background combination in implementation, including placeholders and selected controls. The contrast benchmark is from [W3C's normal-text guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

### Typography

Start by testing better roles for the fonts, rather than assuming the existing display face must go.

| Role | First candidate | Size / weight | Rule |
|---|---|---|---|
| Screen and place names | Existing Syne | 26–30 / 650–700 | Mixed case; normal tracking; usually at most two lines |
| Alternative heading | Bitter | 26–30 / 600 | Optional sturdy ledger character; compare in the same layout |
| Body and controls | Source Sans 3 | 16–17 / 400, 600 | Readable prose and obvious actions |
| Section label | Source Sans 3 | 13–14 / 600 | Sentence case; use spacing before shouting |
| Balances / rewards | Existing JetBrains Mono | 24–34 / 400 | Tabular, aligned, labels directly underneath |
| Time selection | JetBrains Mono | 56–64 / 400 | The dominant number during dispatch |
| Session countdown | JetBrains Mono | 72–84 / 300 | Stable width; fit and scale on smaller screens |
| Metadata | Source Sans 3 or JetBrains Mono | 13–14 / 400 | Mono only when alignment or an identifier helps |

Use one heading family per treatment, not Syne and Bitter together. Neither is a magic signifier of a game. Source Sans 3 is designed for UI use; Bitter is the optional serif comparison. Both are open-source font projects, with license copies beside the study fonts. Sources: [Adobe Source Sans](https://github.com/adobe-fonts/source-sans), [Sol Matas's Bitter project](https://github.com/solmatas/BitterPro), [Google Fonts' Bitter distribution](https://github.com/google/fonts/tree/main/ofl/bitter). Production fonts should be bundled locally, preserving the app's offline behavior.

### Graphic vocabulary

Keep the five sector sigils and five class emblems. Use the existing survey scenes at approximately 100–150 logical pixels tall on the outpost or order, with sufficient line weight to read on a phone. Their job is to identify a place and show past stakes, not to occupy every available pixel. The Archive's tall repeated shelves can read as a skyline at small sizes; an eventual art pass should make books, shelving, and the sealed room recognizable without a caption. The board's scene remains a schematic layout study.

A found object's silhouette is the best first addition: a key looks like a key, a lamp like a lamp. One recognizable shape beside its name and flavor line can make a reward tangible. Reuse item silhouettes in the vault, equipment slots, forge, and debrief. Provide a sigil/text fallback so a future content entry remains possible without commissioned art. The small key on the board is an illustrative vector study, not new production art.

Portraits, texture, and decorative animation are optional later work. They are not dependencies of this proposal. Avoid introducing an art obligation for each recruit or item as a prerequisite to shipping content.

### Layout and components

Use a 4-point spacing base: 4, 8, 12, 16, 24, 32. Default horizontal inset: 24. Primary action height: at least 52. All interactive targets: at least 48 logical pixels, including inline edits and navigation. Use wrapping and scrolling at increased text size; do not shrink essential copy to keep a fixed composition.

Build a small set of semantic components instead of one card for every subject:

- **Resource row:** three aligned values with names, no enclosing boxes.
- **Order field:** a visible label and selectable value with a clear affordance; opens an ordinary picker.
- **Squad row:** class emblem, member name, role, selection, and duration fit. List class bonuses where a decision needs them.
- **Survey plate:** recognizable sector geometry plus past/latest stakes, with a text equivalent for meaningful history.
- **Find row:** item silhouette, name, rarity word, effect, and flavor. A rare result earns whitespace and scale.
- **Ledger entry:** narrative prose with optional metadata, separated by spacing or a rule.
- **Primary action / secondary action:** one filled action per decision; secondary actions remain recognizable controls.

## Screen behavior

**Outpost:** name the guild; show a compact balance row; introduce the last/selected expedition and its survey; show the available squad; offer Dispatch and a restrained recent-order shortcut. Show one next target. Put Roster, Forge, Facilities, and Log in a consistent bottom navigation area or equally reachable navigation row. Keep contracts and lifetime statistics in a secondary scroll area. They remain available without displacing the next expedition.

**Dispatch:** preserve the README's intent → duration → sector → squad ordering. Lead with the user's intent, then a large duration. Give duration quick choices plus custom input. Keep the sector selection independent; changing duration never silently swaps it. Explain minimum and depth separately: for Cinder, 40 minutes is the loot minimum, 60 minutes is nominal depth, so a 45-minute run reaches 75% depth while qualifying for non-scrap loot. Show squad fit and a concise expected-yield summary. Label estimates as estimates; integrity is not known in advance. Pin the dispatch action above the safe area. Do not replace explicit confirmation with a sentence that starts a run when edited.

**Session:** retain the dark screen, countdown, intent, static destination/squad, and secondary recall. Integrity remains available as a small, readable status rather than a second dashboard. Explain its rule during setup/onboarding so there is no hidden penalty. Preserve the cancellation grace and the README's 30-second integrity grace. No looping animation, live expedition feed, changing scene, simulated combat, or preview of earned loot. The timer itself may update. The current implementation animates the entry sigil despite the README saying no motion; remove that entrance motion if taking the README literally.

**Debrief:** preserve the brief, skippable sequence: return → actual time/integrity → compact journal → resource yield → salvage → progression. The settled layout should expose the reward summary without scrolling through a large amount of report scaffolding. Provide the full journal and prior-survey text below, or through a clearly labeled expansion that does not discard it. Give a rare find a physical silhouette and its existing flavor line. Keep Return to outpost available. An optional Equip action must show the recipient and slots and preserve any displaced gear; it is a separate interaction change, not something to assume a visual refresh already implements.

**Roster / forge / facilities / log:** use rows and aligned numbers. Put gear on visible, named slots; show cost and resulting effect together; explain locks with legible text; make history read like a record of expeditions and the work that funded them. The same typographic and spacing rules should work without decorative panel variants.

## Voice

Keep the existing short, practical writing. Prefer “Pike and Odrin returned” over a system-status headline. Prefer “45 min · 75% depth” over an unexplained score. The precision and odd details in the existing content already provide personality.

Suggested new interface copy, subject to editorial review: “Your work. Their expedition.” during dispatch and “The report will be here when you return.” during a session. These describe the relationship without adding lore. Preserve exact meaning around integrity: the app measures time on Telos and reopens, not whether someone truly worked or used another app.

If character replies become a priority, author a bounded set of lines with a consistent voice for each class/member. No runtime text generation is needed. Do not turn current journal selection into invented event timestamps or simulated ongoing activity.

## Practical implementation order

1. **One vertical slice:** Outpost, Dispatch, Session, Debrief. Introduce semantic type/color tokens in `telos_theme.dart`, add a readable body family, and build the unboxed components alongside `Section`. No economy or save changes required for the initial visual slice.
2. **Validate the actual phone flow:** start/recall/return, first-run empty state, no loot, a rare drop, locked sector, long guild/intent names, full inventory, large text, and smaller screens. Preserve meaningful existing engine/flow checks; update goldens only after the layout is accepted. Static mockups cannot validate these behaviors.
3. **Apply the rules to the other screens:** roster, forge, facilities, log, onboarding, and share card. Use the same item and class marks. Add explicit semantics to custom controls and honor reduced motion in the debrief.
4. **Only then expand the art:** a small, consistent family of item silhouettes, and stronger sector drawings if needed. The game must still read clearly in plain text and grayscale.

For review, compare the same representative state in the current UI and the proposed slice. Ask testers what they would do next, who is going, where they are going, and what they earned. Ask separately whether it feels like managing an expedition. A preference poll alone will not tell us whether the design communicates the game.

## README stewardship

The README remains the product authority. This proposal changes its visual-language section only if adopted; it does not silently replace the core loop. There are already implementation/documentation differences to reconcile: Syne and sector drawings now exist although the visual section describes mono throughout; a forge exists although crafting is listed outside V1. Clarify these explicitly before treating either side as the definitive current feature list. Do not broaden the game merely to satisfy a visual concept.

## Study files

`review.html` is an offline design comparison, with inline vector marks and locally loaded fonts. Only its review controls are interactive. It makes no network calls and does not connect to a save. `review.png` is an exported overview. These files do not change the Flutter app, its dependencies, or its README.
