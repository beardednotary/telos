Sector header illustrations, named `<sector id>.webp`:

    mosswood.webp  blackstone.webp  cinder.webp  riftline.webp  spire.webp

All five are delivered at 1290 x 726, WebP quality 86, for centered cover
crops around 2.3:1. The full images retain their approximately 16:9 framing
(726px is the nearest integer height at 1290px wide).

| File | Bytes |
| --- | ---: |
| `mosswood.webp` | 228,668 |
| `blackstone.webp` | 181,580 |
| `cinder.webp` | 229,914 |
| `riftline.webp` | 165,346 |
| `spire.webp` | 103,828 |

The complete set is 909,336 bytes. All files fit the approximate 230 KB
per-image budget (largest: 224.5 KiB).

The existing `SectorHeader` widget loads these automatically. Missing art
still collapses without a placeholder.

**Spire is a spoiler:** never use `spire.webp` in store listings or sector
list thumbnails. Its access review only shows it after sector unlock.

Design resources in `docs/design/sector-headers/`:

- `review.html`: phone-width previews with full, 2.3:1 and 2.7:1 framing;
  the Spire is hidden behind an explicit spoiler reveal.
- `prompts.md`: original brief and shared style lock.
- `generation.json`: exact built-in image_gen prompts, revision prompts,
  reference image and export settings.
- `sources/`: selected full-resolution generated PNG masters.
- `export.py`: reproducible resize and WebP encoding with Pillow.

Run `python docs/design/sector-headers/export.py` from the repo root to
re-export. All illustration edits were made with the built-in image_gen
tool; the export script grades, resizes and encodes. The grade
(`docs/design/grade.py`) matches each header's paper and warmth to the camp
illustration, so the five read as one printing.
