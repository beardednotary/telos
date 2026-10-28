"""Build the hosted privacy policy page from the text the app bundles.

    python3 tool/privacy_page.py

Reads assets/legal/privacy_policy.txt and writes docs/privacy/index.html, a
single self-contained file to upload to dahvio.com/telos/privacy. It loads
nothing from anywhere else: a privacy page that calls a font or analytics
server would contradict itself. test/privacy_policy_test.dart fails if the
page and the app's text drift apart, so re-run this after any edit.
"""

from html import escape
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/legal/privacy_policy.txt"
OUTPUT = ROOT / "docs/privacy/index.html"

# The app's Night Watch palette (lib/theme/telos_theme.dart).
STYLE = """
  :root { color-scheme: dark; }
  body {
    margin: 0; background: #1E252B; color: #E6EAEB;
    font: 17px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      "Helvetica Neue", Arial, sans-serif;
  }
  main { max-width: 680px; margin: 0 auto; padding: 48px 20px 64px; }
  h1 { font-size: 34px; line-height: 1.2; margin: 0 0 6px; }
  h2 { font-size: 21px; margin: 40px 0 4px; }
  .date, footer { color: #ACBBC1; }
  ul { padding-left: 1.2em; }
  li { margin: 10px 0; }
  li::marker { color: #D3B779; }
  a { color: #D3B779; }
  footer { margin-top: 48px; padding-top: 16px; border-top: 1px solid #4D5E67;
    font-size: 15px; }
"""


def text(s):
    # Quotes stay literal so the test can match the app's text directly.
    return escape(s, quote=False)


def build():
    chunks = [c.strip() for c in re.split(r"\n\s*\n",
              SOURCE.read_text(encoding="utf-8").replace("\r\n", "\n").strip())]
    title, effective = [line.strip() for line in chunks[0].split("\n")[:2]]
    body = [f"<h1>{text(title)}</h1>", f'<p class="date">{text(effective)}</p>']
    for chunk in chunks[1:]:
        if chunk.startswith("## "):
            body.append(f"<h2>{text(chunk[3:].strip())}</h2>")
        elif chunk.startswith("- "):
            items = "".join(f"<li>{text(line.strip()[2:].strip())}</li>"
                            for line in chunk.split("\n"))
            body.append(f"<ul>{items}</ul>")
        else:
            body.append(f"<p>{text(' '.join(chunk.split(chr(10))))}</p>")
    body = "\n".join(body).replace(
        "telos@dahvio.com", '<a href="mailto:telos@dahvio.com">telos@dahvio.com</a>')
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{text(title)}</title>
<style>{STYLE}</style>
</head>
<body>
<main>
{body}
<footer>This page loads nothing from any other server.</footer>
</main>
</body>
</html>
"""


if __name__ == "__main__":
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(build(), encoding="utf-8", newline="\n")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
