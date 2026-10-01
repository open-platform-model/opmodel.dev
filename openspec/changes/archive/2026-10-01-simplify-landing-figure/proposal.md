## Why

The landing shows ModuleToCluster, the Start here overview's figure, beside the hero text: 622 units of drawing with a three-line caption under it. The owner asked for a minimal version of that figure on the landing, without the explanation text, with three transformers (Deployment, Service, Backup), a "Backup provider" in the cluster box, and no word repeated down a column. The owner approved the v3 preview on 2026-10-01 ("ship it").

## What Changes

- The landing (`site/content/_index.md`) calls a new site-owned figure, `{{< opm/landing-overview >}}`, in place of `{{< opm/module-to-cluster >}}`.
- The new figure draws the same story with less detail: Module (module author) and Values (deployer) make a Module instance, rendered against the Platform (platform team), whose Deployment, Service and Backup transformers emit onto one rail. One "applied" arrow carries that set into the cluster's single "Kubernetes objects" bar, which a "Backup provider" watches.
- It has no visible caption. Its claim stays the SVG's accessible label.
- The shared frame `site/layouts/_partials/opm/figure.html` gains an optional `caption` argument. `caption: false` leaves the `<figcaption>` out; every other call renders exactly as before.
- `site/assets/css/opm/landing.css` drops the 36rem height cap and the centred caption rule: the new drawing fills the 26rem column.
- `README.md` "Adding a figure" names the landing's figure as the one site-owned exception to the dialect figure rules.
- Docs pages keep `opm/module-to-cluster` unchanged. Nothing is **BREAKING**: no URL, page, version, dialect rule or theme override changes.

## Before / After

**Before**

```text
site/
  content/_index.md                     .opm-hero-figure: {{< opm/module-to-cluster >}}
  layouts/_partials/opm/figure.html     dict id, title, claim, width, height, body; always a <figcaption>
  layouts/_shortcodes/opm/              six dialect figures
  layouts/_partials/opm/figures/        six bodies
  assets/css/opm/landing.css            @media (min-width: 64rem):
                                          .opm-hero-figure .opm-fig svg { height: 36rem; ... }
                                          .opm-hero-figure .opm-fig figcaption { text-align: center; }
README.md                               "Adding a figure": every figure is 360 wide and shows its caption
```

**After**

```text
site/
  content/_index.md                     .opm-hero-figure: {{< opm/landing-overview >}}
  layouts/_partials/opm/figure.html     + optional caption: false leaves the <figcaption> out
  layouts/_shortcodes/opm/
    landing-overview.html               + frame call: id lov, "From module to cluster", 372 x 472, caption false
  layouts/_partials/opm/figures/
    landing-overview.html               + static SVG body
  assets/css/opm/landing.css            @media (min-width: 64rem): the two rules removed
README.md                               "Adding a figure": + the site-owned landing figure (372 wide, no caption, not in the dialect)
(lint-sources.sh FIGURES, figure-titles.html and the six dialect figures unchanged)
```

## Impact

- **Files.** `site/content/_index.md`, `site/layouts/_partials/opm/figure.html`, `site/layouts/_shortcodes/opm/landing-overview.html` (new), `site/layouts/_partials/opm/figures/landing-overview.html` (new), `site/assets/css/opm/landing.css`, `README.md`, and this change directory.
- **Build inputs.** None gained or lost: no mount, source repo, vendored file or pinned tool changes. No Hextra file is copied, so `site/overrides.sha256` is untouched.
- **Source repos.** None has to change. The new shortcode is site-owned: it is not added to the page dialect (`lint-sources.sh` `FIGURES`), so no source page can call it.
- **Published URLs.** Only the landing's content changes, at `/v1.0/` and so what `/latest/` and `/` lead to. The home page has no Markdown output, so `figure-titles.html` needs no entry. No URL is added, moved or removed. The version set stays `v1.0` alone; this change does not touch 0021:OQ15.
- **Sections.** One implementation section, ending green under `task ci` and `task qa` with the landing screenshots read.

## Enhancement

None implemented, so no `enhancement.yaml`. The figure keeps 0018:D14's visual language (role colours, neutral objects, verb-labelled arrows, the site's colour tokens, phone-width legibility) and its accessible label. It departs from one clause of 0018:D14, "each figure states one point in a caption", at the owner's request for the landing only; the docs figures keep their captions.
