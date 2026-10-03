## Why

A theme switch on the site is an instant flash. The owner tried a prototype (`feat/theme-transition`) with the View Transitions API and approved the reveal: the new theme grows as a circle from the point the pointer clicked. The prototype still carries an experiment switch (`?themefx`) and one visible flaw: the toggle's icon changes before the browser takes the old snapshot, so the old theme briefly shows the new icon.

## What Changes

- **Reveal on a pointer switch**: `site/assets/js/opm-theme-transition.js` wraps Hextra's global `setTheme` in `document.startViewTransition`; the new theme grows as a circle from the pointer (500 ms).
- **Cross-fade on a keyboard or OS switch**: a short fade (0.3 s), no origin to grow from.
- **No animation** when the resolved theme does not change (the toggle's own call at load), under `prefers-reduced-motion`, or without View Transitions support: `setTheme` runs as before.
- **The icon fix**: Hextra's `switchTheme` flips the toggle icon (`data-theme` on each toggle button's parent) right after `setTheme`, before the old snapshot. The wrapper puts the old values back in a microtask and sets the new ones in the update callback. No Hextra file is forked.
- **The experiment goes**: no `?themefx` parameter, no `opm-themefx` in `localStorage`, no `none` mode.
- **A browser check**, `site/tests/browser/theme_reveal.py`, run by `task qa`.

## Before / After

**Before** (the prototype, unmerged)

```text
?themefx=reveal|fade|none, remembered in localStorage
old snapshot of the toggle shows the new icon
no check
```

**After**

```text
pointer switch   -> one view transition, circle from the pointer
keyboard/OS      -> one view transition, cross-fade
unchanged theme, reduced motion, no API -> none
old snapshot keeps the old icon
task qa: theme_reveal.py
```

## Impact

- **Files.** `site/assets/js/opm-theme-transition.js`, `site/assets/css/opm/theme-transition.css`, `site/layouts/_partials/custom/head-end.html` (the script include, all from the prototype, the JS changed here), `site/tests/browser/theme_reveal.py` (new), `site/tests/browser/qa_common.py` (docstring), `site/scripts/run-in-image.sh` (`qa` runs the new check), `Taskfile.yml` (`qa` description), `README.md`, and this change directory.
- **Build inputs.** One script, minified and fingerprinted with SRI as before; no Hextra file is copied, `site/overrides.sha256` is untouched.
- **Published URLs.** None.
- **Sections.** One implementation section, then verify and archive.

## Enhancement

None implemented, so no `enhancement.yaml`.
