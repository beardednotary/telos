All nineteen salvage plates, named `<gear id>.webp`, are delivered at
**640 x 640, WebP quality 86**, on bone paper. They use the camp concept
and sector headers' shared ink style.

The twelve standard discoveries use rarity to control visual complexity:
commons are plain objects with abundant paper; uncommons have a useful
working feature; rares carry mechanism or the specific oddity in their
brief. First Light and Deep Lamp have the only warm accents, confined to
their small flames. Neither casts a glow.

| File | Rarity | Bytes |
| --- | --- | ---: |
| `scav_cord.webp` | Common | 15,768 |
| `mossglass.webp` | Common | 13,782 |
| `hollow_pick.webp` | Common | 10,254 |
| `ash_ledger.webp` | Common | 19,546 |
| `field_optic.webp` | Uncommon | 25,452 |
| `slag_brace.webp` | Uncommon | 25,914 |
| `archivist_optic.webp` | Uncommon | 17,912 |
| `rift_anchor.webp` | Uncommon | 23,482 |
| `verge_charm.webp` | Rare | 23,294 |
| `deep_lamp.webp` | Rare | 21,282 |
| `cinder_key.webp` | Rare | 19,124 |
| `descent_rig.webp` | Rare | 18,026 |
| `ore_sense.webp` | Epic | 33,716 |
| `quiet_seal.webp` | Epic | 33,954 |
| `null_core.webp` | Epic | 26,960 |
| `first_light.webp` | Epic | 31,962 |
| `spire_sigil.webp` | Epic | 44,736 |
| `telos_lens.webp` | Epic | 39,820 |
| `last_charter.webp` | Epic | 29,870 |

The twelve standard plates total **233,836 bytes**, averaging 19.5 kB;
all are below the approximate 40 KB target. The complete nineteen total
474,854 bytes. The previously delivered epic token remains 44.7 kB,
slightly above that approximate target.

**Reveal only.** `GearArt` loads these files by gear ID in the player's
salvage debrief, currently at 124px. The directory is already bundled in
`pubspec.yaml`. Equipment lists, comparison details and the field manual
use `GearMark`. Missing art still falls back to its engraving.

**Endgame spoilers:** `spire_sigil`, `telos_lens` and `last_charter` must
stay out of store listings, galleries and previews outside the player's
own debrief. The review page contains only the sixteen non-spoiler items,
with no hidden spoiler images or links to spoiler plates.

Design resources in `docs/design/gear-art/`:

- `prompts.md`: original briefs and shared style lock.
- `generation.json`: exact built-in image_gen prompts, revision prompts,
  references, spoiler policy and export settings.
- `sources/`: nineteen selected full-resolution generated PNG masters;
  the same spoiler restrictions apply to these files.
- `export.py`: reproducible resize and WebP encoding with Pillow.
- `review.html`: sixteen non-spoiler plates grouped by rarity, at the
  current 124px reveal size, 248px for inspection or 88px as a small check.

Run `python docs/design/gear-art/export.py` from the repo root to re-export
all plates, or append gear IDs to export only selected items. For example:

```sh
python docs/design/gear-art/export.py scav_cord deep_lamp
```

All generation and illustration edits used the built-in image_gen tool;
the export script only resizes and encodes the selected masters. Original
tool outputs are preserved in the local `.codex/generated_images` folder.
