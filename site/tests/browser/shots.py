"""Screenshots of the built site (task shots).

Every page of the default version that draws a figure (a <figure> holding an
<svg role="img">) gets each drawn figure shot in six variants, into
site/.shots/<page>/<n>-<variant>.png, where <n> counts only drawn figures in
page order (a figure that is not drawn yet takes no number). The extras (the
landing, a docs page, the 404 page, the open search palette and two section
pages with their child cards, the Enhancements section's page, graph, a
draft entry, its decisions and an archived entry, and the Catalogs section's
page, newest landing, a member with a spec block, a kind index and the edge
landing) get a viewport shot per variant, into site/.shots/<page>/page-<variant>.png. The
sized extras (SIZED_EXTRAS: a tablet width, for example) get one viewport
shot per theme at their own size, into site/.shots/<page>/<name>-<theme>.png.
On every page of the default version that holds a direction note, the
first one is shot as an element, into
site/.shots/direction/<page>/note-<variant>.png. Each version's footer stamp
(build-stamp.json lists the versions) is shot as
an element, into site/.shots/<version>_docs/stamp-<variant>.png. With two or
more versions, two more extras: the open version switch (site/.shots/switch/)
and a page of a version that is not the default, which carries the outdated
bar.
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

from qa_common import PUBLIC, SITE, catalog_pages, default_version, direction_pages, enhancement_pages, new_page, serve, slug, versions, wait_for_diagrams

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

# Viewport shots at a size of their own, one entry each, in light and dark,
# into site/.shots/<page>/<name>-<theme>.png:
#   (url under the version, name, width, height, phone, action before the shot)
SIZED_EXTRAS = [
    # Between 48rem and 80rem the rail is hidden and the current page's h2
    # list sits under its sidebar entry.
    ("/docs/start/quickstart/", "tablet", 1024, 768, False, None),
    # The phone menu, opened: it starts at the section root.
    ("/docs/start/quickstart/", "drawer", 390, 844, True, "drawer"),
    # The landing on a wide desktop.
    ("/", "wide", 1440, 900, False, None),
]

# The landing's first screen: at these desktop sizes the first feature card
# starts inside the window, and the hero figure's smallest text stays at
# MIN_TEXT_PX or more at its rendered size.
LANDING_FOLD = [(1280, 900), (1440, 900)]

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


def shoot_sized_extras(browser, base, version, errors):
    """The SIZED_EXTRAS entries, each in light and dark."""
    for path, name, width, height, phone, action in SIZED_EXTRAS:
        url = f"/{version}{path}"
        folder = OUT / slug(url)
        folder.mkdir(parents=True, exist_ok=True)
        for theme in ("light", "dark"):
            page = new_page(browser, width, theme, theme, phone)
            page.set_viewport_size({"width": width, "height": height})
            page.on("pageerror", lambda e, u=url: errors.append(f"{u}: {e}"))
            page.goto(base + url, wait_until="networkidle")
            if action == "drawer":
                page.locator(".hextra-hamburger-menu").click()
                page.wait_for_timeout(400)
            page.screenshot(path=str(folder / f"{name}-{theme}.png"))
            page.context.close()
        print(f"{url}: {name} {width}x{height} x 2 themes -> .shots/{slug(url)}/")


def shoot_direction(browser, base, version, errors):
    """Each page's first direction note in six variants, as an element, into
    site/.shots/direction/<page>/note-<variant>.png."""
    urls = direction_pages(version)
    if not urls:
        print("no direction note in this build")
    for url in urls:
        folder = OUT / "direction" / slug(url)
        folder.mkdir(parents=True, exist_ok=True)
        for variant, width, theme, scheme, phone in VARIANTS:
            page = new_page(browser, width, theme, scheme, phone)
            page.on("pageerror", lambda e, u=url: errors.append(f"{u}: {e}"))
            page.goto(base + url, wait_until="networkidle")
            page.evaluate(UNSTICK)
            page.locator(".opm-direction").first.screenshot(path=str(folder / f"note-{variant}.png"))
            page.context.close()
        print(f"{url}: direction note x {len(VARIANTS)} variants -> .shots/direction/{slug(url)}/")


def check_landing(browser, base, version):
    """LANDING_FOLD on the landing; returns the failures as strings."""
    failures = []
    url = f"/{version}/"
    for width, height in LANDING_FOLD:
        page = new_page(browser, width, "light", "light")
        page.set_viewport_size({"width": width, "height": height})
        page.goto(base + url, wait_until="networkidle")
        top = page.evaluate("() => document.querySelector('.hextra-feature-card').getBoundingClientRect().top")
        figure = page.locator(FIGURES).first
        px = figure.evaluate(MIN_TEXT) if figure.count() else None
        page.context.close()
        text = "no figure" if px is None else f"smallest figure text {px:.1f} px"
        print(f"{url} at {width}x{height}: first feature card at y={top:.0f}, {text}")
        if top >= height:
            failures.append(f"{url} at {width}x{height}: the first feature card starts at y={top:.0f}, below the fold")
        if px is not None and px < MIN_TEXT_PX:
            failures.append(f"{url} at {width}x{height}: figure text {px:.1f} px, under {MIN_TEXT_PX} px")
    return failures


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
        (f"/{version}/docs/", "section cards", None),
        (f"/{version}/docs/operating/", "section cards", None),
        (f"/{version}/docs/reference/", "reference tab", None),
    ]
    # The Enhancements section, outside every version: its page, the graph, a
    # draft entry with its decisions and an archived entry.
    extras += [(url, "enhancements page", None) for url in enhancement_pages()]
    # The Catalogs section, outside every version: its page, the newest
    # minor's landing, a member page with a spec block, a kind index and the
    # edge landing (none without the section).
    extras += [(url, "catalog page", None) for url in catalog_pages()]
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
                wait_for_diagrams(page)
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
        shoot_sized_extras(browser, base, version, errors)
        shoot_direction(browser, base, version, errors)
        landing = check_landing(browser, base, version)
        browser.close()
    for e in errors:
        print(f"page error: {e}")
    for f in landing:
        print(f"shots: FAILED, {f}")
    if landing:
        return 1
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
