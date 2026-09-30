"""Renders the favicon rasters from the drawn marks (task brand:favicons).

Runs in the QA image (site/tests/browser/Dockerfile) with the repo at
/work/repo and no network; Chromium, driven by Playwright, is the rasteriser.
Reads the two drawn sources and writes, into site/static/:

  favicon-16x16.png, favicon-32x32.png   favicon.svg (the mark on its rounded
                                         tile), transparent outside the tile
  favicon.ico                            16, 32 and 48 px PNG frames of
                                         favicon.svg, packed with struct
  apple-touch-icon.png (180)             images/opm-mark-dark.svg on a full-bleed
  android-chrome-192x192.png             #0a0a0a square, its drawn extent at
  android-chrome-512x512.png             60% of the icon, centred; opaque

The outputs are committed and never hand-edited: redraw the SVGs, then rerun
the task. Chromium's output can differ between runs, so no check compares
their bytes.
"""

import base64
import pathlib
import struct
import sys

from playwright.sync_api import sync_playwright

STATIC = pathlib.Path("/work/repo/site/static")
TILE = "#0a0a0a"
# The mark's drawn extent is 20 of its 24 viewBox units; the opaque icons show
# that extent at 60% of their width.
EXTENT = 20 / 24
OPAQUE_SHARE = 0.6


def data_uri(path):
    return "data:image/svg+xml;base64," + base64.b64encode(path.read_bytes()).decode()


def render(browser, html, size, transparent):
    page = browser.new_page(viewport={"width": size, "height": size}, device_scale_factor=1)
    page.set_content(html)
    page.wait_for_function("Array.from(document.images).every(i => i.complete && i.naturalWidth > 0)")
    png = page.screenshot(omit_background=transparent)
    page.close()
    return png


def tiled(browser, svg, size):
    """favicon.svg at size x size px, transparent outside its tile."""
    html = ('<!doctype html><style>html,body{margin:0;background:transparent}img{display:block}</style>'
            f'<img src="{svg}" width="{size}" height="{size}">')
    return render(browser, html, size, True)


def opaque(browser, svg, size):
    """The mark centred on a full-bleed tile-coloured square, no alpha."""
    box = OPAQUE_SHARE * size / EXTENT
    html = ('<!doctype html><style>html,body{margin:0;height:100%}'
            f'body{{background:{TILE};display:flex;align-items:center;justify-content:center}}</style>'
            f'<img src="{svg}" style="width:{box}px;height:{box}px">')
    return render(browser, html, size, False)


def ico(frames):
    """An ICO file holding PNG frames: ICONDIR, one ICONDIRENTRY each, the PNGs."""
    head = struct.pack("<HHH", 0, 1, len(frames))
    offset = len(head) + 16 * len(frames)
    entries, blobs = b"", b""
    for size, png in frames:
        dim = 0 if size >= 256 else size  # 0 means 256 in an ICONDIRENTRY
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset)
        blobs += png
        offset += len(png)
    return head + entries + blobs


def main():
    favicon = data_uri(STATIC / "favicon.svg")
    mark = data_uri(STATIC / "images" / "opm-mark-dark.svg")
    with sync_playwright() as p:
        browser = p.chromium.launch()
        for size in (16, 32):
            (STATIC / f"favicon-{size}x{size}.png").write_bytes(tiled(browser, favicon, size))
        frames = [(size, tiled(browser, favicon, size)) for size in (16, 32, 48)]
        (STATIC / "favicon.ico").write_bytes(ico(frames))
        (STATIC / "apple-touch-icon.png").write_bytes(opaque(browser, mark, 180))
        for size in (192, 512):
            (STATIC / f"android-chrome-{size}x{size}.png").write_bytes(opaque(browser, mark, size))
        browser.close()
    print("brand:favicons: OK -> site/static/ (favicon-16x16.png, favicon-32x32.png, favicon.ico,"
          " apple-touch-icon.png, android-chrome-192x192.png, android-chrome-512x512.png)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
