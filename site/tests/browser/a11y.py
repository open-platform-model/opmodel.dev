"""Accessibility smoke test: axe-core (in the QA image) on key pages of the
default version, light and dark (set through Hextra's 'color-theme' key), for
the WCAG 2.1 A and AA rules. Any violation fails the run."""

import sys

from playwright.sync_api import sync_playwright

from qa_common import AXE, default_version, new_page, serve

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
    with sync_playwright() as p:
        browser = p.chromium.launch()
        for theme in ("light", "dark"):
            for path in PAGES:
                url = f"/{version}{path}"
                page = new_page(browser, 1280, theme, theme)
                page.goto(base + url, wait_until="networkidle")
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
        browser.close()
    if failures:
        print(f"a11y: FAILED, {failures} violation(s)")
        return 1
    print(f"a11y: OK, {len(PAGES)} pages x 2 themes, WCAG 2.1 A and AA")
    return 0


if __name__ == "__main__":
    sys.exit(main())
