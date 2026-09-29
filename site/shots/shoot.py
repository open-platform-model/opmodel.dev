"""Screenshots every figure on the built site (task shots).

Serves site/dist over HTTP inside the container, opens every page of the
latest version that holds a figure (a <figure> with an <svg role="img">), and
saves each figure in six variants to /out/<page>/<n>-<variant>.png: light and
dark at desktop width, the two cases where the site's theme switch and the OS
setting disagree, and light and dark at phone width.

It also prints each figure's smallest effective text size at phone width. A
figure drawn wider than the phone scales its text down, and below 9 px it is
unreadable; the run fails then.
"""

import functools
import http.server
import json
import pathlib
import sys
import threading

from playwright.sync_api import sync_playwright

SITE = pathlib.Path("/site")
OUT = pathlib.Path("/out")
MIN_TEXT_PX = 9

VARIANTS = [
    # name, viewport width, site theme switch, OS colour scheme
    ("light", 1280, "light", "light"),
    ("dark", 1280, "dark", "dark"),
    ("switch-dark-os-light", 1280, "dark", "light"),
    ("switch-light-os-dark", 1280, "light", "dark"),
    ("phone-light", 390, "light", "light"),
    ("phone-dark", 390, "dark", "dark"),
]

FIGURES = 'figure:has(svg[role="img"])'

# Sticky headers would cover the top of a tall figure in an element screenshot.
UNSTICK = """() => {
  for (const el of document.querySelectorAll('*')) {
    const p = getComputedStyle(el).position
    if (p === 'fixed' || p === 'sticky') el.style.position = 'static'
  }
}"""

# Smallest rendered text size in the figure: font size times the SVG's scale.
MIN_TEXT = """(figure) => {
  let min = Infinity
  for (const t of figure.querySelectorAll('svg text')) {
    const m = t.getScreenCTM()
    if (!m) continue
    const px = parseFloat(getComputedStyle(t).fontSize) * Math.hypot(m.a, m.b)
    if (px < min) min = px
  }
  return min
}"""


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def main():
    dist = SITE / "dist"
    latest = json.loads((SITE / "src/generated/versions.json").read_text())["latest"]
    handler = functools.partial(Quiet, directory=str(dist))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_address[1]}"

    pages = []
    for html in sorted((dist / latest).rglob("index.html")):
        text = html.read_text(errors="ignore")
        if "<figure" in text and 'role="img"' in text:
            pages.append("/" + html.parent.relative_to(dist).as_posix() + "/")
    if not pages:
        print(f"no figures found under dist/{latest}")
        return 0

    too_small = []
    with sync_playwright() as p:
        browser = p.chromium.launch()
        for url in pages:
            slug = url.strip("/").replace("/", "_")
            (OUT / slug).mkdir(parents=True, exist_ok=True)
            for name, width, theme, scheme in VARIANTS:
                ctx = browser.new_context(viewport={"width": width, "height": 900}, color_scheme=scheme)
                ctx.add_init_script(f"localStorage.setItem('starlight-theme', '{theme}')")
                page = ctx.new_page()
                page.goto(base + url, wait_until="networkidle")
                page.evaluate(UNSTICK)
                figures = page.locator(FIGURES)
                count = figures.count()
                for i in range(count):
                    fig = figures.nth(i)
                    fig.screenshot(path=str(OUT / slug / f"{i + 1}-{name}.png"))
                    if name == "phone-light":
                        px = fig.evaluate(MIN_TEXT)
                        flag = "" if px >= MIN_TEXT_PX else f"  < {MIN_TEXT_PX} px, too small"
                        print(f"{url} figure {i + 1}: smallest text at phone width {px:.1f} px{flag}")
                        if flag:
                            too_small.append((url, i + 1))
                ctx.close()
            print(f"{url}: {count} figure(s) x {len(VARIANTS)} variants -> .shots/{slug}/")
        browser.close()
    server.shutdown()
    return 1 if too_small else 0


if __name__ == "__main__":
    sys.exit(main())
