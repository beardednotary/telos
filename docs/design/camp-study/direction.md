# Telos, revision 2: camp, expedition, return

**Latest feedback:** the user explicitly loves the camp illustration as the reference for the people and world. They prefer an expedition/tactical mix with graphics-lite screens, and confirmed that the missing strategy concerns gameplay. Retain the illustration as an art-direction anchor and the disclosure experiment; continue from [the current brief](../current-direction.md), which also addresses consistent 25-minute sessions. The user has agreed to that direction. [The newer interactive prototype](../expedition-prototype/index.html) now demonstrates forecasts, equipment choices, resource spending and a complete sample expedition loop. This folder preserves the earlier disclosure study.

This supersedes the first guild-ledger proposal. The user's response was that the screens still held too much information, lacked clear delineation, and did not read as a game. Removing containers did not solve those problems.

Open [the interactive prototype](index.html) or [the three-screen board](board.html). The prototype demonstrates accordion behavior, duration/destination/squad selection, a dispatch transition, a static session, and an example return. It is not connected to Flutter or a save file.

## Decisions in this revision

1. **The default screen is a limited view, not an overview of everything.** Camp shows the party, two collapsed sections, and one departure action. Balances, XP, history, contracts, unlock progress, and repeated expeditions do not all need to occupy the opening screen.
2. **Restore explicit boundaries.** Clearly headed panels group things that belong together. A shared neutral surface distinguishes them without assigning a different color to every concept. A border is useful when it marks a meaningful interaction boundary.
3. **Use progressive disclosure for depth.** Closed sections explain what is inside. When expanded, they show one coherent subject. Only one accordion is open per screen. The content scrolls; the primary action stays in its footer.
4. **Give the game actual subjects.** A party with recognizable equipment replaces the schematic skyline as the camp's focal point. A returned relic becomes the focal point of its own moment. Character marks and numbers alone did not establish this strongly enough.

## What stays visible, what opens

| Screen | Default view | On tap |
|---|---|---|
| Camp | Guild name, party illustration/names, two section labels, Prepare expedition | Party & equipment: member roles and kit slots. Guild stores: balances and next unlock. |
| Dispatch | One open decision, summaries of the other two, explicit dispatch action | Your focus: intent and duration. Destination: available sectors and requirements. Squad: members and duration fit. |
| Session | Static destination/party, countdown, intent, integrity explanation, recall | Recall confirmation only. |
| Return | One noteworthy result, item name/effect/flavor, Expedition report, return action | Resource gains, elapsed time, integrity, depth, progression, journal, and prior survey. |

The visible headings and closed summaries matter as much as the accordion mechanism. Adding accordions around every old card would still leave a long list to decode. Here each screen is reorganized around its purpose first.

## Dispatch safeguards

Destination, duration, and squad remain independent decisions. The prototype refuses a dispatch below the chosen sector's minimum and explains how to fix it; it does not silently change the destination. This differs from the current app's automatic fallback selection and is an explicit proposed interaction change. Selected party members can be removed and replaced, with two slots in the illustrated level-5 state. A custom duration accepts five-minute increments from 5 to 180, matching the current picker bounds.

Relevant conditions cannot be hidden only in an accordion. The closed destination row names the place. The closed squad row names the people. A below-minimum warning remains visible. The dispatch footer repeats the duration, destination, and selected names. If any selected member is outside their effective duration window, production should surface that in the closed squad summary as well as in the expanded picker.

The prototype does not calculate yield estimates, award loot, run a timer, save data, or change the real game. The Return preview is a fixed example of a completed 45-minute Cinder expedition, independent of experimental selections in Dispatch. Fixed demo member equipment and the camp illustration are illustrative, not a live roster representation. The prototype's session is deliberately static. Production retains both cancellation and integrity grace and the actual wall-clock timer.

## A game identity, with a controlled art budget

The first proposal tried to obtain most of the game identity from writing and tiny marks. This version tests a stronger visual claim: actual adventurers with gear, camp as a place, and a relic as an object. Most of the rest of the interface is restrained.

The chosen study uses a sparse ink/woodcut language, a bone background, moss-black structure, and a small brass accent. Bitter is used for names, Source Sans 3 for readable controls, and JetBrains Mono for numerical values. The goal is clear objects and simple menus, not simulated parchment controls or decorative framing everywhere.

The camp illustration is generated concept art, made with the built-in image tool and subsequently approved by the user as the mood and world reference. Its exact prompt and provenance are in [art-prompt.md](art-prompt.md). It establishes neither canonical character appearances nor a commitment to generated production art. The direction is now ink expedition art with a tactical interface; the style question is no longer open.

For production, recognizable party art needs reusable class/character assets. A static scene showing exactly two people cannot faithfully represent arbitrary recruited squads. Start with one consistent asset family and a text/sigil fallback rather than requiring bespoke art for every content entry. The prototype uses a vector key derived from the previous code-native key study; no new asset pipeline is needed to inspect that interaction.

## Return states and the README

The rare-find composition is an example, not the default promise of every run. A common run should lead with what actually happened: recovered supplies, a new survey note, or a level increase. A scraps/early-return state should show the honest result without manufacturing a consolation drop. All results remain discoverable in the report.

This proposal changes the default visibility and arrangement of the debrief. The README currently gives a deliberate staged order: header, numbers, journal, yield, salvage, progression. Showing a rare find as the settled screen's focal point while collapsing most of that sequence is a proposed change to the visual/pacing section, requiring an explicit documentation update if adopted. It does not change when or how rewards are resolved. Keep any reveal brief and skippable, support reduced motion, and never turn reward inspection into gameplay that advances a run.

Camp/return illustration is confined to between-session moments. The active session stays dark and quiet. The one notification, offline operation, focus-earned progression, no live game activity, and deterministic return remain the foundation.

## Next validation

First judge the three collapsed screens. Can a new player tell where they are, what they can do, and where extra details live? Then open each section and confirm that it answers one coherent question. Validate disclosure with touch and keyboard, long names/intent, larger text, a smaller device, empty inventory, full slots, no loot, and reduced motion before transferring the structure to Flutter.

This study introduces a real art requirement the previous ledger tried to avoid. The user should be able to assess that tradeoff visually before any production screen migration.
