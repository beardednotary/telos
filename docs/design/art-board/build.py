"""Builds the art board: every picture the app shows, at real size, on the
app's own colours, with each painted image measured against the style lock.

    flutter test docs/design/art-board/render_board_test.dart   # code-drawn art
    python docs/design/art-board/build.py                       # this page

Run from the repo root. Writes docs/design/art-board/index.html, plus tinted
copies of the mark plates in renders/marks/. Needs Pillow.

The measurements are the point. Generated sets drift apart in ways that are
hard to see one image at a time and obvious side by side: paper that warms
from set to set, ink that greys, hatching that thickens, colour creeping past
"a tiny ochre accent". Each image's paper and ink are compared with the lock's
own swatches, so a drift is a number rather than an impression.
"""

from __future__ import annotations

import colorsys
import html
import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BOARD = ROOT / "docs/design/art-board"
ART = ROOT / "assets/art"
RENDERS = BOARD / "renders"

# The style lock's swatches (docs/design/camp-study/art-prompt.md).
LOCK_PAPER = (0xE8, 0xE1, 0xCE)
LOCK_INK = (0x20, 0x25, 0x1F)

# The app (lib/theme/telos_theme.dart).
T = {
    "black": "#1E252B", "card": "#272F35", "band": "#12181D",
    "raised": "#313B42", "line": "#4D5E67", "boundary": "#677A83",
    "dim": "#ACBBC1", "text": "#E6EAEB", "amber": "#D3B779",
}
AMBER = (0xD3, 0xB7, 0x79)

# Past these a swatch is flagged. Delta E 76 in CIELAB: about 2.3 is the
# smallest difference most people can see; 8 is plainly a different paper.
PAPER_FLAG = 8.0
INK_FLAG = 12.0

SECTORS = ["mosswood", "blackstone", "cinder", "riftline", "spire"]
CLASSES = ["vanguard", "recon", "archivist", "artificer", "quartermaster"]
GUILD = ["lantern", "compass", "branch", "anvil"]
SPOILER_GEAR = {"spire_sigil", "telos_lens", "last_charter"}

# Gear in the order content.dart lists it: standard by rarity, then caravan.
GEAR = [
    "scav_cord", "mossglass", "hollow_pick", "ash_ledger",
    "field_optic", "slag_brace", "archivist_optic", "rift_anchor",
    "verge_charm", "deep_lamp", "cinder_key", "descent_rig",
    "ore_sense", "quiet_seal", "null_core", "first_light",
    "spire_sigil", "telos_lens", "last_charter",
    "waybill", "road_lantern", "axle_pin", "drover_coat", "slow_watch",
    "gate_seal",
]

# Sample stakes for the scene mockups: the same spread the renders use.
DEPTHS = [0.28, 0.41, 0.52, 0.55, 0.63, 0.78, 0.81, 0.97, 1.12]
LATEST = 1.04


# --------------------------------------------------------------------------
# Measuring
# --------------------------------------------------------------------------

def _lab(rgb):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def delta_e(a, b):
    return math.dist(_lab(a), _lab(b))


def _mean(px):
    n = len(px)
    return tuple(round(sum(p[i] for p in px) / n) for i in range(3))


def measure(path: Path) -> dict:
    # Full detail up to 640px: thin strokes blur into grey when shrunk, and
    # that would read as pale ink.
    im = Image.open(path).convert("RGB")
    im.thumbnail((640, 640))
    raw = im.tobytes()
    px = [tuple(raw[i:i + 3]) for i in range(0, len(raw), 3)]
    lum = sorted((0.2126 * r + 0.7152 * g + 0.0722 * b, (r, g, b)) for r, g, b in px)
    n = len(lum)
    paper = _mean([p for _, p in lum[int(n * 0.90):]])
    # The darkest 1%: a plate drawn with little ink has few solid pixels, and
    # a wider sample would reach into the grey edges of its strokes.
    ink = _mean([p for _, p in lum[: max(1, int(n * 0.01))]])
    lp = 0.2126 * paper[0] + 0.7152 * paper[1] + 0.0722 * paper[2]
    li = 0.2126 * ink[0] + 0.7152 * ink[1] + 0.0722 * ink[2]
    mid = (lp + li) / 2
    coverage = sum(1 for l, _ in lum if l < mid) / n
    warm = 0
    for r, g, b in px:
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if v > 0.25 and s > 0.30 and 20 / 360 <= h <= 60 / 360:
            warm += 1
    return {
        "paper": paper, "ink": ink, "coverage": coverage, "warm": warm / n,
        "paper_de": delta_e(paper, LOCK_PAPER), "ink_de": delta_e(ink, LOCK_INK),
    }


