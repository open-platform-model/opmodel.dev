"""Theme switch animation check (site/assets/js/opm-theme-transition.js).

The script wraps Hextra's setTheme in a view transition; a browser change
that breaks the wrap would still leave the site working, so nothing else
notices. An init script wraps Document.prototype.startViewTransition and
counts calls on window.__vt, then this fails unless:
  - loading a page starts no transition (the toggle's own setTheme call
    changes nothing);
  - a pointer switch starts exactly one, as a reveal, ends in the new theme,
    leaves no opm-theme-* class on <html>, and the old snapshot is taken with
    the old toggle icon (Hextra flips the icon right after setTheme);
  - a keyboard switch starts exactly one, as a fade;
  - under prefers-reduced-motion a switch starts none and still switches;
  - nothing logs a console error or throws.
"""

import sys

from playwright.sync_api import sync_playwright

from qa_common import default_version, serve

# Counts startViewTransition calls and records, per call, the class the
# script put on <html> and the toggle icon's data-theme at three moments: in
# a microtask queued right after the call (what the old snapshot is taken
# from, after the script's own microtask restored the old icon) and after the
# page update.
COUNT = """
(() => {
  window.__vt = [];
  const icon = () => document.querySelector('.hextra-theme-toggle').parentElement.dataset.theme;
  const native = Document.prototype.startViewTransition;
  if (!native) return;
  Document.prototype.startViewTransition = function (update) {
    const rec = { cls: document.documentElement.className, snapshot: null, updated: null };
    window.__vt.push(rec);
    queueMicrotask(() => { rec.snapshot = icon(); });
    return native.call(this, function () {
      const r = update && update.apply(this, arguments);
      rec.updated = icon();
      return r;
    });
  };
})();
"""


def context(browser, theme, reduced):
    ctx = browser.new_context(
        viewport={"width": 1280, "height": 900},
        color_scheme="light",
        reduced_motion="reduce" if reduced else "no-preference",
    )
    ctx.add_init_script(f"try {{ localStorage.setItem('color-theme', '{theme}') }} catch (e) {{}}")
    ctx.add_init_script(COUNT)
    page = ctx.new_page()
    errors = []
    page.on("console", lambda m: errors.append(f"console {m.type}: {m.text}") if m.type == "error" else None)
    page.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
    return page, errors


def settled(page, want):
    """Waits for the theme to be WANT with no transition class left."""
    page.wait_for_function(
        """want => document.documentElement.classList.contains(want) &&
                  ![...document.documentElement.classList].some(c => c.startsWith('opm-theme-'))""",
        arg=want,
        timeout=5000,
    )


def state(page):
    return page.evaluate(
        """() => ({
          vt: window.__vt,
          dark: document.documentElement.classList.contains('dark'),
          cls: document.documentElement.className,
          stored: localStorage.getItem('color-theme'),
          icon: document.querySelector('.hextra-theme-toggle').parentElement.dataset.theme,
        })"""
    )


def pick(page, item, keyboard=False):
    """Opens the theme menu and chooses ITEM, with the pointer or the keyboard."""
    toggle = page.locator(".hextra-theme-toggle:visible").first
    opt = page.locator(f".hextra-theme-toggle-options:visible button[data-item={item}]").first
    if keyboard:
        toggle.focus()
        page.keyboard.press("Enter")
        opt.focus()
        page.keyboard.press("Enter")
    else:
        toggle.click()
        opt.click()


def main():
    base = serve()
    url = f"{base}/{default_version()}/docs/"
    failures = []
    errors = []

    def check(ok, msg):
        if not ok:
            failures.append(msg)

    with sync_playwright() as p:
        browser = p.chromium.launch()

        # No transition on load, whichever theme is stored.
        for theme in ("light", "dark"):
            page, errs = context(browser, theme, False)
            page.goto(url, wait_until="networkidle")
            s = state(page)
            check(s["vt"] == [], f"loading with {theme} stored started {len(s['vt'])} view transition(s)")
            errors += errs
            page.context.close()

        # Pointer switches both ways, then a keyboard switch.
        page, errs = context(browser, "light", False)
        page.goto(url, wait_until="networkidle")
        supported = page.evaluate("typeof document.startViewTransition === 'function'")
        check(supported, "this Chromium has no document.startViewTransition, so the check cannot run")
        for n, (item, dark, was, now) in enumerate([("dark", True, "light", "dark"), ("light", False, "dark", "light")], 1):
            pick(page, item)
            settled(page, item)
            s = state(page)
            check(len(s["vt"]) == n, f"pointer switch to {item}: {len(s['vt'])} transition(s) in total, want {n}")
            if len(s["vt"]) == n:
                rec = s["vt"][-1]
                check("opm-theme-reveal" in rec["cls"], f"pointer switch to {item} was not a reveal (html class {rec['cls']!r})")
                check(rec["snapshot"] == was, f"pointer switch to {item}: the old snapshot shows the {rec['snapshot']!r} icon, want {was!r}")
                check(rec["updated"] == now, f"pointer switch to {item}: the page updated with the {rec['updated']!r} icon, want {now!r}")
            check(s["dark"] is dark, f"pointer switch to {item} did not end in {item}")
            check(s["stored"] == item and s["icon"] == item, f"pointer switch to {item}: stored {s['stored']!r}, icon {s['icon']!r}")
            check("opm-theme" not in s["cls"], f"pointer switch to {item} left {s['cls']!r} on <html>")
        pick(page, "dark", keyboard=True)
        settled(page, "dark")
        s = state(page)
        check(len(s["vt"]) == 3, f"keyboard switch: {len(s['vt'])} transition(s) in total, want 3")
        if len(s["vt"]) == 3:
            check("opm-theme-fade" in s["vt"][-1]["cls"], f"keyboard switch was not a fade (html class {s['vt'][-1]['cls']!r})")
        check(s["dark"] and s["icon"] == "dark", "keyboard switch did not end in dark")
        errors += errs
        page.context.close()

        # Reduced motion: no transition, the switch still works, icon and all.
        page, errs = context(browser, "light", True)
        page.goto(url, wait_until="networkidle")
        pick(page, "dark")
        settled(page, "dark")
        s = state(page)
        check(s["vt"] == [], f"reduced motion started {len(s['vt'])} view transition(s)")
        check(s["dark"] and s["stored"] == "dark" and s["icon"] == "dark", f"reduced motion did not switch to dark: {s}")
        errors += errs
        page.context.close()
        browser.close()

    check(not errors, f"console errors: {errors}")
    for f in failures:
        print(f"theme reveal: FAILED, {f}")
    if failures:
        return 1
    print("theme reveal: OK, no transition on load, one reveal per pointer switch (old icon in the snapshot), one fade per keyboard switch, none under reduced motion, no console errors")
    return 0


if __name__ == "__main__":
    sys.exit(main())
