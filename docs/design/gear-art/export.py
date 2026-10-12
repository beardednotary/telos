"""Export the selected salvage plates. Requires Pillow with WebP support.

Run: python docs/design/gear-art/export.py [gear_id ...]
Omit IDs to export all plates; provide IDs to export only selected items.
Only resizes and encodes; all illustration edits used built-in image_gen.
No gallery or preview is generated, including for the three spoiler items.
"""

import argparse
import json
from pathlib import Path

from PIL import Image


study = Path(__file__).resolve().parent
root = study.parents[2]
manifest = json.loads((study / "generation.json").read_text(encoding="utf-8"))
settings = manifest["export"]
size = (settings["width"], settings["height"])
total = 0
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("ids", nargs="*", help="Gear IDs to export; default: all")
args = parser.parse_args()
known_ids = {asset["id"] for asset in manifest["assets"]}
unknown_ids = set(args.ids) - known_ids
if unknown_ids:
    parser.error(f"Unknown gear IDs: {', '.join(sorted(unknown_ids))}")
assets = [
    asset for asset in manifest["assets"]
    if not args.ids or asset["id"] in args.ids
]

for asset in assets:
    source = study / asset["source"]
    destination = root / asset["asset"]
    with Image.open(source) as master:
        if master.width != master.height:
            raise ValueError(f"Expected a square master: {source}")
        exported = master.convert("RGB").resize(
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
    # The brief budgets about 40 KB. Allow up to 45 KB for intricate plates.
    if byte_count > 45_000:
        raise ValueError(f"Over the approximate 40 KB budget: {destination} ({byte_count} bytes)")
    total += byte_count
    print(f"{destination.relative_to(root)}: {size[0]} x {size[1]}, q86, {byte_count:,} bytes")

print(f"{len(assets)}-plate total: {total:,} bytes")
