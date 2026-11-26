# Mark plates: sector sigils, class emblems, guild emblems

Fourteen inked plates to replace the code-drawn strokes wherever a mark is
shown large. Five sector sigils (a place), five class emblems (a person),
four guild emblems (the player's own company).

## Where they are used, and where they are not

Same rule as the salvage plates (`../gear-art/prompts.md`): a plate goes
where the mark is looked at, the stroke stays where it is scanned.

**Plates (56px and up):**

| Call site | Mark | Size |
| --- | --- | ---: |
| `lib/screens/outpost_screen.dart:411` ("The way is open", on unlocking a sector) | sector sigil | 72 |
| `lib/screens/outpost_screen.dart:342` ("A new hand", on recruiting) | class emblem | 72 |
| `lib/screens/outpost_screen.dart:301` ("Meet a recruit" sheet) | class emblem | 64 |
| `lib/screens/debrief_screen.dart:406` (guild beat) | guild emblem | 88 |
| `lib/screens/guild_identity_sheet.dart:131` (emblem picker) | guild emblem | 32 → raise to 64 |

**Strokes stay (under 56px, or animated):** dispatch rows (24), contract
board (26), share card (26), roster (32), home header (32), backup (40),
and the flash in `lib/widgets/flash.dart`, whose stroke-by-stroke reveal a
raster cannot do. Do not touch these.

## The current mark is the spec

Players already know these shapes. Each plate must keep the current mark's
silhouette so that the 72px plate and the 24px stroke read as the same
sign. Attach the matching file from `current/` as the image reference for
every generation, and reject any output whose silhouette at 64px does not
match it.

```
current/sector-mosswood.png     current/class-vanguard.png       current/guild-lantern.png
current/sector-blackstone.png   current/class-recon.png          current/guild-compass.png
current/sector-cinder.png       current/class-archivist.png      current/guild-branch.png
current/sector-riftline.png     current/class-artificer.png      current/guild-anvil.png
current/sector-spire.png        current/class-quartermaster.png
```

The geometry these came from is `lib/widgets/sigil.dart` (`sigilPath`,
`emblemPath`) and `lib/widgets/guild_sigil.dart`. Their comments are the
meaning of each mark; the briefs below use nothing else.

## Rules for all fourteen

The style lock is `../camp-study/art-prompt.md`, as for the sector headers
and salvage. These plates depart from it in one deliberate way: **ink only,
no colour.** The app tints every mark (amber at all the plate sites today),
and a mark's colour is information: a sector's colour says *where*, a class
stays monochrome and says *who*. So the plate is a single-ink alpha mask
and the code supplies the colour.

- **Square, 1:1.** The mark sits in the central ~80% of the canvas, the
  same box the stroke version fills (0.1 to 0.9 of the unit square), so
  swapping one for the other does not shift the layout.
- **A cut sign, not a picture.** One bold silhouette, as if cut into a
  wooden printing block or struck as a die: heavy main strokes, a few cut
  hatches for weight, chipped and worn edges. No scene, no object study,
  no ground or shadow.
- **Readable at 64px.** No fine hatching that fills in when reduced. If a
  hatch would not survive at 64px, leave it out.
- **Generate black ink on flat, untextured off-white paper.** Paper grain
  or a shadow becomes noise in the alpha channel. The export does the
  keying (see below).
- **No glow, no gradient, no second colour.** The lantern guild emblem
  gets no flame colour; the tint is the whole palette.

## Shared prompt skeleton

> Use case: stylized-concept. Asset type: a single carved sign for a mobile
> expedition RPG, square 1:1 composition, the mark centred and filling the
> central 80% of the frame. Keep the exact silhouette and stroke layout of
> the attached reference mark. **MARK GOES HERE.** Art style: a woodcut or
> die-struck stamp; confident heavy inked strokes, a few sparse cut hatches,
> slightly chipped worn edges, as if cut by hand into a printing block.
> Pure black ink on flat plain off-white paper, no paper texture. Strong
> silhouette that stays readable at 64 pixels. No colour, no gradient, no
> glow, no shadow, no background, no frame, no border, no text,
> typography, numbers, watermark, photorealism, glossy 3D, or decorative
> fantasy ornament. A single mark; no animation.

## The fourteen

### Sectors (a place)

- **`mosswood`** - *a treeline: canopy over a trunk, branches either side.*
  > A single conifer as a cut sign: a pointed canopy chevron, a straight
  > trunk to the base, two shorter branch chevrons lower down.
- **`blackstone`** - *a descent: wedges dropping to a floor.*
  > Two stacked downward chevrons above a heavy horizontal floor bar, like
  > a shaft dropping to its bottom.
- **`cinder`** - *a burned ledger: a volume struck through.*
  > A closed ledger seen face-on, struck through by one heavy diagonal cut,
  > its edges ragged as if scorched. Keep it reading as a book, not a
  > domino: the earlier page-stack version failed exactly that way.
- **`riftline`** - *a split: two halves pulled off the centre line.*
  > A heavy vertical centre line with an angle bracket pulled away on each
  > side, a little cut rock grain on the brackets.
- **`spire`** - *a banded tower with something at the top.*
  > A narrow tapering tower in banded courses, with a pointed cap above
  > the top band.

### Classes (a person)

- **`vanguard`** - *a bulwark: heavy, planted.*
  > A top bar over a deep V, crossed by a short bar: a shield set in the
  > ground.
- **`recon`** - *a dart already moving.*
  > A diagonal arrow rising to the upper right, its head an open corner,
  > two short speed ticks trailing at the lower left.
- **`archivist`** - *an open volume on its spine.*
  > An open book standing on its spine, the two covers angled out.
- **`artificer`** - *a clamp on a rivet.*
  > A small square rivet at the centre, four jaws reaching in to it from
  > the corners.
- **`quartermaster`** - *a balance: no specialism, no bad days.*
  > A diamond with a level crossbar through its middle.

### Guild emblems (the player's company)

These are the player's choice, not game data, and the debrief shows them
at 88px, so they may carry a little more cut detail than the class marks.
The current strokes use round caps; keep their curves.

- **`lantern`** - a hooded field lantern with a cross set into its body.
- **`compass`** - a four-point star with short diagonal ticks between the
  points. A cut mark, not a navigation instrument.
- **`branch`** - a straight stem with two curling leaves.
- **`anvil`** - an anvil on a narrow waist and a flared foot.

## Spoilers

The sector plate's only call site is the unlock acknowledgement, so the
Spire's plate is first seen at the moment the Spire opens, the same gate
as its header. Keep `sectors/spire` out of store listings, marketing and
any gallery outside the game, as for `spire.webp` and the three Spire
salvage plates. `review.html` may show it, behind an explicit spoiler
reveal like the sector headers' review.

## Delivery

Assets go in a new directory, so nothing collides with the sector headers
or with the salvage item `spire_sigil`:

```
assets/art/marks/sectors/<sector id>.webp   mosswood blackstone cinder riftline spire
assets/art/marks/classes/<class id>.webp    vanguard recon archivist artificer quartermaster
assets/art/marks/guild/<GuildSigil name>.webp  lantern compass branch anvil
```

- **512 x 512 WebP with alpha.** Budget about 25 KB each.
- **Colour channels black, alpha from ink.** `export.py` keys the paper
  out: alpha = clamp((paper L - pixel L) / (paper L - ink L)), RGB set to
  black. The app tints with `BlendMode.srcIn`, so only alpha matters.
- Add the three directories to `pubspec.yaml` under `flutter: assets:`.

Design resources, following the other art sets:

- `prompts.md` (this file)
- `generation.json`: the exact image_gen prompts, revisions, references
  and export settings
- `sources/`: the selected full-resolution masters
- `export.py`: keying, resize and WebP encoding with Pillow, same
  command-line shape as `../gear-art/export.py`
- `review.html`: each plate tinted amber (`T.amber`) on the app's card
  colour at 64, 72 and 88px, beside the current stroke mark at 72px and
  24px, so a mismatch in silhouette is obvious

## Code hookup

Mirror `lib/widgets/gear_art.dart`:

- A `MarkPlate` widget in `lib/widgets/mark_plate.dart` with named
  constructors for a sector, a class and a guild emblem, taking `color`
  and `size`. It loads the asset with `color` and
  `colorBlendMode: BlendMode.srcIn`. While loading, and if the file is
  missing, it shows the existing stroke widget (`Sigil`, `ClassEmblem`,
  `GuildEmblem`) at the same size, so dropping in a file is the whole
  installation step. No frame: a tinted mask has no paper rectangle.
- Keep `GuildEmblem`'s semantics label (`'<label> sigil'`).
- Swap only the five call sites in the first table. Raise the emblem
  picker to 64.
- Tests, after `test/gear_art_test.dart`: a missing file falls back to the
  stroke; every sector, class and guild ID maps to its own path; the
  small call sites still use the stroke widgets.
