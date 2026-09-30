"""Renders the Open Graph card (task brand:og).

Runs in the QA image (site/tests/browser/Dockerfile) with the repo at
/work/repo and no network. Fills site/tools/og-card.html with the site's
title and params.description from site/config/_default/hugo.toml, the mark
from site/static/images/opm-mark-dark.svg, and Geist and Geist Mono from
site/static/fonts/, then screenshots it at 1200x630 into
site/static/images/og-default.png.

The card is committed and never hand-edited: rerun the task when the title,
the description or the mark changes.
"""

import base64
import html
import pathlib
import string
import sys
import tomllib

from playwright.sync_api import sync_playwright

SITE = pathlib.Path("/work/repo/site")
TEMPLATE = SITE / "tools" / "og-card.html"
OUT = SITE / "static" / "images" / "og-default.png"


def font(name):
    data = (SITE / "static" / "fonts" / name).read_bytes()
    return "data:font/woff2;base64," + base64.b64encode(data).decode()


def main():
    config = tomllib.loads((SITE / "config" / "_default" / "hugo.toml").read_text())
    title = config["title"]
    description = config["params"]["description"]
    card = string.Template(TEMPLATE.read_text()).substitute(
        title=html.escape(title),
        description=html.escape(description),
        mark=(SITE / "static" / "images" / "opm-mark-dark.svg").read_text().strip(),
        geist=font("Geist-Variable.woff2"),
        geist_mono=font("GeistMono-Variable.woff2"),
    )
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1200, "height": 630}, device_scale_factor=1)
        page.set_content(card)
        page.evaluate("document.fonts.ready")
        loaded = page.evaluate("[...document.fonts].filter(f => f.status === 'loaded').map(f => f.family)")
        if not {"Geist", "Geist Mono"} <= {f.strip('"') for f in loaded}:
            print(f"brand:og: FAILED, fonts not loaded: {loaded}")
            return 1
        page.screenshot(path=str(OUT))
        browser.close()
    print(f"brand:og: OK -> site/static/images/og-default.png ({title!r})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