def hexc(rgb):
    return "#%02X%02X%02X" % rgb


# --------------------------------------------------------------------------
# Tinting the mark plates the way the app will (BlendMode.srcIn, amber)
# --------------------------------------------------------------------------

def tint_marks() -> dict[str, str]:
    out = {}
    dest = RENDERS / "marks"
    dest.mkdir(parents=True, exist_ok=True)
    for folder, ids in (("sectors", SECTORS), ("classes", CLASSES), ("guild", GUILD)):
        for i in ids:
            src = ART / "marks" / folder / f"{i}.webp"
            if not src.exists():
                continue
            alpha = Image.open(src).convert("RGBA").getchannel("A")
            tinted = Image.new("RGBA", alpha.size, AMBER + (255,))
            tinted.putalpha(alpha)
            name = f"{folder}-{i}.png"
            tinted.save(dest / name)
            out[f"{folder}/{i}"] = f"renders/marks/{name}"
    return out


# --------------------------------------------------------------------------
# Page
# --------------------------------------------------------------------------

def rel(p: Path) -> str:
    return Path("../../..").joinpath(p.relative_to(ROOT)).as_posix()


def stakes_svg(width=358, height=48, ground=None, on_paper=False):
    """The scene's stakes as a strip: the old company's depth scale, the
    player's earlier runs, and this run's stake. Same geometry as
    SectorScene._stakes."""
    ground = height - 8 if ground is None else ground

    def x(d):
        return width * (0.03 + 0.94 * min(max(d, 0), 1.6) / 1.6)

    def stake(px, tall, colour, w, opacity=1.0):
        top = ground - tall
        return (f'<path d="M{px:.1f} {ground} L{px:.1f} {top} L{px + 7:.1f} {top + 3} '
                f'L{px:.1f} {top + 6}" fill="none" stroke="{colour}" '
                f'stroke-width="{w}" stroke-opacity="{opacity}"/>')

    theirs = LOCK_INK if on_paper else None
    parts = []
    if not on_paper:
        parts.append(f'<line x1="0" y1="{ground}" x2="{width}" y2="{ground}" '
                     f'stroke="{T["line"]}" stroke-width="1.2"/>')
    for d in (0.25, 0.5, 0.75, 1.0):
        parts.append(stake(x(d), 24 if d == 1.0 else 17,
                           hexc(theirs) if theirs else T["dim"], 1.3))
    for i, d in enumerate(DEPTHS):
        rng = random.Random(i * 31 + 7)
        parts.append(stake(x(d) + (rng.random() - 0.5) * 8, 12 + rng.random() * 6,
                           T["amber"], 1.2, 0.5))
    parts.append(stake(x(LATEST), 30, T["amber"], 1.6))
    return (f'<svg class="overlay" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">{"".join(parts)}</svg>')


CSS = f"""
:root {{ color-scheme: dark; }}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: {T['black']}; color: {T['text']};
  font: 15px/1.5 "IBM Plex Sans", system-ui, sans-serif; }}
main {{ max-width: 1240px; margin: 0 auto; padding: 40px 24px 96px; }}
h1 {{ font-size: 30px; margin: 0 0 8px; }}
h2 {{ font-size: 21px; margin: 56px 0 6px; padding-top: 16px;
  border-top: 1px solid {T['line']}; }}
h3 {{ font-size: 15px; margin: 28px 0 10px; color: {T['dim']};
  text-transform: uppercase; letter-spacing: .06em; font-weight: 600; }}
p, li {{ color: {T['dim']}; max-width: 72ch; }}
code {{ font-family: "JetBrains Mono", ui-monospace, monospace; font-size: 13px;
  color: {T['text']}; }}
.grid {{ display: flex; flex-wrap: wrap; gap: 20px; align-items: flex-start; }}
.cell {{ display: flex; flex-direction: column; gap: 6px; }}
.cap {{ font: 12px/1.3 "JetBrains Mono", ui-monospace, monospace; color: {T['dim']}; }}
.phone {{ width: 390px; background: {T['card']}; border: 1px solid {T['boundary']};
  border-radius: 3px; padding: 16px; }}
.phone .cap {{ margin: 4px 0 12px; }}
.cover {{ display: block; width: 358px; object-fit: cover; border-radius: 3px; }}
.frame {{ border: 1px solid {T['boundary']}; display: block; }}
.stack {{ position: relative; width: 358px; }}
.stack .overlay {{ position: absolute; left: 0; bottom: 0; }}
.on-card {{ background: {T['card']}; padding: 16px; border-radius: 3px; }}
table {{ border-collapse: collapse; width: 100%; font-size: 13px; }}
th {{ text-align: left; color: {T['dim']}; font-weight: 600; padding: 6px 10px;
  border-bottom: 1px solid {T['line']}; }}
td {{ padding: 5px 10px; border-bottom: 1px solid {T['raised']};
  font-family: "JetBrains Mono", ui-monospace, monospace; vertical-align: middle; }}
td.name {{ font-family: inherit; }}
.sw {{ display: inline-block; width: 22px; height: 16px; vertical-align: middle;
  border: 1px solid {T['line']}; margin-right: 6px; }}
.flag {{ color: #ED9A94; font-weight: 600; }}
.thumb {{ height: 34px; vertical-align: middle; border-radius: 2px; }}
details {{ margin-top: 16px; }}
summary {{ cursor: pointer; color: {T['amber']}; }}
.pair {{ display: flex; gap: 24px; flex-wrap: wrap; }}
.note {{ border-left: 2px solid {T['amber']}; padding: 2px 0 2px 12px; margin: 12px 0; }}
"""


