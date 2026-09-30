"""Search smoke test: opens Hextra's search palette on the default version's
docs home, types a query, and fails unless the expected page is among the
first results and every result stays inside the version (the per-version
Pagefind bundle). Then the same on every version that public/build-stamp.json
lists (one in a normal build, two in the two-version build). check_sublines
then checks what a result shows: the page's description as its page-level
sub-line, excerpts on heading matches, and crumbs that start below the docs
root."""

import sys

from playwright.sync_api import sync_playwright

from qa_common import default_version, new_page, serve, versions

QUERY = "quickstart"
EXPECT = "/docs/start/quickstart/"
FIRST = 5


def search(browser, base, version):
    """The result hrefs for QUERY in VERSION's search palette."""
    page = new_page(browser, 1280, "light", "light")
    page.goto(f"{base}/{version}/docs/", wait_until="networkidle")
    page.locator("[data-search-open]:visible").first.click()
    page.locator("input.hextra-search-input").fill(QUERY)
    page.wait_for_selector('#hextra-search-results a[role="option"]', timeout=10000)
    page.wait_for_timeout(500)
    hrefs = page.eval_on_selector_all(
        "#hextra-search-results > li:not(.hextra-search-child) a",
        "els => els.map(e => e.getAttribute('href'))",
    )
    page.context.close()
    return hrefs


def every_version(base):
    """QUERY in every listed version finds that version's quickstart first
    among FIRST results, and nothing outside the version."""
    failures = 0
    with sync_playwright() as p:
        browser = p.chromium.launch()
        for version, _ in versions():
            hrefs = search(browser, base, version)
            first = [h.split("#")[0] for h in hrefs[:FIRST]]
            want = f"/{version}{EXPECT}"
            outside = [h for h in hrefs if not h.startswith(f"/{version}/")]
            if want not in first or outside:
                failures += 1
                print(f"search: FAILED in {version}: {want} in the first {FIRST}: {want in first}; outside {version}: {outside}")
            else:
                print(f"search {version}: {want} is result {first.index(want) + 1}; all {len(hrefs)} results stay in {version}")
        browser.close()
    return failures


def main():
    version = default_version()
    base = serve()
    with sync_playwright() as p:
        browser = p.chromium.launch()
        hrefs = search(browser, base, version)
        browser.close()
    first = [h.split("#")[0] for h in hrefs[:FIRST]]
    print(f"search {version} {QUERY!r}: {first}")
    want = f"/{version}{EXPECT}"
    outside = [h for h in hrefs if not h.startswith(f"/{version}/")]
    if want not in first:
        print(f"search: FAILED, {want} is not among the first {FIRST} results")
        return 1
    if outside:
        print(f"search: FAILED, results outside {version}: {outside}")
        return 1
    print(f"search: OK, {want} is result {first.index(want) + 1}; all {len(hrefs)} results stay in {version}")
    failures = every_version(base)
    if failures:
        print(f"search: FAILED in {failures} version(s)")
        return 1
    print(f"search: OK in every version ({', '.join(v for v, _ in versions())})")
    return check_sublines(version, base)


# The palette's results as groups: each page result with its crumbs and the
# matches listed under it (route, title, excerpt).
RESULT_GROUPS = """() => {
  const groups = []
  for (const li of document.querySelectorAll('#hextra-search-results > li')) {
    const a = li.querySelector('a')
    if (!a) continue
    const excerpt = a.querySelector('.hextra-search-excerpt')
    if (li.classList.contains('hextra-search-child')) {
      if (groups.length) groups[groups.length - 1].matches.push({
        href: a.getAttribute('href'),
        excerpt: excerpt ? excerpt.textContent.trim() : '',
      })
    } else {
      const crumb = a.querySelector('.hextra-search-crumb')
      groups.push({
        href: a.getAttribute('href'),
        crumbs: crumb ? crumb.getAttribute('aria-label').split(' > ') : [],
        matches: [],
      })
    }
  }
  return groups
}"""


def squash(s):
    return " ".join((s or "").split())


def check_sublines(version, base):
    """The page-level match shows the page's description (its lead) as its
    sub-line, every match shows a sub-line (a match on a heading keeps
    Pagefind's excerpt), and no result's crumbs start with the docs root."""
    want = f"/{version}{EXPECT}"
    failures = []
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = new_page(browser, 1280, "light", "light")
        page.goto(f"{base}/{version}/docs/", wait_until="networkidle")
        root = squash(page.locator("#content h1").first.text_content())
        page.goto(f"{base}{want}", wait_until="networkidle")
        lead = squash(page.locator("#content p.opm-lead").first.text_content())
        page.locator("[data-search-open]:visible").first.click()
        page.locator("input.hextra-search-input").fill("Quickstart")
        page.wait_for_selector('#hextra-search-results a[role="option"]', timeout=10000)
        page.wait_for_timeout(500)
        groups = page.evaluate(RESULT_GROUPS)
        browser.close()
    target = next((g for g in groups if g["href"].endswith(EXPECT)), None)
    if not lead:
        failures.append(f"{want} has no p.opm-lead")
    if target is None:
        failures.append(f"no result for {want}")
    else:
        own = [m for m in target["matches"] if m["href"] == target["href"]]
        if not own:
            failures.append(f"no page-level match (route {target['href']}, no fragment) under {want}")
        elif squash(own[0]["excerpt"]) != lead:
            failures.append(f"page-level sub-line of {want} is {own[0]['excerpt']!r}, not the lead {lead!r}")
    rooted = [g["href"] for g in groups if g["crumbs"] and g["crumbs"][0] == root]
    if rooted:
        failures.append(f"results whose crumbs start with the docs root {root!r}: {rooted}")
    # Every match shows a sub-line: a page-level match its description, a
    # heading-level match (route with a #fragment) Pagefind's excerpt.
    # Pagefind builds a heading match only for a heading that carries its own
    # id; Hextra's render-heading.html puts the id on a nested span, so today
    # every match is page-level and the heading count is 0.
    matches = [m for g in groups for m in g["matches"]]
    heading = [m for m in matches if "#" in m["href"]]
    empty = [m["href"] for m in matches if not m["excerpt"]]
    if empty:
        failures.append(f"matches with no sub-line: {empty}")
    for f in failures:
        print(f"search sub-lines: FAILED, {f}")
    if failures:
        return 1
    print(
        f"search sub-lines: OK, {want} shows its lead as the page-level sub-line; "
        f"{len(matches) - len(heading)} page-level and {len(heading)} heading match(es), each with a sub-line; "
        f"no crumbs start with {root!r}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
