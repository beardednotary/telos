# Onboarding hourglass

Delivered asset: `assets/art/onboarding-hourglass.webp`, **1290 x 726,
WebP quality 86**, 209,384 bytes. The full landscape frame is approximately
16:9, with the hourglass and empty stool held in the central band.

A plain wooden-framed hourglass stands on an upturned supply crate. Its
sand is mid-fall, with the lower bulb about a third full. An empty folding
camp stool sits beside it, turned away. Two small distant figures walk
along the old graded road toward low mist and a treeline. Nobody stands
near the hourglass.

Generated and reframed with the built-in image_gen tool. The camp concept
and Mosswood header were style and palette references, not edit targets.
`generation.json` preserves the exact prompts, reference paths, selected
output and export settings. `sources/onboarding-hourglass.png` is the
selected full-resolution PNG master; the original tool output is also
preserved in `.codex/generated_images`.

`review.html` shows the full frame and an optional centred 2.3:1 crop at
phone width. The existing `assets/art/` entry in `pubspec.yaml` bundles the
image. This delivery supplies the illustration for the onboarding page.

Re-export with:

```sh
python docs/design/onboarding-hourglass/export.py
```

The export script only resizes and encodes with the sector-header settings.
All illustration and composition edits used image_gen.
