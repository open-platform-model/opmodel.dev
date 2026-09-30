## Why

The Hugo + Hextra site that `port-site-to-hugo-hextra` lands works, but both judges of the theme bake-off asked for eight fixes before it ships (`research/docs-site-stacks/hugo-themes/README.md`, "Fixes the judges want before shipping"). The page never shows its `description`. Headings are heavy. The table of contents has no visible active item and vanishes between 768 and 1279 px. Section pages list their children as bare links. Search results repeat "Documentation" and show run-on excerpts. The landing ends with an empty right half. Inline code and callouts are loud. On a phone the breadcrumb clips and the menu opens scrolled past the section root. Hextra's breadcrumb is also a `div` with no `nav` and no `aria-current`. These are the last design gaps on the go-live path; the supervisor recommends having this change merged before the DNS cutover.

## What Changes

1. **Page lead** (fix 1). Every docs page with a `description` shows it as a lead paragraph under the title, before the page-type badge. The same element carries the Pagefind `description` metadata. The landing gets no lead: its hero subtitle already says the same, and Hextra's home layout runs the same hook, so the lead is guarded with `.IsHome`.
2. **Lighter type** (fix 2). h1 about 36 px at weight 650, h2 about 24 px at 600 with no rule, h3 about 18 px at 600.
3. **Quieter inline code and callouts** (fix 7). Inline code loses its border. GitHub alerts become a neutral box with a 2 px role-coloured start border and a coloured icon.
4. **Table of contents** (fix 3). The right rail marks its active item with weight and an inset bar. Between 768 and 1279 px, where Hextra hides the rail, the current page's h2 headings show under its sidebar entry.
5. **Section cards** (fix 4). `opm/section-children.html` renders the children as cards: subsections first, then pages grouped by type in the order tutorial, how-to guide, explanation, reference. Each group is ordered by `weight`, then title. The cards are kept out of the search index and out of Hextra's prose styles (`not-prose`).
6. **Search results** (fix 5). The page-level result shows the description as its sub-line. The crumbs start below the docs root, so "Documentation" no longer leads every result.
7. **Landing** (fix 6). The hero gets a right column with the ModuleToCluster figure, through the existing `{{< opm/module-to-cluster >}}` shortcode. The feature grid stays inside the hero wrapper, below the two columns, so it keeps the hero's width and centring. The feature cards lose their glow gradients and get a smaller title. No new landing copy.
8. **Phone breadcrumb and drawer, and breadcrumb a11y** (fix 8). A breadcrumb override renders `nav` > `ol` with `aria-current="page"`. Below 48 rem the crumbs wrap instead of clipping, and the docs-root crumb is hidden. A copy of Hextra's `sidebar.js` scrolls only when the active item is outside the visible part of the sidebar, and then places it near the top as upstream does. The drawer therefore opens at the section root whenever the active item fits the first screen, and otherwise shows the item with its h2 list.
9. **Theme override set grows by two copies**: `layouts/_partials/breadcrumb.html` and `assets/js/core/sidebar.js`, each pinned in `site/overrides.sha256`.
10. **QA.** The search smoke test checks the sub-line and the crumbs. The a11y smoke test checks the breadcrumb landmark and that no crumb is clipped at 390 px. A drawer smoke test checks where the drawer opens. The shots gain a 1024 px tablet shot and a phone shot with the drawer open, and a landing entry if A's shot set misses the landing or its 9 px floor. Each is a separate test function or extra entry.
11. **README.** A `## Page design` heading records the rules page authors and maintainers need (design.md, Durable decisions).

Nothing here is **BREAKING**: no URL, page, version or dialect rule changes.

## Before / After