def img(src, w=None, h=None, cls="", alt=""):
    size = (f' width="{w}"' if w else "") + (f' height="{h}"' if h else "")
    c = f' class="{cls}"' if cls else ""
    return f'<img src="{html.escape(src)}"{size}{c} alt="{html.escape(alt)}" loading="lazy">'


def render(name, cls=""):
    """A render from render_board_test.dart at its logical size (drawn at 3x)."""
    path = RENDERS / name
    if not path.exists():
        return f'<div class="cap">missing render: {html.escape(name)}</div>'
    w, h = Image.open(path).size
    return img(f"renders/{name}", round(w / 3), round(h / 3), cls)


def cell(inner, caption):
    return f'<div class="cell">{inner}<div class="cap">{html.escape(caption)}</div></div>'


def measurements_table(rows):
    out = ['<table><tr><th>Image</th><th>Set</th><th>Paper</th><th>ΔE to lock</th>'
           '<th>Ink</th><th>ΔE to lock</th><th>Ink cover</th><th>Warm colour</th></tr>']
    for r in rows:
        m = r["m"]
        pf = ' class="flag"' if m["paper_de"] > PAPER_FLAG else ""
        inf = ' class="flag"' if m["ink_de"] > INK_FLAG else ""
        thumb = "" if r["spoiler"] else img(r["src"], h=34, cls="thumb")
        name = html.escape(r["name"]) + (" (spoiler)" if r["spoiler"] else "")
        out.append(
            f'<tr><td class="name">{thumb} {name}</td><td class="name">{html.escape(r["set"])}</td>'
            f'<td><span class="sw" style="background:{hexc(m["paper"])}"></span>{hexc(m["paper"])}</td>'
            f'<td{pf}>{m["paper_de"]:.1f}</td>'
            f'<td><span class="sw" style="background:{hexc(m["ink"])}"></span>{hexc(m["ink"])}</td>'
            f'<td{inf}>{m["ink_de"]:.1f}</td>'
            f'<td>{m["coverage"] * 100:.0f}%</td><td>{m["warm"] * 100:.1f}%</td></tr>')
    out.append("</table>")
    return "".join(out)


def set_summary(rows):
    by = {}
    for r in rows:
        by.setdefault(r["set"], []).append(r["m"])
    out = ['<table><tr><th>Set</th><th>Images</th><th>Mean paper</th><th>Paper ΔE range</th>'
           '<th>Mean ink cover</th><th>Mean warm colour</th></tr>']
    for s, ms in by.items():
        paper = _mean([m["paper"] for m in ms])
        des = [m["paper_de"] for m in ms]
        out.append(
            f'<tr><td class="name">{html.escape(s)}</td><td>{len(ms)}</td>'
            f'<td><span class="sw" style="background:{hexc(paper)}"></span>{hexc(paper)}</td>'
            f'<td>{min(des):.1f} to {max(des):.1f}</td>'
            f'<td>{sum(m["coverage"] for m in ms) / len(ms) * 100:.0f}%</td>'
            f'<td>{sum(m["warm"] for m in ms) / len(ms) * 100:.1f}%</td></tr>')
    out.append("</table>")
    return "".join(out)


