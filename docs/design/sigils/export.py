"""Export the ink masks. Requires Pillow with WebP support.

Run: python docs/design/sigils/export.py [sectors/mosswood classes/recon ...]
Omit IDs to export all fourteen plates. Only keys, resizes and encodes;
all illustration work used built-in image_gen. Does not generate a gallery.
"""

import argparse
import json
from pathlib import Path

from PIL import Image


def main():
    study = Path(__file__).resolve().parent
    root = study.parents[2]
    manifest = json.loads((study / "generation.json").read_text(encoding="utf-8"))
    settings = manifest["export"]
    size = (settings["width"], settings["height"])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ids", nargs="*", help="Mark IDs, e.g. guild/lantern; default: all")
    args = parser.parse_args()
    known = {asset["id"] for asset in manifest["assets"]}
    if unknown := set(args.ids) - known:
        parser.error(f"Unknown mark IDs: {', '.join(sorted(unknown))}")

    paper, ink = settings["paper_luminance"], settings["ink_luminance"]
    if not 0 <= ink < paper <= 255:
        raise ValueError("Expected 0 <= ink L < paper L <= 255")
    # Clipped endpoints remove the light paper and make the dark ink solid.
    # Values between them preserve antialiased edges and broad carved cuts.
    lut = [round(255 * max(0, min(1, (paper - value) / (paper - ink))))
           for value in range(256)]
    assets = [asset for asset in manifest["assets"]
              if not args.ids or asset["id"] in args.ids]
    total = 0
    for asset in assets:
        source = study / asset["source"]
        destination = root / asset["asset"]
        with Image.open(source) as master:
            if master.width != master.height:
                raise ValueError(f"Expected a square master: {source}")
            alpha = master.convert("L").point(lut).resize(
                size, getattr(Image.Resampling, settings["resampling"]))
        exported = Image.new("RGBA", size, (*settings["rgb"], 0))
        exported.putalpha(alpha)
        destination.parent.mkdir(parents=True, exist_ok=True)
        exported.save(destination, format="WEBP", quality=settings["quality"],
                      method=settings["method"], lossless=settings["lossless"],
                      alpha_quality=100, exact=True)
        with Image.open(destination) as check:
            check.load()
            assert check.size == size and check.format == "WEBP"
            assert check.mode == "RGBA", f"Missing alpha: {destination}"
            assert check.convert("RGB").getextrema() == ((0, 0),) * 3
            assert check.getchannel("A").getextrema() == (0, 255)
            assert check.getchannel("A").crop((0, 0, size[0], 16)).getbbox() is None
        byte_count = destination.stat().st_size
        if byte_count > settings["max_bytes"]:
            raise ValueError(f"Over 25 KB budget: {destination} ({byte_count:,} bytes)")
        total += byte_count
        print(f"{asset['asset']}: {size[0]} x {size[1]}, black RGB + alpha, {byte_count:,} bytes")
    print(f"{len(assets)}-plate total: {total:,} bytes")


if __name__ == "__main__":
    main()
