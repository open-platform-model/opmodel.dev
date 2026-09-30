"""Screenshots of the built site (task shots).

Every page of the default version that draws a figure (a <figure> holding an
<svg role="img">) gets each drawn figure shot in six variants, into
site/.shots/<page>/<n>-<variant>.png, where <n> counts only drawn figures in
page order (a figure that is not drawn yet takes no number). The extras (the
landing, a docs page, the 404 page and the open search palette) get a
viewport shot per variant, into site/.shots/<page>/page-<variant>.png. Each
version's footer stamp (build-stamp.json lists the versions) is shot as an
element, into site/.shots/<version>_docs/stamp-<variant>.png. With two or more
versions, two more extras: the open version switch (site/.shots/switch/) and
a page of a version that is not the default, which carries the outdated bar.
site/.shots/ is replaced on every run.

The variants: light and dark at desktop width, the two cases where the site's
theme switch and the OS setting disagree, and light and dark at phone width.

At phone width it also measures each figure's smallest rendered text: a
figure drawn wider than the phone scales its text down, and under 9 px it is
unreadable, so the run fails.
"""

import shutil
import sys

from playwright.sync_api import sync_playwright

from qa_common import PUBLIC, SITE, default_version, new_page, serve, slug, versions

OUT = SITE / ".shots"
MIN_TEXT_PX = 9

VARIANTS = [
    # name, viewport width, site theme switch, OS colour scheme, phone
    ("light", 1280, "light", "light", False),
    ("dark", 1280, "dark", "dark", False),
    ("switch-dark-os-light", 1280, "dark", "light", False),
    ("switch-light-os-dark", 1280, "light", "dark", False),
    ("phone-light", 390, "light", "light", True),
    ("phone-dark", 390, "dark", "dark", True),
]

FIGURES = 'figure:has(svg[role="img"])'

# Sticky and fixed elements (the navbar) would cover the top of a tall figure
# in an element screenshot. They are hidden, not made static: a static copy
# of the off-canvas mobile sidebar would take the phone's width from the page.
UNSTICK = """() => {
  for (const el of document.querySelectorAll('*')) {
    const p = getComputedStyle(el).position
    if (p === 'fixed' || p === 'sticky') el.style.visibility = 'hidden'
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


def figure_pages(version):
    pages = []
    for html in sorted((PUBLIC / version).rglob("index.html")):
        if "pagefind" in html.parts:
            continue
        text = html.read_text(errors="ignore")
        if "<figure" in text and "role=img" in text.replace('"', ""):
            pages.append("/" + html.parent.relative_to(PUBLIC).as_posix() + "/")
    return pages


def main():
    version = default_version()
    base = serve()
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    pages = figure_pages(version)
    extras = [
        (f"/{version}/", "landing", None),
        (f"/{version}/docs/start/quickstart/", "docs page", None),
        (f"/{version}/404.html", "404 page", None),
        (f"/{version}/docs/", "search", "search"),
    ]
    listed = versions()
    others = [name for name, is_default in listed if not is_default]
    if others:
        extras += [
            (f"/{version}/docs/", "version switch, open", "switch"),
            (f"/{others[0]}/docs/start/quickstart/", "outdated bar", None),
        ]
    too_small = []
    errors = []
    with sync_playwright() as p:
        browser = p.chromium.launch()
        for url in pages:
            name = slug(url)
            (OUT / name).mkdir(parents=True, exist_ok=True)
            count = 0
            for variant, width, theme, scheme, phone in VARIANTS:
                page = new_page(browser, width, theme, scheme, phone)
                page.on("pageerror", lambda e, u=url: errors.append(f"{u}: {e}"))
                page.goto(base + url, wait_until="networkidle")
                page.evaluate(UNSTICK)
                figures = page.locator(FIGURES)
                count = figures.count()
                for i in range(count):
                    fig = figures.nth(i)
                    fig.screenshot(path=str(OUT / name / f"{i + 1}-{variant}.png"))
                    if variant == "phone-light":
                        px = fig.evaluate(MIN_TEXT)
                        flag = "" if px >= MIN_TEXT_PX else f"  < {MIN_TEXT_PX} px, too small"
                        print(f"{url} figure {i + 1}: smallest text at phone width {px:.1f} px{flag}")
                        if flag:
                            too_small.append((url, i + 1))
                page.context.close()
            print(f"{url}: {count} figure(s) x {len(VARIANTS)} variants -> .shots/{name}/")
        for url, what, kind in extras:
            name = kind if kind in ("search", "switch") else slug(url.replace("404.html", "404"))
            (OUT / name).mkdir(parents=True, exist_ok=True)
            for variant, width, theme, scheme, phone in VARIANTS:
                page = new_page(browser, width, theme, scheme, phone)
                page.on("pageerror", lambda e, u=url: errors.append(f"{u}: {e}"))
                page.goto(base + url, wait_until="networkidle")
                if kind == "search":
                    page.locator("[data-search-open]:visible").first.click()
                    page.locator("input.hextra-search-input").fill("module")
                    page.wait_for_selector('#hextra-search-results a[role="option"]', timeout=10000)
                    page.wait_for_timeout(300)
                if kind == "switch":
                    page.locator(".opm-version-toggle:visible").first.click()
                    page.wait_for_selector(".opm-version .hextra-nav-menu-items:visible", timeout=5000)
                    page.wait_for_timeout(300)
                page.screenshot(path=str(OUT / name / f"page-{variant}.png"))
                page.context.close()
            print(f"{url}: {what} x {len(VARIANTS)} variants -> .shots/{name}/")
        for v, _ in listed:
            url = f"/{v}/docs/"
            name = slug(url)
            (OUT / name).mkdir(parents=True, exist_ok=True)
            for variant, width, theme, scheme, phone in VARIANTS:
                page = new_page(browser, width, theme, scheme, phone)
                page.on("pageerror", lambda e, u=url: errors.append(f"{u}: {e}"))
                page.goto(base + url, wait_until="networkidle")
                page.locator(".opm-build-stamp").first.screenshot(path=str(OUT / name / f"stamp-{variant}.png"))
                page.context.close()
            print(f"{url}: footer stamp x {len(VARIANTS)} variants -> .shots/{name}/")
        browser.close()
    for e in errors:
        print(f"page error: {e}")
    if too_small:
        print(f"shots: FAILED, {len(too_small)} figure(s) with text under {MIN_TEXT_PX} px at phone width")
        return 1
    if errors:
        print(f"shots: FAILED, {len(errors)} JavaScript error(s)")
        return 1
    print(f"shots: OK, {len(pages)} figure page(s), {len(extras)} extras in {version} and {len(listed)} footer stamp(s) -> site/.shots/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