def scene_options(sector):
    header = rel(ART / "sectors" / f"{sector}.webp")
    sheet = render(f"scene-{sector}-sheet.png")
    debrief = render(f"scene-{sector}-debrief.png")
    a = (f'<div class="phone"><div class="cap">A · today: header, then the drawn scene</div>'
         f'{img(header, 358, 150, "cover")}<div style="height:16px"></div>'
         f'{sheet}<div style="height:12px"></div>'
         f'<div class="cap">debrief, same place</div>{debrief}</div>')
    b = (f'<div class="phone"><div class="cap">B · the painting, then the stakes as a strip</div>'
         f'{img(header, 358, 150, "cover")}<div style="height:10px"></div>'
         f'{stakes_svg()}<div style="height:12px"></div>'
         f'<div class="cap">debrief: the painting is the place, the strip is the run</div>'
         f'{img(header, 358, 100, "cover")}<div style="height:6px"></div>{stakes_svg()}</div>')
    c = (f'<div class="phone"><div class="cap">C · the painting as backdrop, stakes drawn on it</div>'
         f'<div class="stack">{img(header, 358, 150, "cover")}'
         f'{stakes_svg(358, 150, ground=140)}</div><div style="height:12px"></div>'
         f'<div class="cap">the same stakes in the lock\'s ink, for the old company\'s</div>'
         f'<div class="stack">{img(header, 358, 150, "cover")}'
         f'{stakes_svg(358, 150, ground=140, on_paper=True)}</div></div>')
    return f'<div class="grid">{a}{b}{c}</div>'


def build():
    rows = []

    def add(path: Path, set_name: str, spoiler=False):
        if path.exists():
            rows.append({"name": path.stem, "set": set_name, "src": rel(path),
                         "spoiler": spoiler, "m": measure(path)})

    for n in ("camp", "lantern", "onboarding-hourglass", "caravan"):
        add(ART / f"{n}.webp", "Camp & story")
    for s in SECTORS:
        add(ART / "sectors" / f"{s}.webp", "Sector headers", spoiler=s == "spire")
    for g in GEAR:
        add(ART / "gear" / f"{g}.webp", "Salvage plates", spoiler=g in SPOILER_GEAR)

    marks = tint_marks()

    camp = [
        cell(img(rel(ART / "camp.webp"), 358, 184, "cover"), "camp · home, full width × 184"),
        cell(img(rel(ART / "caravan.webp"), 358, 184, "cover"), "caravan · debrief and caravan screen"),
        cell(img(rel(ART / "onboarding-hourglass.webp"), 358, 160, "cover"), "hourglass · onboarding × 160"),
        cell(img(rel(ART / "lantern.webp"), 260, 200), "lantern · launch, 260 × 200"),
    ]
    headers = [cell(img(rel(ART / "sectors" / f"{s}.webp"), 358, 150, "cover"), f"{s} · sector sheet × 150")
               for s in SECTORS if s != "spire"]
    spire_header = cell(img(rel(ART / "sectors/spire.webp"), 358, 150, "cover"), "spire · after unlock only")

    def gear_cell(g):
        return cell(img(rel(ART / "gear" / f"{g}.webp"), 124, 124, "frame"), f"{g} · 124")
    gear_open = [gear_cell(g) for g in GEAR if g not in SPOILER_GEAR]
    gear_spoil = [gear_cell(g) for g in GEAR if g in SPOILER_GEAR]

    def mark_cells(folder, ids, size, hide=()):
        shown, hidden = [], []
        for i in ids:
            src = marks.get(f"{folder}/{i}")
            if not src:
                continue
            c = cell(img(src, size, size), f"{i} · {size}")
            (hidden if i in hide else shown).append(c)
        return shown, hidden
    sec_marks, sec_hidden = mark_cells("sectors", SECTORS, 72, hide={"spire"})
    cls_marks, _ = mark_cells("classes", CLASSES, 72)
    gld_marks, _ = mark_cells("guild", GUILD, 88)

    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Telos art board</title><style>{CSS}</style></head><body><main>
<h1>Telos art board</h1>
<p>Every picture the app shows, at the size it is shown, on the app's own colours.
The test is whether it reads as one world drawn by one hand. Built by
<code>docs/design/art-board/build.py</code>; code-drawn art is rendered by
<code>render_board_test.dart</code> beside it. Spoilers sit behind reveals.</p>

<h2>1 · Measured against the style lock</h2>
<p>Paper and ink are sampled from each image (the lightest 10% and darkest 1% of
pixels) and compared with the lock's swatches: paper
<span class="sw" style="background:{hexc(LOCK_PAPER)}"></span><code>{hexc(LOCK_PAPER)}</code>,
ink <span class="sw" style="background:{hexc(LOCK_INK)}"></span><code>{hexc(LOCK_INK)}</code>.
ΔE is the colour distance: under about 2 is invisible, past
{PAPER_FLAG:.0f} for paper or {INK_FLAG:.0f} for ink is flagged in red. <em>Ink cover</em> is how much
of the image is on the dark side, a proxy for hatching density. <em>Warm colour</em> is the share
of clearly ochre-to-amber pixels; the lock allows a tiny accent.</p>
<h3>By set</h3>
{set_summary(rows)}
<h3>Every image</h3>
{measurements_table(rows)}

