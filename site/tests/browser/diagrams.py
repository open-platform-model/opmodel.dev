"""Diagram check (task shots and task qa): every Mermaid diagram of the
Enhancements section, drawn in the browser as a reader sees it.

Every page under public/enhancements/ that holds a mermaid fence is loaded at
desktop width in the light theme and at phone width in the dark theme. Each
diagram must render to an SVG that is not Mermaid's error drawing, with no
console error, page error or failed request, and no label may render under
MIN_TEXT_PX (a diagram fitted to the column would shrink its labels; the
section draws them at their natural size in a scroller), and every label
must pass axe's colour-contrast rule (WCAG 2.1 AA) in both themes. shots.py's figure
rule cannot see these: it measures only figure:has(svg[role=img]).

Before the pages, the rule proves it can fail: on a diagram page it draws a
diagram with a syntax error and one squeezed into a narrow box, and the run
fails unless it reports the first as an error and the second as too small.

Screenshots, into site/.shots/diagrams/<page>/: for the graph and the
first entry with a diagram (or every diagram page, with --all), each diagram
in the reader's view (scrolled into the window) in the six variants, and the
whole diagram once per theme (diagram-<n>-full-<theme>.png). site/.shots/
diagrams/ is replaced on every run.
"""

import re
import shutil
import sys

from playwright.sync_api import sync_playwright

from qa_common import AXE, PUBLIC, SITE, new_page, serve, slug

OUT = SITE / ".shots" / "diagrams"
MIN_TEXT_PX = 9
RENDER_TIMEOUT_MS = 30000

VARIANTS = [
    # name, viewport width, site theme switch, OS colour scheme, phone
    ("light", 1280, "light", "light", False),
    ("dark", 1280, "dark", "dark", False),
    ("switch-dark-os-light", 1280, "dark", "light", False),
    ("switch-light-os-dark", 1280, "light", "dark", False),
    ("phone-light", 390, "light", "light", True),
    ("phone-dark", 390, "dark", "dark", True),
]
# The loads every diagram page gets: (width, theme, phone).
LOADS = [(1280, "light", False), (390, "dark", True)]

RENDERED = """() => {
  const els = [...document.querySelectorAll('pre.mermaid')]
  return els.length > 0 && els.every(e => e.dataset.processed && e.querySelector('svg'))
}"""

# Per diagram (the pre.mermaid elements a selector names): whether it drew an SVG, whether that SVG is Mermaid's error
# drawing, its rendered width, and the smallest rendered label size: the
# computed font size of every element that holds text, times the scale of its
# SVG coordinate system on screen (an HTML label sits in a foreignObject).
INSPECT = """(sel) => [...document.querySelectorAll(sel)].map((pre, i) => {
  const svg = pre.querySelector('svg')
  if (!svg) return {i, svg: false}
  const err = svg.getAttribute('aria-roledescription') === 'error' ||
    !!svg.querySelector('.error-icon, .error-text') || /Syntax error/.test(svg.textContent)
  let min = Infinity, labels = 0
  for (const el of svg.querySelectorAll('text, tspan, foreignObject *')) {
    if (![...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim())) continue
    const host = el.closest('foreignObject') || el
    const m = host.getScreenCTM && host.getScreenCTM()
    if (!m) continue
    const px = parseFloat(getComputedStyle(el).fontSize) * Math.hypot(m.a, m.b)
    if (px) { labels++; min = Math.min(min, px) }
  }
  const r = svg.getBoundingClientRect()
  return {i, svg: true, err, width: Math.round(r.width), labels,
          minPx: labels ? Math.round(min * 10) / 10 : null}
})"""

# axe's colour-contrast rule (WCAG 2.1 AA) on the diagrams alone; per
# violating node, its colours and ratio.
CONTRAST = """async () => {
  const r = await axe.run(document.querySelectorAll('.opm-enh-diagram'), {runOnly: {type: 'rule', values: ['color-contrast']}})
  return r.violations.flatMap(v => v.nodes.map(n => {
    const d = (n.any[0] || {}).data || {}
    return `${n.target.join(' ')}: ${(n.element || {}).textContent || ''} ${d.fgColor} on ${d.bgColor}, ${d.contrastRatio}:1`
  }))
}"""

# The rule's own failing cases, drawn on a live diagram page.
CANARY = """async () => {
  const box = document.createElement('div')
  box.innerHTML = '<pre class="mermaid" id="opm-canary-error">flowchart LR\\n  a --> --> b{</pre>' +
    '<div style="width:60px;overflow:hidden"><pre class="mermaid" id="opm-canary-small">' +
    '%%{init: {"flowchart": {"useMaxWidth": true}}}%%\\nflowchart LR\\n' +
    '  a[A label long enough to shrink] --> b[Another label long enough to shrink] --> c[And a third]</pre></div>'
  document.querySelector('#content').appendChild(box)
  const nodes = [...box.querySelectorAll('pre.mermaid')]
  try { await mermaid.run({nodes}) } catch (e) {}
  return true
}"""


def diagram_pages():
    pages = []
    for html in sorted((PUBLIC / "enhancements").rglob("index.html")):
        if "pagefind" in html.parts:
            continue
        if re.search(r'class="?mermaid', html.read_text(errors="ignore")):
            pages.append("/" + html.parent.relative_to(PUBLIC).as_posix() + "/")
    return pages


