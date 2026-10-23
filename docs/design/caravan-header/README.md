# Caravan header

Delivered asset: `assets/art/caravan.webp`, **1290 x 726, WebP q86**,
199,264 bytes. The master is approximately 16:9; the intended display is
a centred 2.3:1 cover crop, matching the sector-header treatment.

Three covered freight wagons halt at the timber gate on Mosswood's old
graded service road. The same squat survey posts, low mist and treeline
connect the scene to Mosswood and camp. One small distant gate figure gives
scale. The lead wagon nearest the gate carries the only tiny ochre flame;
the rest of the scene remains neutral. Canvas, gate and posts have no text.

Created and revised using the built-in image_gen tool with
`assets/art/sectors/mosswood.webp` and
`docs/design/camp-study/camp-concept.png` as references. `generation.json`
records the exact prompts, references, selected output and export settings.
`sources/caravan.png` preserves the selected full-resolution master.
`export.py` only resizes and encodes; all creative edits used image_gen.

Open `review.html` to compare the Caravan and Mosswood at phone widths,
with the full frame, intended 2.3:1 crop and a tighter 2.7:1 crop.

## Flutter usage

`lib/widgets/caravan_header.dart` supplies `CaravanHeader`. It uses the
available card width for its default 2.3:1 crop, supports an optional
height override, and collapses if its asset cannot load. The existing
`assets/art/` entry in `pubspec.yaml` bundles the file.

```dart
import '../widgets/caravan_header.dart';

// Above the Caravan card's text, inside its existing border:
const CaravanHeader(),

// The same widget can head the debrief's "With the caravan" beat.
```

The Caravan card and debrief beat do not exist in this checkout yet, so
the widget is prepared but not mounted in those screens. Their existing
visibility conditions should control when it appears once the feature
code is available. The illustration does not itself decide when a caravan
arrives or create new game state.

Re-export from the repo root with:

```sh
python docs/design/caravan-header/export.py
```
