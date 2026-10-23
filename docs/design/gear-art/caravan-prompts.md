# The Caravan's six
Caravan salvage (kCaravanGear in lib/data/content.dart) is found in no sector. It comes from a supply line that has run the old service road for longer than the outpost has existed. These pieces should look like freight gear: teamsters' kit, made to be loaded, lashed down and checked at gates. Compared with sector salvage, they are plainer and more standardised, like things issued and stamped rather than found. That difference is how someone recognises a caravan find before reading its name.

Same skeleton, same style lock, same rarity guide and same 640px WebP as above. Use camp-concept.png and ore_sense.webp as references, exactly as the twelve did.

Two lessons from the first nineteen that apply here:

Brass drifts gold. Deep Lamp needed a revision because its metal came out warm. Put the colour-discipline line in the first prompt; don't rely on the revision.
Paper and dials invite text. Three of these have a stamp, a dial or a label. Every mark must stay a mark: no letters, no numerals, nothing readable.
None of the six are spoilers.

## waybill — TEAMSTER'S WAYBILL · uncommon
"Stamped for a place that was not here yet."

A single folded freight waybill of heavy creased paper, tied through a brass-ringed eyelet to a short loop of string, the way a tag is tied to cargo. One round inked stamp impression on its face, partly worn away.

Constraints: the eyelet and string are the one working feature. The stamp is an abstract round mark of rings and a simple cross-hatch, with no letters or numbers. Ruled lines appear only as faint marks. Paper parchment, stamp charcoal. No warm accent.

## road_lantern — ROAD LANTERN · uncommon
"Lit at the gate. Never put out on the road."

A plain tin hurricane lantern of the cheap, common kind: a squat fuel font, two thin wire guards around a short glass chimney, and a top cap with a wire carrying bail. Dented, its paint mostly worn off. Lit, with a very small low flame.

Constraints: deliberately simpler and cheaper than the Deep Lamp. Use wire guards instead of mesh, with no brass cap or base. The flame is the only warm note: a tiny flat ochre shape with no glow, halo or light cast on the glass or paper. All metal stays neutral grey. It must read as a different object from the Deep Lamp at 88px: squat and wide where the Deep Lamp is tall and narrow.

## axle_pin — AXLE PIN · rare
"Turned by hand. It fits every wagon on the line."

A heavy hand-forged iron linchpin, long and slightly tapered, with a flat forged head. A split cotter pin runs through a hole near its tip, with one leg bent back to lock it. Worn smooth and bright in a band where a wheel hub has turned against it for years.

Constraints: the cotter through the pin is the mechanism. Show the pin lying at a slight diagonal so its length and the cotter both read. The worn band is parchment-pale against charcoal iron, not shiny. Add nothing else: no wheel, no hub, no chain. No warm accent.

## drover_coat — DROVER'S COAT · rare
"Proofed against weather with something that still smells of smoke."

A heavy oilskin drover's coat, folded square the way it would be packed on a wagon seat, with a short shoulder cape lying over the fold. One horn button is visible, and beside it a mismatched replacement. A long darkened, smoke-stained patch runs along one edge of the hem.

Constraints: a folded garment, with no figure, mannequin or hanger. The oddity is the smoke staining: a dark tonal patch, with no burns, holes or flames. Use broad dark silhouette masses for the oilskin and selective hatching on the fold lines. No warm accent.

## slow_watch — THE SLOW WATCH · epic
"Eleven years behind, and never once late."

A heavy old pocket watch on a short length of chain, its back case hinged open to show the movement: a few large gears and a balance wheel. The front dial carries tick marks only, and its two hands sit at an ordinary-looking time. The case is worn smooth at the edges from years in a pocket.

Constraints: no numerals on the dial. Use tick marks only, with a heavier mark at each quarter. The open back is the epic's mechanism, so keep it legible at 88px by using a few big gears rather than a dense movement. The metal is tarnished neutral grey, never gold. This is the lead driver's watch from the manifest. It echoes the eleven-year-old tins in Mosswood, so don't make it look precious or magical. It should look like a working tool that has never been corrected. No warm accent.

## gate_seal — GATE SEAL · epic
"The caravan stops where this is pressed. Nowhere else."

A freight seal: a heavy disc of soft grey lead crimped shut around the two ends of a twisted wire loop, the way cargo and gates are sealed. Its face is pressed with a deep, crisp, simple mark. Beside it lies the pliers-like iron sealing press that made the impression, its jaws still open.

Constraints: two objects is the epic allowance here. The press is the mechanism, and it shows how the seal is made. Keep the lead seal clearly the subject: larger, central, with the press set behind and to one side. The pressed mark is a simple geometric sign, a ring around a short vertical bar like a gate post. It is not a letter or a heraldic crest, and it must not resemble the Spire Sigil's tower or the Quiet Seal's wax. Lead is dull grey, never silver or shiny. No warm accent.

## Production notes

Generated and revised with the built-in image_gen tool, using the camp concept
and Ore-Sense Rig as style references. Exact prompts, revisions and output
provenance are recorded in `generation.json`. Selected PNG masters are in
`sources/`; final files are `assets/art/gear/<id>.webp`, 640 x 640 at quality 86.

The six IDs and rarities come from the supplied brief. `kCaravanGear` was not
present in this checkout when the art was delivered; the files use those IDs
for the existing `GearArt` filename convention. Gameplay definitions remain
part of the Caravan feature implementation.
