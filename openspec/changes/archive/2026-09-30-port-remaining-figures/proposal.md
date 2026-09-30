## Why

The Hugo site that `port-site-to-hugo-hextra` (A) ships draws one of the six figures, ModuleToCluster. The other five render a "Figure pending" stub. All five sit on the two pages a new reader opens first: Start here (`/v1.0/docs/start/`) and What OPM is (`/v1.0/docs/start/what-is-opm/`). The Astro site that A replaced drew all six, so until this change lands the new site explains OPM worse than the old one did. The supervisor recommends merging this change before the owner cuts DNS over.

## What Changes

- Port the five remaining Astro figures to Hugo, as they were at commit `2207ba1` (the last commit that touched `site/src/components/diagrams/`; A's cutover deletes that directory):
  - HelmAndOpm (114 lines, static SVG; the only figure the prototype never saw);
  - RolesAndArtifacts and WhereThingsLive (static SVG);
  - ComponentToObjects and ThreeWaysToDeploy (rows drawn from a data array, ported as a `range` over a slice of dicts).
- Each figure gets an SVG body partial in `site/layouts/_partials/opm/figures/`. Its existing shortcode in `site/layouts/_shortcodes/opm/` stops rendering the stub and calls A's frame, `opm/figure.html`, the way `module-to-cluster.html` does.
- The drawings do not change: same viewBox, ids, coordinates, text and caption. This is a port, not a redesign. The one allowed exception: if A's build trims the space before a `<tspan>`, that space is written `&#160;` in two text nodes, so the figure still reads "component web" (design.md Decision 8).
- `site/assets/css/opm/figures.css` gains any rule these five figures use that A did not carry, written on the `--opm-fig-*` tokens, which follow the site's light/dark toggle (`html.dark`), not the OS.
- The "Figure pending" stub is removed.
- The figure recipe in `README.md` (`## Contributing`, "Adding a figure", which A writes) is brought up to date.
- Nothing is breaking: no URL, page, version, dialect rule or theme override changes.

## Before / After

**Before** (A merged)

```text
site/
  layouts/_shortcodes/opm/
    module-to-cluster.html        frame call, id mtc (A)
    helm-and-opm.html             "Figure pending" stub
    roles-and-artifacts.html      "Figure pending" stub
    where-things-live.html        "Figure pending" stub
    component-to-objects.html     "Figure pending" stub
    three-ways-to-deploy.html     "Figure pending" stub
  layouts/_partials/opm/
    figure.html                   the frame: dict id, title, claim, width, height, body (A)
    figures/module-to-cluster.html
  assets/css/opm/figures.css      --opm-fig-* tokens (light, html.dark) + .opm-fig rules (A)
README.md                         ## Contributing > "Adding a figure" (A section 5)
```

**After**

```text
site/
  layouts/_shortcodes/opm/
    module-to-cluster.html        unchanged
    helm-and-opm.html             frame call: id hao, "Helm and OPM", 360 x 586
    roles-and-artifacts.html      frame call: id raa, "Three roles, three artifacts", 360 x 420
    where-things-live.html        frame call: id wtl, "Where things live", 360 x 492
    component-to-objects.html     frame call: id cto, "How a component becomes objects", 360 x 496
    three-ways-to-deploy.html     frame call: id ttd, "Three ways to deploy", 360 x 232
  layouts/_partials/opm/
    figure.html                   unchanged
    figures/module-to-cluster.html  unchanged
    figures/helm-and-opm.html          + static SVG body
    figures/roles-and-artifacts.html   + static SVG body
    figures/where-things-live.html     + static SVG body
    figures/component-to-objects.html  + rows: slice of 4 dicts, range
    figures/three-ways-to-deploy.html  + rows: slice of 3 dicts, nested range
  assets/css/opm/figures.css      + any figure.css rule from 2207ba1 that A did not carry
README.md                         ## Contributing > "Adding a figure": static and data-driven bodies, the rules
(no "Figure pending" text left under site/)
```

## Impact

- **Files.** `site/layouts/_shortcodes/opm/{helm-and-opm,roles-and-artifacts,where-things-live,component-to-objects,three-ways-to-deploy}.html`, five new `site/layouts/_partials/opm/figures/*.html`, `site/assets/css/opm/figures.css`, the stub's own leftovers if A made any (a stub-only partial, i18n key or CSS rule; deleted), and `README.md` `## Contributing`, part "Adding a figure".
- **Build inputs.** None gained or lost: no mount, source repo, vendored file or pinned tool changes. No Hextra file is copied, so `site/overrides.sha256` is untouched.
- **Source repos.** None has to change. After `adopt-hugo-page-dialect` (S1), opm's `docs/site/start/_index.md` calls five of the shortcodes and `docs/site/start/what-is-opm.md` calls three. They render the figure in place of the stub with no edit.
- **Published URLs.** Only the content of `/v1.0/docs/start/` and `/v1.0/docs/start/what-is-opm/` changes, and so what `/latest/` shows for them. Their search index entries gain the figure text. No URL is added, moved or removed. The version set stays `v1.0` alone; this change does not touch 0021:OQ15.
- **Depends on.** Starts when A (`port-site-to-hugo-hextra`) is merged. Merges when verify is green, after E (`add-site-ci`). Builds read the supervisor's `site-src` worktrees (orchestration.md section 5).
- **Touches.** `site/layouts/_partials/opm/figures/*`, `site/layouts/_shortcodes/opm/*` (the five stubs; `module-to-cluster.html` is not edited), `site/assets/css/opm/figures.css`, the stub's own leftovers if A made any (a stub-only partial, i18n key or CSS rule; deleted), `README.md` `## Contributing` part "Adding a figure" (the figure recipe), and this change directory. Not touched: A's `hugo.toml` and minify setting, and any test or check under `site/tests/` or `site/scripts/`. A test or check that asserts the stub stops the worker, who reports it (design.md Decision 6). A minifier that trims text is handled inside the two figure bodies and reported (design.md Decision 8).
- **Sections.** Three, each ending green under `task ci` and `task qa` with the screenshots read.

## Enhancement

0018:D14: figures are hand-built inline SVG in one visual language. There is one colour per role, and Kubernetes objects stay neutral. The figures use only the site's colour tokens. Each figure's caption is also its accessible label. The text stays readable at phone width. The `0018-engine-neutral` row (I2) rewords 0018:D14 from "Astro component" to "figure component ... through the engine's figure shortcode", which is what this change builds on. No `enhancement.yaml`: this change set records no delivery claims (supervisor ruling O7).
