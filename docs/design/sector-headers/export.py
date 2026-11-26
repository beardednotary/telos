"""Export the selected generated masters. Requires Pillow with WebP support.

Run from any directory: python docs/design/sector-headers/export.py
Grades, resizes and encodes; all illustration and reframing used image_gen.
The grade (../grade.py) matches paper and warmth to the camp illustration.
"""

import json
import sys
from pathlib import Path

from PIL import Image


study = Path(__file__).resolve().parent
sys.path.insert(0, str(study.parent))
import grade  # noqa: E402

root = study.parents[2]
manifest = json.loads((study / "generation.json").read_text(encoding="utf-8"))
settings = manifest["export"]
size = (settings["width"], settings["height"])

for asset in manifest["assets"]:
    source = study / asset["source"]
    destination = root / asset["asset"]
    with Image.open(source) as master:
        if abs(master.width / master.height - 16 / 9) > 0.005:
            raise ValueError(f"Expected a 16:9 master: {source}")
        graded = grade.apply(asset["asset"], master.convert("RGB"))
        exported = graded.resize(
            size, getattr(Image.Resampling, settings["resampling"])
        )
        exported.save(
            destination,
            format="WEBP",
            quality=settings["quality"],
            method=settings["method"],
            lossless=settings["lossless"],
        )
    with Image.open(destination) as check:
        check.load()
        assert check.size == size and check.format == "WEBP"
    byte_count = destination.stat().st_size
    if byte_count > 230 * 1024:
        raise ValueError(f"Over the approximate 230 KB budget: {destination} ({byte_count} bytes)")
    print(f"{destination.relative_to(root)}: {size[0]} x {size[1]}, q86, {byte_count:,} bytes")