def load(browser, base, url, width, theme, scheme, phone):
    """Opens url and waits for its diagrams; returns (page, problems seen)."""
    page = new_page(browser, width, theme, scheme, phone)
    seen = []
    page.on("console", lambda m: seen.append(f"console: {m.text}") if m.type == "error" else None)
    page.on("pageerror", lambda e: seen.append(f"page error: {e}"))
    page.on("requestfailed", lambda r: seen.append(f"failed request: {r.url}"))
    page.goto(base + url, wait_until="networkidle")
    try:
        page.wait_for_function(RENDERED, timeout=RENDER_TIMEOUT_MS)
    except Exception:
        seen.append(f"not every diagram rendered within {RENDER_TIMEOUT_MS // 1000} s")
    return page, seen


def problems_of(info):
    out = []
    for d in info:
        n = d["i"] + 1
        if not d["svg"]:
            out.append(f"diagram {n}: no SVG")
        elif d["err"]:
            out.append(f"diagram {n}: Mermaid drew an error")
        elif d["minPx"] is None:
            out.append(f"diagram {n}: no label text found")
        elif d["minPx"] < MIN_TEXT_PX:
            out.append(f"diagram {n}: label text {d['minPx']} px, under {MIN_TEXT_PX} px")
    return out


def canary(browser, base, url):
    """The rule's failing cases; returns the failures (the rule missed one)."""
    page, _ = load(browser, base, url, 1280, "light", "light", False)
    page.evaluate(CANARY)
    info = page.evaluate(INSPECT, "#opm-canary-error, #opm-canary-small")
    page.context.close()
    found = problems_of(info)
    failures = []
    if not any("error" in p for p in found if p.startswith("diagram 1:")):
        failures.append(f"a syntax error was not reported as a Mermaid error ({info[0]})")
    if not any("under" in p for p in found if p.startswith("diagram 2:")):
        failures.append(f"a squeezed diagram was not reported as too small ({info[1]})")
    for f in failures:
        print(f"FAIL canary {url}: {f}")
    if not failures:
        print(f"ok   canary {url}: {'; '.join(found)}")
    return failures


def shoot(browser, base, url):
    """The reader's view of each diagram in six variants, and each diagram
    whole, once per theme."""
    folder = OUT / slug(url)
    folder.mkdir(parents=True, exist_ok=True)
    count = 0
    for variant, width, theme, scheme, phone in VARIANTS:
        page, _ = load(browser, base, url, width, theme, scheme, phone)
        boxes = page.locator(".opm-enh-diagram")
        count = boxes.count()
        for i in range(count):
            boxes.nth(i).scroll_into_view_if_needed()
            page.wait_for_timeout(200)
            page.screenshot(path=str(folder / f"diagram-{i + 1}-{variant}.png"))
        page.context.close()
    for theme in ("light", "dark"):
        page, _ = load(browser, base, url, 1280, theme, theme, False)
        # The whole drawing: the boxes stop clipping it to the column.
        # Sticky and fixed elements (the navbar, the table of contents) would
        # lie over it, so they are hidden.
        page.evaluate("""() => {
          document.querySelectorAll('.opm-enh-diagram').forEach(b => { b.style.overflow = 'visible' })
          for (const el of document.querySelectorAll('*')) {
            const p = getComputedStyle(el).position
            if (p === 'fixed' || p === 'sticky') el.style.visibility = 'hidden'
          }
        }""")
        for i in range(page.locator(".opm-enh-diagram").count()):
            svg = page.locator(".opm-enh-diagram svg").nth(i)
            w = svg.evaluate("s => Math.ceil(s.getBoundingClientRect().width)")
            page.set_viewport_size({"width": max(1280, w + 400), "height": 900})
            page.wait_for_timeout(200)
            svg.screenshot(path=str(folder / f"diagram-{i + 1}-full-{theme}.png"))
        page.context.close()
    print(f"{url}: {count} diagram(s) x {len(VARIANTS)} variants, and whole -> .shots/diagrams/{slug(url)}/")


def main():
    pages = diagram_pages()
    if not pages:
        print("diagrams: the build has no diagram (no Enhancements section, or no mermaid fence in it)")
        return 0
    base = serve()
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    failures = []
    smallest = None
    with sync_playwright() as p:
        browser = p.chromium.launch()
        failures += canary(browser, base, pages[0])
        total = 0
        for url in pages:
            for width, theme, phone in LOADS:
                page, seen = load(browser, base, url, width, theme, theme, phone)
                info = page.evaluate(INSPECT, "pre.mermaid")
                page.add_script_tag(path=AXE)
                low = page.evaluate(CONTRAST)
                page.context.close()
                bad = seen + problems_of(info)
                if low:
                    bad.append(f"{len(low)} label(s) under WCAG AA contrast, first: {low[0]}")
                where = f"{url} at {width} px {theme}"
                for b in bad:
                    print(f"FAIL {where}: {b}")
                    failures.append(f"{where}: {b}")
                if width == LOADS[0][0]:
                    total += len(info)
                sizes = [d["minPx"] for d in info if d.get("minPx") is not None]
                if sizes:
                    smallest = min(sizes + ([smallest] if smallest is not None else []))
                if not bad:
                    print(f"ok   {where}: {len(info)} diagram(s), widths {[d.get('width') for d in info]}, smallest label {min(sizes) if sizes else '-'} px")
        shots = pages if "--all" in sys.argv[1:] else [u for u in ("/enhancements/graph/",) if u in pages] + \
            [next((u for u in pages if re.fullmatch(r"/enhancements/[0-9]{4}/", u)), pages[0])]
        for url in dict.fromkeys(shots):
            shoot(browser, base, url)
        browser.close()
    if failures:
        print(f"diagrams: FAILED, {len(failures)} problem(s)")
        return 1
    print(f"diagrams: OK, {total} diagram(s) on {len(pages)} page(s), smallest label {smallest} px (at least {MIN_TEXT_PX} px), the rule's own failing cases caught")
    return 0


if __name__ == "__main__":
    sys.exit(main())