<h2>2 · Camp and story</h2>
<div class="grid">{''.join(camp)}</div>

<h2>3 · Sector headers</h2>
<div class="grid">{''.join(headers)}</div>
<details><summary>Show the Spire (spoiler)</summary><div class="grid">{spire_header}</div></details>

<h2>4 · Salvage plates</h2>
<p>As the debrief and detail sheet frame them: 124px with the boundary line.</p>
<div class="grid on-card">{''.join(gear_open)}</div>
<details><summary>Show the three Spire pieces (spoilers)</summary>
<div class="grid on-card">{''.join(gear_spoil)}</div></details>

<h2>5 · Marks: plates and strokes</h2>
<p>The plates tinted amber the way the app will draw them, above the strokes that stay
below 56px. The same sign should read at both sizes.</p>
<h3>Sector sigils</h3>
<div class="grid on-card">{''.join(sec_marks)}</div>
<details><summary>Show the Spire's plate (spoiler)</summary><div class="grid on-card">{''.join(sec_hidden)}</div></details>
<div class="on-card" style="margin-top:12px">{render('strokes-sectors.png')}</div>
<h3>Class emblems</h3>
<div class="grid on-card">{''.join(cls_marks)}</div>
<div class="on-card" style="margin-top:12px">{render('strokes-classes.png')}</div>
<h3>Guild emblems</h3>
<div class="grid on-card">{''.join(gld_marks)}</div>
<div class="on-card" style="margin-top:12px">{render('strokes-guild.png')}</div>
<h3>Camp marks (section headers, 23px)</h3>
<div class="on-card">{render('strokes-camp.png')}</div>

<h2>6 · Line drawings that carry data</h2>
<p>These stay drawn because they show the player's own history: stakes at the depth each run
reached, and floors raised on the Spire.</p>
<h3>Spire screen</h3>
<div class="phone">{render('spire-drawing.png')}</div>

<h2>7 · Same place, two styles: the options</h2>
<p>Today the sector sheet shows the painted header and, directly under it, the drawn scene of the
same place; dispatch does the same at a smaller size. Three ways out, mocked with the real
header and the real stake geometry (sample runs). Spire left out: its header is a spoiler.</p>
<div class="note"><p><strong>A</strong> is today. <strong>B</strong> keeps the painting as the
place and turns the scene into a strip of stakes: no new art, and the amber stays on charcoal
where it reads. <strong>C</strong> draws the stakes on the painting: it needs new side-on
paintings with a clear strip of ground for the stakes to stand on, and the stakes recoloured
for paper.</p></div>
<h3>Mosswood Verge</h3>{scene_options('mosswood')}
<h3>Blackstone Hollow</h3>{scene_options('blackstone')}
<h3>Riftline Descent</h3>{scene_options('riftline')}

<h2>8 · What to look for</h2>
<ul>
<li>Paper that changes from set to set: a warmer cream here, a greyer stone there.</li>
<li>Hatching density that jumps: one set sparse, the next cross-hatched dark.</li>
<li>The same chipped edge or grain stamped onto everything, whatever it is.</li>
<li>Backgrounds busier than the subject.</li>
<li>Mushy small detail: rope, buckles, hinges, and especially marks that look like writing.</li>
<li>Light from different directions in images that sit together.</li>
<li>Colour past the lock: the only warm note is a small flat ochre, and only on a flame.</li>
</ul>
</main></body></html>
"""
    (BOARD / "index.html").write_text(page, encoding="utf-8")
    return rows


if __name__ == "__main__":
    rows = build()
    flagged = [r["name"] for r in rows if r["m"]["paper_de"] > PAPER_FLAG or r["m"]["ink_de"] > INK_FLAG]
    print(f"index.html written: {len(rows)} images measured, {len(flagged)} flagged")
    for r in rows:
        m = r["m"]
        print(f'{r["set"]:<16} {r["name"]:<22} paper {hexc(m["paper"])} dE {m["paper_de"]:5.1f}  '
              f'ink {hexc(m["ink"])} dE {m["ink_de"]:5.1f}  cover {m["coverage"]*100:4.0f}%  warm {m["warm"]*100:5.1f}%')
