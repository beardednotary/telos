"""One colour grade for every painted scene, applied at export.

The headers and story scenes were generated one at a time, and their paper
and warmth drifted apart: the art board (docs/design/art-board/) measured
Cinder's paper as plainly darker and yellower than the camp's, the caravan's
as greyer, and Cinder, Blackstone and the hourglass as two to three times as
warm as the camp, where the style lock allows only a tiny ochre accent.

The target is the camp illustration, not the lock's hex values. The camp is
the approved reference, and the scenes already cluster around its paper; the
lock's #E8E1CE is a prompt number that no scene ever came out at. Grading to
it would repaint the camp too.

Two steps, both measured from the image itself, so a regenerated master gets
the same correction without anyone retuning numbers:

1. Paper. Each channel is stretched so the image's own paper lands on the
   camp's, with its own ink held where it is. Ink is not moved: every scene
   comes out near-black, and lifting it to the lock's charcoal would flatten
   the contrast the art depends on.
2. Warmth, only where an asset asks for it. Saturation is pulled down on warm
   hues (ochre to amber) until the share of clearly warm pixels is no more
   than the camp's. Cool hues, and the image's darks and lights, are left
   alone.

Masters are never touched; this runs between loading a master and resizing it.
"""

from __future__ import annotations

import numpy as np
from PIL import Image

# The camp master's paper (docs/design/camp-study/camp-concept.png), sampled
# the way the art board samples: the mean of its lightest 10% of pixels.
TARGET_PAPER = np.array([0xDE, 0xD2, 0xB7], dtype=np.float64)

# The camp master's share of clearly warm pixels, as the art board measures
# it: hue 20-60 degrees, saturation over 0.30, value over 0.25.
CAMP_WARM = 0.125

# Per asset, by its path under the repo root. Absent: not graded.
GRADES: dict[str, dict] = {
    "assets/art/sectors/mosswood.webp": {},
    "assets/art/sectors/blackstone.webp": {"warm_cap": CAMP_WARM},
    "assets/art/sectors/cinder.webp": {"warm_cap": CAMP_WARM},
    "assets/art/sectors/riftline.webp": {},
    "assets/art/sectors/spire.webp": {},
    "assets/art/caravan.webp": {},
    "assets/art/onboarding-hourglass.webp": {"warm_cap": CAMP_WARM},
}


def _luma(a: np.ndarray) -> np.ndarray:
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def _paper_and_ink(a: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    flat = a.reshape(-1, 3)
    order = np.argsort(_luma(flat))
    n = len(order)
    paper = flat[order[int(n * 0.90):]].mean(axis=0)
    ink = flat[order[: max(1, int(n * 0.01))]].mean(axis=0)
    return paper, ink


def _hsv(a: np.ndarray):
    """RGB 0-255 to hue (0-1), saturation, value: vectorised colorsys."""
    rgb = a / 255.0
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.where(mx > 0, mx, 1), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    safe = np.where(d > 0, d, 1)
    h = np.select(
        [d == 0, mx == r, mx == g],
        [0.0, ((g - b) / safe) % 6, (b - r) / safe + 2],
        (r - g) / safe + 4,
    ) / 6.0
    return h, s, mx


def warm_share(a: np.ndarray) -> float:
    h, s, v = _hsv(a)
    warm = (v > 0.25) & (s > 0.30) & (h >= 20 / 360) & (h <= 60 / 360)
    return float(warm.mean())


def _desaturate_warm(a: np.ndarray, factor: float) -> np.ndarray:
    """Scale saturation by [factor] on warm hues, easing out over 10 degrees
    either side so no hue boundary shows as an edge."""
    h, s, v = _hsv(a)
    deg = h * 360
    core = (deg >= 15) & (deg <= 65)
    edge = np.clip(1 - np.minimum(np.abs(deg - 15), np.abs(deg - 65)) / 10, 0, 1)
    weight = np.where(core, 1.0, np.where((deg > 5) & (deg < 75), edge, 0.0))
    # Only colour, not paper: bone paper is itself a pale warm hue (the
    # camp's sits at saturation 0.18), and greying it would undo step 1.
    # Full effect from 0.35, none at 0.20 or below.
    weight = weight * np.clip((s - 0.20) / 0.15, 0, 1)
    scale = 1 - weight * (1 - factor)
    # Pull each pixel toward its own grey at the same value: saturation
    # scales, brightness does not.
    grey = v[..., None] * 255.0
    return grey + (a - grey) * scale[..., None]


def grade_array(a: np.ndarray, warm_cap: float | None = None) -> np.ndarray:
    paper, ink = _paper_and_ink(a)
    span = np.maximum(paper - ink, 1.0)
    out = ink + (a - ink) * (TARGET_PAPER - ink) / span
    out = np.clip(out, 0, 255)

    if warm_cap is not None:
        # Measure on a small copy, the way the art board does, then apply the
        # least desaturation that meets the cap.
        small = Image.fromarray(out.astype(np.uint8))
        small.thumbnail((640, 640))
        probe = np.asarray(small, dtype=np.float64)
        if warm_share(probe) > warm_cap:
            lo, hi = 0.0, 1.0
            for _ in range(14):
                mid = (lo + hi) / 2
                if warm_share(_desaturate_warm(probe, mid)) > warm_cap:
                    hi = mid
                else:
                    lo = mid
            out = np.clip(_desaturate_warm(out, lo), 0, 255)
    return out


def apply(asset: str, image: Image.Image) -> Image.Image:
    """The graded image for [asset], or [image] unchanged if it has no grade."""
    if asset not in GRADES:
        return image
    a = np.asarray(image.convert("RGB"), dtype=np.float64)
    out = grade_array(a, **GRADES[asset])
    return Image.fromarray(np.round(out).astype(np.uint8), "RGB")
