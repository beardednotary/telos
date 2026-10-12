Sector header illustrations, named `<sector id>.webp`:

    mosswood.webp  blackstone.webp  cinder.webp  riftline.webp  spire.webp

All five are delivered at 1290 x 726, WebP quality 86, for centered cover
crops around 2.3:1. The full images retain their approximately 16:9 framing
(726px is the nearest integer height at 1290px wide).

| File | Bytes |
| --- | ---: |
| `mosswood.webp` | 231,198 |
| `blackstone.webp` | 183,796 |
| `cinder.webp` | 228,142 |
| `riftline.webp` | 166,194 |
| `spire.webp` | 103,676 |

The complete set is 913,006 bytes. All files fit the approximate 230 KB
per-image budget (largest: 225.8 KiB).

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
tool; the export script only resizes and encodes.