```text
Before (after port-site-to-hugo-hextra)            After
site/
  assets/css/opm/typography.css   A's split        + .opm-lead, h1-h3 scale, inline code, .hextra-alert
  assets/css/opm/toc.css          A's split        + active TOC item, 48-79.99rem sidebar TOC,
                                                     .opm-crumbs phone rules
  assets/css/opm/cards.css        A's split        + .opm-cards grid and groups
  assets/css/opm/landing.css      A's split        + two-column hero, quieter feature cards
  assets/js/opm-pagefind.js       excerpt only     + description as the page-level sub-line
  assets/js/core/sidebar.js       none             NEW copy of Hextra's, scrolls only when out of view
  layouts/_partials/breadcrumb.html none           NEW copy of Hextra's: nav > ol, aria-current
  layouts/_partials/custom/content-begin.html
                                  badge, crumbs    + lead first; crumbs skip the docs root
  layouts/_partials/opm/section-children.html
                                  plain list       cards grouped by type, data-pagefind-ignore
  content/_index.md               hero, 3 cards    hero + figure column, no glow gradients
  overrides.sha256                A's lines        + 2 lines (breadcrumb.html, core/sidebar.js)
  tests/browser/                  A's QA           + sub-line, crumbs, breadcrumb a11y, drawer, extra shots
README.md                         A's headings     + ## Page design
```

```html
<!-- content-begin.html, top: one element is both the lead and the search meta; docs pages only -->
{{ if not .IsHome }}{{ with .Description }}<p class="opm-lead" data-pagefind-meta="description">{{ . }}</p>{{ end }}{{ end }}
```

## Impact

- **Files.** Only `site/` files and `README.md`, as in the tree above. `site/layouts/_partials/opm/docs-main.html` and `site/layouts/_partials/sidebar.html` are in D's allowance (orchestration.md section 6) but are planned unchanged; design.md says when either may be touched (sidebar.html for fix 8 only).
- **Landing file.** `site/content/_index.md`, or, if A chose goldmark `unsafe = false` for comment stripping, the one landing layout or partial that A's design.md names.
- **Build inputs.** None gained or lost: no mount, source repo, vendored file or pinned tool. The drift guard gains two pinned upstream files.
- **Must not edit.** `navbar-title.html`, `banner.html`, `opm/build-stamp.html`, `scripts/build-all.sh`, `components/last-updated.html` (B); `_partials/opm/figures/*`, `_shortcodes/opm/*`, `figures.css` (C); `brand.css`, favicons, `params.navbar.logo` (M); `.github/workflows/*` (E and F); `_markup/render-link.html` (nobody).
- **Source repos.** None is forced to change. Every source page's `description` now shows as its lead, card text and search sub-line. A description that reads badly in those places is a follow-up in its owning repo, never an edit here.
- **URLs and versions.** No URL changes. The design applies to every page of `v1.0`, the only version, and to the landing at `/v1.0/`.
- **Depends on.** Starts when `port-site-to-hugo-hextra` (A) is merged. Merges when verify is green, after `add-site-ci` (E) is merged; then in any order with B, C and M. Builds read the supervisor's `site-src` worktrees (`OPM_SRC_WORKTREE=site-src`).
- **Merge owner.** The supervisor.
- **Touches.** `site/assets/css/opm/{typography,toc,cards,landing}.css`; `site/layouts/_partials/custom/content-begin.html`; `site/layouts/_partials/opm/{docs-main,section-children}.html`; `site/layouts/_partials/sidebar.html` (fix 8 only); `site/layouts/_partials/breadcrumb.html` (new); `site/assets/js/opm-pagefind.js`; `site/assets/js/core/sidebar.js` (new); `site/content/_index.md` or A's landing layout; `site/overrides.sha256` (append only); `site/tests/browser/*` (separate test functions and extra shots); `README.md` (own heading).

## Enhancement

Related, not claimed. Under 0018:D7 the description "does double duty as the index entry and the search snippet". Fixes 1, 4 and 5 put it on screen in those roles. The cards follow the order of 0018:D7:R2 (tutorial, how-to guide, explanation, reference) as intent only. The landing figure stays a figure in the engine, per 0018:D14. This change writes no `enhancement.yaml` and logs no delivery (supervisor ruling O7).
