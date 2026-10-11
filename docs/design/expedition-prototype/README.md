# Telos: camp, expedition, return

The user has chosen **Night Watch for launch**, alongside the approved interaction flow. The default prototype now uses its charcoal/brass palette and IBM Plex typography. [The other treatments](../visual-directions/index.html) remain reviewable; `?treatment=cream` preserves the earlier cream appearance. Tap the guild name/pencil at camp to edit the name and choose a sigil. The [launch and cosmetic recommendations](../launch-identity.md) distinguish the confirmed direction from possible future packs.

Open [index.html](index.html) in a browser. No server or build step is needed. [board.html](board.html) puts the three main screens side by side.

This is the next interactive study after agreement on the direction in [the working brief](../current-direction.md). It explores a game that rewards deliberate preparation and then lets the player put the phone down. It does not modify the Flutter app or supersede its README.

## Try this loop

1. At camp, inspect the Forge II project. Open **Squad & equipment**, then **Equip** to compare a Slag Brace with the existing gear. Each adventurer has two slots; an item can have only one owner.
2. Choose **Plan an expedition**. Keep 25 minutes. Under **Their expedition**, switch between Extraction and Survey and compare the forecast. Destination and duration remain independent. An invalid combination explains the constraint and disables dispatch.
3. Deploy. The phone preview offers no camp management or reward peeking. Use **Preview completed session**, outside the phone, to simulate returning after the committed duration.
4. Inspect the find and expand the report. Return to camp and build Forge II with the credited earnings. Equip the Deep Lamp, then inspect how the next forecast changes.
5. **Repeat** deploys the saved time, destination, purpose and squad with the currently equipped gear and facilities. **Reset example** restores the original fixture. Reloading also resets it.

## What works

- Guild identity editing at camp: a name up to 32 characters, four code-native sigils, explicit save/cancel, and no effect on resources or the expedition forecast. Changes last for this in-memory example only, like other prototype state.
- One open disclosure section at a time; selected values remain visible in its closed summary.
- Duration presets and custom 5–180 minutes in steps of five; optional work intent; three destinations and two squad slots.
- Gear ownership, two gear slots per adventurer, live swap comparisons, clear slots, and equipping the earned item.
- Selectable Forge or Archive projects, affordability, confirmation of resource spending, escalating costs, and improvements to the following expedition.
- A committed snapshot of the plan and forecast. Completion credits resources once. Camp interactions themselves do not generate earnings. Recall simulates an immediate zero-minute return with no earnings.
- A return report explaining how the selected purpose changes the resource mix, plus the fast repeat path.
- Local fonts and artwork; no network calls, dependencies at runtime, persistence, analytics, or backend.

## Current rules versus proposed rules

The sample guild starts at level 5 with four level-4 adventurers, two squad slots, three available sectors, 96 credits, 18 alloy and 61 intel. Barracks II permits the four-member roster; Forge and Archive start at level I. Previous recruitment and unlock costs are assumed already paid. The fixture deliberately needs one ordinary 25-minute run to afford the next facility. It is not a simulation of a new save or long-term balance.

Existing values come from `lib/data/content.dart`, `lib/models/models.dart`, `lib/models/guild_state.dart` and `lib/services/expedition_engine.dart`: sector minimums and resource rates, class windows and bonuses, level modifiers, equipped gear, averaging of squad modifiers, team size, facility increments and facility costs. Resource forecasts assume 100% Integrity. They use the existing resource formula, then the proposed purpose multiplier before rounding. The formulas are copied into this isolated experiment, not imported from Dart or exhaustively verified as a second resolver.

**Expedition purpose is a new proposal.** The two examples are deliberately simple resource tradeoffs:

| Purpose | Credits | Alloy | Intel |
|---|---:|---:|---:|
| Extraction | ×0.90 | ×1.25 | ×0.80 |
| Survey | ×0.90 | ×0.75 | ×1.60 |

These multipliers are illustrative, not approved production balance. For the untouched fixture, the base 25-minute Blackstone haul is 165 credits, 59 alloy and 6 intel. Extraction yields 149 / 74 / 5; Survey yields 149 / 44 / 10. Both can fund Forge II from this fixture. The different resource mix is the decision under review, not a claim that either policy is balanced over months.

The first completed expedition has a **scripted find**: Deep Lamp in Blackstone, Field Optic in Mosswood, Cinder Key in Cinder. Later completions in the same preview award resources without further gear. This is a reward presentation demo, not a loot-probability test. A percentage labeled “gear-find modifier” is a relative modifier to a per-attempt chance, not a promise of a rare item.

The journal closing sentence is sample copy. There is no invented minute-by-minute encounter timeline. The prototype does not run a timer or track Integrity, XP, levels, contracts, recruitment, crafting, story progression, device locks, or notifications. The running view is a frozen review state. The button that advances it sits outside the product UI. The production timer and honesty model remain the README's authority.

## Visual system

**Launch update:** the table below records the earlier study. The selected treatment is Night Watch: IBM Plex Sans Condensed titles, IBM Plex Sans controls and reading, JetBrains Mono quantities, charcoal `#1e252b`, pale text `#e6eaeb`, brass `#d3b779`, and visible neutral rules. The interaction and illustration rules remain applicable. The full appearance specification and licenses are in [the treatment rationale](../visual-directions/direction.md).

The approved [camp illustration](../camp-study/camp-concept.png) anchors the mood: practical travelers, worn tools, quiet ruins and ink silhouettes. Its [generation prompt and provenance](../camp-study/art-prompt.md) remain with the earlier study. Reuse that approved image; gear drawings in this prototype are inline SVG. The image establishes tone, not canonical portraits of named characters.

| Role | Decision |
|---|---|
| World and item titles | Bitter, medium/semibold; compact serif shapes with a bookish expedition character |
| Reading and controls | Source Sans 3; sentence case, plain verbs, comfortable line spacing |
| Time and quantities | JetBrains Mono; tabular, stable digits, restrained use |
| Ground / text | Warm paper `#f2eee1` / dark ink `#232a24` |
| Boundaries | Visible 1px rules, square or 3px corners, a quieter neutral fill |
| Main action | Dark green `#28372c`, consistent at the bottom |
| Current choice | A heavier border and explicit check or pressed state; never color alone |
| Running | Dark field, one clock, work intent and Integrity; no live game information |
| Information density | One project, closed management sections, one primary action; only the decision being edited expands |

This is a deliberately small system study. It does not establish the full set of production components, dark-mode management screens, Dynamic Type behavior, or the complete guild navigation. A full rollout also needs a durable progression model for players who always choose 25 minutes; this example establishes one useful loop, not that larger balance claim.

## Validation

Run `python docs/design/expedition-prototype/render.py` with the installed Python Playwright package and Chrome. The script exercises the earning/spending loop, tradeoffs, equipment ownership, recalls, duration constraints, keyboard dialog behavior, and mobile layouts. It also creates `overview.png`, `equipment.png`, `dispatch.png`, `away.png` and `return-report.png` for review. No Flutter tests are necessary for this isolated document prototype.
