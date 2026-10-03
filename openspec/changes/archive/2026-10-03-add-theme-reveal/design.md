## Context

Hextra defines `setTheme` as a global in `js/head/theme.js` and calls it from `js/core/theme.js` in the toggle's `switchTheme`, which then calls its own `applyTheme` (icon `data-theme`, `aria-checked`, `localStorage`). The OS-scheme listener calls `setTheme("system")`. `head-end.html` includes the wrapper as a blocking script, after Hextra's head scripts define `setTheme` and before the body script calls it.

## Goals / Non-Goals

**Goals:**

- A circular reveal for a pointer switch, a short fade for keyboard and OS switches.
- The old snapshot shows the old toggle icon.
- A check that fails when the wrap silently stops working.

**Non-Goals:**

- Forking or patching any Hextra file.
- A user setting for the effect (the `?themefx` experiment is removed).

## Decisions

### 1. Wrap the global, decide by what changed

The wrapper keeps the original `setTheme` and falls back to it when the resolved theme equals the current one (the toggle's call at load, a re-pick of the same theme), under `prefers-reduced-motion`, and when `document.startViewTransition` is missing. Pointer origin: a capturing `pointerdown` records the point and a capturing `keydown` clears it; the point is consumed by the next switch, so an OS switch after a click does not reveal from a stale point.

### 2. The icon, without a fork

`switchTheme` is `setTheme(theme); applyTheme(theme)` in one task, and the browser captures the old snapshot after that task. The wrapper reads each toggle parent's `data-theme` before, queues a microtask (which runs after `applyTheme`, before the capture), reads the new values there and writes the old ones back, and the update callback writes the new ones. In the no-animation paths the wrapper returns the original `setTheme` call untouched, so `applyTheme` works as before. If a transition is skipped the update callback still runs, so the icon always ends new.

### 3. The check counts transitions

An init script wraps `Document.prototype.startViewTransition`, counts calls on `window.__vt` and records, per call, the class on `<html>` (reveal or fade) and the toggle icon in a microtask queued right after the call (what the old snapshot is taken from) and after the update. That makes the icon fix deterministic to test; no timing or pixels. It runs on the built site in the QA image, no network.

## Risks / Trade-offs

- [A Hextra update changes `switchTheme` so the icon flips elsewhere] -> The check fails (its snapshot icon would be new), and the pinned `site/overrides.sha256` drift guard covers only overridden files, so this check is the guard.
- [A browser without View Transitions] -> No animation, the switch works as before.

## Durable decisions

- **The theme switch is a view transition wrapped around Hextra's `setTheme`, never a fork of its theme files.** Lands in the head of `opm-theme-transition.js` and in `README.md`.
- **`task qa` fails if a pointer switch does not start exactly one transition.** Lands in `theme_reveal.py` and `README.md`.
