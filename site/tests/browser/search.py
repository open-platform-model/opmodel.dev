"""Search smoke test: opens Hextra's search palette on the default version's
docs home, types a query, and fails unless the expected page is among the
first results and every result stays inside the version (the per-version
Pagefind bundle)."""

import sys

from playwright.sync_api import sync_playwright

from qa_common import default_version, new_page, serve

QUERY = "quickstart"
EXPECT = "/docs/start/quickstart/"
FIRST = 5


def main():
    version = default_version()
    base = serve()
    with sync_playwright() as p:
        browser = p.chromium.launch()
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
