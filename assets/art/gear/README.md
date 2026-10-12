Seven epic salvage plates, named `<gear id>.webp`:

    ore_sense.webp  quiet_seal.webp  null_core.webp  first_light.webp
    spire_sigil.webp  telos_lens.webp  last_charter.webp

All seven are delivered at **640 x 640, WebP quality 86**, on bone paper.
They use the camp concept and sector headers' shared ink style. First
Light's small flame is the only warm accent; none has a glow.

| File | Bytes |
| --- | ---: |
| `ore_sense.webp` | 33,716 |
| `quiet_seal.webp` | 33,954 |
| `null_core.webp` | 26,960 |
| `first_light.webp` | 31,962 |
| `spire_sigil.webp` | 44,736 |
| `telos_lens.webp` | 39,820 |
| `last_charter.webp` | 29,870 |

The set totals 241,018 bytes, averaging 34.4 kB. The most intricate token
is 44.7 kB, slightly above the approximate 40 KB per-item target.

**Reveal only.** `GearArt` is used only for the player's salvage debrief.
Equipment lists, comparison details and the field manual use `GearMark`.
An item with no plate still falls back to its engraving. The remaining
twelve gear items are listed in `lib/data/content.dart`.

**Endgame spoilers:** `spire_sigil`, `telos_lens` and `last_charter` must
stay out of store listings, galleries and previews outside the player's
own debrief. The review page contains only the other four items, with no
hidden spoiler images or links to spoiler plates.

Design resources in `docs/design/gear-art/`:

- `prompts.md`: original brief and shared style lock.
- `generation.json`: exact built-in image_gen prompts, revision prompts,
  reference, spoiler policy and export settings.
- `sources/`: the seven selected full-resolution generated PNG masters;
  the same spoiler restrictions apply to these files.
- `export.py`: reproducible resize and WebP encoding with Pillow.
- `review.html`: only the four non-spoiler plates, at 88px reveal size or
  264px for inspection.

Run `python docs/design/gear-art/export.py` from the repo root to re-export.
All illustration edits used the built-in image_gen tool; this script only
resizes and encodes the selected masters.
