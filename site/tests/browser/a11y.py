"""Accessibility smoke test: axe-core (in the QA image) on key pages of the
default version, light and dark (set through Hextra's 'color-theme' key), for
the WCAG 2.1 A and AA rules, the first page that holds a direction note
(qa_common.direction_pages, when the build has one), and the Enhancements
section's pages (qa_common.enhancement_pages), each once its diagrams are
drawn. Any violation fails the run.

Two more checks, each its own function: the breadcrumb is a landmark that
marks the current page and clips no crumb on a phone (check_breadcrumb), and
the phone menu opens where a reader needs it (check_drawer)."""

import sys

from playwright.sync_api import sync_playwright

from qa_common import AXE, PUBLIC, SITE, default_version, direction_pages, enhancement_pages, new_page, serve, wait_for_diagrams

TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]
PAGES = [
    "/",                          # landing
    "/docs/",                     # docs home, a section with its child list
    "/docs/start/",               # five figures
    "/docs/start/quickstart/",    # alerts, code blocks, a tutorial badge
    "/docs/reference/",           # a site-owned section
    "/404.html",
]


def main():
    version = default_version()
    base = serve()
    failures = 0
    urls = [f"/{version}{path}" for path in PAGES] + direction_pages(version)[:1] + enhancement_pages()
    with sync_playwright() as p:
        browser = p.chromium.launch()
        for theme in ("light", "dark"):
            for url in urls:
                page = new_page(browser, 1280, theme, theme)
                page.goto(base + url, wait_until="networkidle")
                wait_for_diagrams(page)
                page.add_script_tag(path=AXE)
                result = page.evaluate(
                    "tags => axe.run(document, {runOnly: {type: 'tag', values: tags}})", TAGS
                )
                violations = result["violations"]
                if violations:
                    failures += len(violations)
                    for v in violations:
                        print(f"FAIL {theme} {url}: {v['id']} ({v['impact']}, {len(v['nodes'])} node(s)): {v['nodes'][0]['target']}")
                else:
                    print(f"ok   {theme} {url}: no violations ({len(result['passes'])} rules passed)")
                page.context.close()
        failures += check_breadcrumb(browser, base, version)
        failures += check_drawer(browser, base, version)
        browser.close()
    if failures:
        print(f"a11y: FAILED, {failures} violation(s)")
        return 1
    print(f"a11y: OK, {len(urls)} pages x 2 themes, WCAG 2.1 A and AA")
    return 0


QUICKSTART = "/docs/start/quickstart/"

BREADCRUMB = """() => {
  const navs = document.querySelectorAll('nav[aria-label="Breadcrumb"]')
  const current = navs.length ? [...navs[0].querySelectorAll('[aria-current="page"]')] : []
  const clipped = [...document.querySelectorAll('.opm-crumbs li')]
    .filter(li => getComputedStyle(li).display !== 'none' && li.scrollWidth > li.clientWidth)
    .map(li => li.textContent.trim())
  return {
    navs: navs.length,
    current: current.map(e => e.textContent.trim()),
    h1: (document.querySelector('#content h1') || {}).textContent,
    clipped,
  }
}"""


def check_breadcrumb(browser, base, version):
    """On the quickstart, at desktop and phone width: one breadcrumb landmark
    whose single aria-current="page" crumb reads as the h1; at phone width no
    displayed crumb is clipped. Returns the number of failures."""
    url = f"/{version}{QUICKSTART}"
    failures = 0
    for width, phone in ((1280, False), (390, True)):
        page = new_page(browser, width, "light", "light", phone)
        page.goto(base + url, wait_until="networkidle")
        r = page.evaluate(BREADCRUMB)
        page.context.close()
        h1 = (r["h1"] or "").strip()
        problems = []
        if r["navs"] != 1:
            problems.append(f'{r["navs"]} nav[aria-label="Breadcrumb"] landmarks, want 1')
        if len(r["current"]) != 1 or r["current"][0] != h1:
            problems.append(f'aria-current="page" crumbs {r["current"]}, want exactly [{h1!r}]')
        if phone and r["clipped"]:
            problems.append(f"clipped crumbs: {r['clipped']}")
        for m in problems:
            print(f"FAIL breadcrumb {width}px {url}: {m}")
        if not problems:
            print(f"ok   breadcrumb {width}px {url}: one landmark, current page {h1!r}, nothing clipped")
        failures += len(problems)
    return failures


DRAWER = """(root) => {
  const box = document.querySelector('aside.hextra-sidebar-container > .hextra-scrollbar')
  const b = box.getBoundingClientRect()
  const inside = el => { if (!el) return null; const r = el.getBoundingClientRect(); return r.height > 0 && r.top >= b.top && r.bottom <= b.bottom }
  const active = [...box.querySelectorAll('.hextra-sidebar-active-item')].find(e => e.getBoundingClientRect().height > 0)
  const entry = active && active.closest('li')
  const toc = entry && entry.querySelector(':scope > ul.opm-sb-toc a')
  return {
    scrollTop: box.scrollTop,
    root: inside(box.querySelector('.opm-sb-root')),
    active: inside(active),
    toc: toc ? inside(toc) : null,
  }
}"""


def last_page_with_toc(version):
    """The last URL in the sidebar order whose page lists its h2 headings under
    its sidebar entry (ul.opm-sb-toc)."""
    urls = (SITE / ".check" / version / "nav-order.txt").read_text().split()
    for url in reversed(urls):
        html = PUBLIC / url.strip("/") / "index.html"
        if html.is_file() and "opm-sb-toc" in html.read_text(errors="ignore"):
            return url
    return None


def open_drawer(page):
    page.locator(".hextra-hamburger-menu").click()
    page.wait_for_function("document.querySelector('.hextra-hamburger-menu').getAttribute('aria-expanded') === 'true'")
    page.wait_for_timeout(400)


def check_drawer(browser, base, version):
    """At phone width with the menu open: on the quickstart, whose entry fits
    the first screen, the menu is not scrolled and the section root is in
    view; on the last page with an h2 list, the active entry is in view, and
    so is the first link of its h2 list when the menu scrolled. The last page
    is also opened on a short phone (600 px), where its entry lies below the
    first screen, so the scrolling branch runs too. Returns the number of
    failures."""
    last = last_page_with_toc(version)
    failures = 0
    cases = [(f"/{version}{QUICKSTART}", "top", 844)]
    if last:
        cases += [(last, "item", 844), (last, "item", 600)]
    else:
        print("FAIL drawer: no page in nav-order.txt lists its h2 headings in the sidebar")
        failures += 1
    for url, want, height in cases:
        page = new_page(browser, 390, "light", "light", True)
        page.set_viewport_size({"width": 390, "height": height})
        page.goto(base + url, wait_until="networkidle")
        open_drawer(page)
        r = page.evaluate(DRAWER)
        page.context.close()
        problems = []
        if want == "top":
            if r["scrollTop"] != 0:
                problems.append(f"menu scrolled to {r['scrollTop']}, want 0")
            if not r["root"]:
                problems.append("the section root's link is not in view")
        else:
            if not r["active"]:
                problems.append("the active entry is not in view")
            if r["scrollTop"] > 0 and r["toc"] is False:
                problems.append("the menu scrolled, but the first link of the h2 list is not in view")
        for m in problems:
            print(f"FAIL drawer 390x{height} {url}: {m}")
        if not problems:
            print(f"ok   drawer 390x{height} {url}: scrollTop {r['scrollTop']}, root in view {r['root']}, active in view {r['active']}, h2 list in view {r['toc']}")
        failures += len(problems)
    return failures


if __name__ == "__main__":
    sys.exit(main())
