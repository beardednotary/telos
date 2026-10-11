# Telos: typography and palette alternatives

**Decision: Night Watch is selected for launch.** The user likes its strong, modern game identity. Survey Office and Woodcut are retained as possible later cosmetic directions; this does not approve a store, prices or a house system. The [launch identity brief](../launch-identity.md) covers guild naming, sigils and future packs.

The comparison followed approval of the interaction structure and dissatisfaction with the earlier cream/font combination. These treatments preserve that flow.

Open [the interactive comparison](index.html). The buttons above the previews switch all three to Camp, Orders, Return or Focus. Each treatment also links to the full expedition loop. The [default prototype](../expedition-prototype/index.html) now uses Night Watch; the [previous cream treatment](../expedition-prototype/index.html?treatment=cream) remains an explicit archive option.

Static exports: [camp](camp.png), [orders](dispatch.png), [return](return.png), [focus](away.png).

## Design judgment

The earlier cream, moss and broad serif combination suggests a comfortable fantasy journal. That is a valid tone, but it does not have to define Telos. Its world also contains extraction works, service roads, shift rosters, survey equipment, expedition crews and strange artifacts. Those concrete references support less familiar combinations of practical lettering and restrained fantasy detail.

“AI-generated” is not a measurable property of a palette or typeface. These studies aim for a more specific identity, not an assurance about audience reaction or proof of human authorship. The approved image still supplies the people and atmosphere. Neither the raster illustration nor the content has been regenerated or recolored.

## 01 — Survey Office

Use **Barlow Semi Condensed Semibold** for titles and **Barlow Regular/Semibold** for controls and reading. The narrower title face gives names the character of signs on equipment. Guild and destination screen titles use capitals; sentence-case control labels remain easy to scan.

The ground is fog gray `#e7ecee`, the main action slate `#273f4c`, and the accent rust `#8e402d`. Rust marks progress and found objects; it does not spread across every panel. The camp image is the warmest element.

This is the practical, lighter option. Its risk is looking too much like an application for fieldwork; recognizable gear, places and characters need to carry the game identity.

## 02 — Night Watch

Use **IBM Plex Sans Condensed Semibold** for titles and **IBM Plex Sans Regular/Semibold** for reading and controls. Keep titles in sentence case, with short uppercase labels only for secondary identifiers. The family provides a consistent relationship between compact names and legible instructions.

The ground is charcoal `#1e252b`, panels `#272f35`, text pale gray `#e6eaeb`, and the action/accent brass `#d3b779`. Dark panels remain distinguishable through borders and spacing. The warm image belongs naturally beside the brass, while the rest of the interface stays quiet.

**My strongest recommendation for the user's desire for a game-menu feel.** The compact type and dark panels give planning a tactical setting without suggesting combat. The risk is becoming too solemn or resembling a generic dark dashboard. Keep the authored objects and world visible, and avoid gradients, glow, tiny HUD labels or extra statistics.

## 03 — Woodcut

Use **Grenze Semibold** for people, place and item titles, with the existing **Source Sans 3** for instructions and controls. Grenze's sharper shapes offer a more overt fantasy-book voice than Bitter. Its use is deliberately limited: buttons, numbers and explanatory paragraphs do not use the display face.

The ground is stone white `#ececea`, ink `#292528`, and the action oxblood `#682d3b`. This keeps a printed character without making every surface parchment-colored. The camp illustration reads like a plate in an expedition account.

This has the clearest tabletop-RPG flavor. It is also the most theatrical option. Avoid extending the expressive title typography into dense equipment statistics or ordinary control labels.

## Shared rules

- Preserve the selected project, two closed camp disclosures, sequential preparation, quiet session, reward moment and optional report.
- Keep JetBrains Mono for quantities across all three. It is already part of Telos, and numerical alignment has a real job.
- Keep bounded sections and one main action. Use one accent with a consistent meaning.
- Use ordinary sentence-case instructions, no faux medieval language, no new textures, no ornamental borders.
- Distinguish selection through a heavier outline and check/pressed state as well as color.
- Keep artwork intentional and sparse. This study reuses the approved image and the existing code-native equipment silhouettes.

These are three coherent starting points. A palette and type family could be mixed after review, but first compare each in context across preparation and return rather than judging a font specimen alone.

## Font sources and licensing

The fonts are downloaded locally with their Open Font License files under `docs/design/fonts/`. The prototype makes no runtime font requests.

- **Barlow / Barlow Semi Condensed:** Jeremy Tribby's [official Barlow page](https://tribby.com/fonts/barlow/), with distributed files from [Barlow](https://github.com/google/fonts/tree/main/ofl/barlow) and [Barlow Semi Condensed](https://github.com/google/fonts/tree/main/ofl/barlowsemicondensed) in Google Fonts. Files: `Barlow-Regular.ttf`, `Barlow-SemiBold.ttf`, `BarlowSemiCondensed-SemiBold.ttf`, and matching `OFL-Barlow*.txt` licenses.
- **IBM Plex:** [official IBM repository](https://github.com/IBM/plex) and [IBM's typeface documentation](https://www.ibm.com/design/language/typography/typeface/). Distributed files from [IBM Plex Sans](https://github.com/google/fonts/tree/main/ofl/ibmplexsans) and [IBM Plex Sans Condensed](https://github.com/google/fonts/tree/main/ofl/ibmplexsanscondensed) in Google Fonts: `IBMPlexSans-Variable.ttf`, `IBMPlexSansCondensed-SemiBold.ttf` and their `OFL-IBMPlex*.txt` licenses.
- **Grenze:** Renata Polastri and Omnibus-Type's [official repository](https://github.com/Omnibus-Type/Grenze), which describes its Roman/blackletter hybrid construction. Distributed variable font from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/grenze): `Grenze-Variable.ttf`, `OFL-Grenze.txt`.
- Existing Source Sans 3, Bitter and JetBrains Mono files and licenses remain unchanged.

The aesthetic descriptions and recommendations above are design judgments about the rendered studies, not statements from the font publishers.

## Validation and implementation boundary

`python docs/design/visual-directions/render.py` renders the four comparison boards and checks all three treatments at 390px and 320px. It also exercises disclosures, equipment dialogs, duration warnings, purpose selection, dispatch, completion and upgrading with the shared prototype code. The default-entry check now expects Night Watch; the cream archive is checked separately. Guild identity save/cancel, blank-name validation and unchanged progression are exercised by the main prototype's rendering script.

Primary text, secondary text on panels and selected rows, and primary button text were checked against their surfaces. The lowest of these measured ratios is 4.65:1. This is a check of the selected text pairs, not a full accessibility certification. Loaded font metadata was verified; Chrome's font inspection confirmed that the Night Watch headings, paragraphs and numbers use the specified embedded fonts rather than fallback faces.

The collapsed main screens fit at 390 × 844. Primary actions also remain visible at 320 × 844, with content scrolling inside its section when needed. Expanded details scroll within the screen. Font scaling and native Flutter rendering still need review if a treatment is implemented in the app.

Implementation: `treatments.js` defaults to Night Watch, accepts explicit `survey`, `night` or `woodcut` variants, and preserves the earlier appearance through `cream`. `treatments.css` applies scoped font and color tokens. The shared prototype now also has an optional name/sigil editor. The real Flutter app, economy and root README are unchanged. Sample sessions, provisional expedition-purpose modifiers and scripted first loot retain the limitations described in the [prototype scope](../expedition-prototype/README.md).
