## Why

core is adding a concept page, "The application model and the platform model" (`core/docs/site/concepts/application-and-platform-models.md`). It makes two points that no existing figure draws: OPM models an application and models a platform only as far as rendering needs, and a module and a platform never depend on each other, only on catalog contracts, so each side changes on its own schedule. The owner approved two new figures for the page. A figure is drawn in the site engine and its name is part of the page dialect, so both land here before core's page can call them.

## What Changes

- **What OPM models today** (`opm/what-opm-models`, new dialect figure, id `wom`, 360 x 580): an APPLICATION MODEL zone with the author's Module and the deployer's Module instance, the published Catalogs, a PLATFORM, AS FAR AS RENDERING NEEDS zone with the platform team's Platform, and a dashed NOT MODELLED box (cluster settings, controllers and APIs, services offered to teams).
- **Two models, one boundary** (`opm/two-models-one-boundary`, new dialect figure, id `tmb`, 360 x 420): the catalog contracts on top (the real `container` resource and `expose` and `backup` traits), the Module and the Platform each with one arrow up to them, a dashed divider between the two labelled NO IMPORT EITHER WAY, and a Render box where they meet.
- The page dialect gains its eighth and ninth figure names: `lint-sources.sh` `FIGURES`, `figure-titles.html`, README, and the dialect contract in `openspec/changes/deploy-site/orchestration.md` (its figure table, its "nine names" sentence and its embedded lint, with the new sha256). The fixture start page draws both figures, and `test-site.sh` counts nine. Nothing is **BREAKING**: no URL, page, version or theme override changes, and the dialect only gains names.

## Before / After

**Before**

```text
site/layouts/_shortcodes/opm/          seven dialect figures + landing-overview
site/layouts/_partials/opm/figures/    the matching bodies
site/scripts/lint-sources.sh           FIGURES = seven names, sha256 4dc241a4...
site/layouts/_partials/opm/figure-titles.html   seven entries
README.md                              "All seven figures of the page dialect"
openspec/changes/deploy-site/orchestration.md   "Exactly these seven names", seven rows, lint sha256 4dc241a4...
site/tests/fixtures/ws/opm/docs/site/start/_index.md   seven figure shortcodes
site/scripts/test-site.sh              dialect/shortcodes and markdown/figure-titles count seven
```

**After**

```text
site/layouts/_shortcodes/opm/
  what-opm-models.html           + wom 360 x 580, "What OPM models today"
  two-models-one-boundary.html   + tmb 360 x 420, "Two models, one boundary"
site/layouts/_partials/opm/figures/    + the two bodies
site/scripts/lint-sources.sh           FIGURES = + what-opm-models two-models-one-boundary
site/layouts/_partials/opm/figure-titles.html   + two entries, "nine figures"
README.md                              "All nine figures of the page dialect"
openspec/changes/deploy-site/orchestration.md   "Exactly these nine names", + two rows; embedded lint and sha256 match lint-sources.sh
site/tests/fixtures/ws/opm/docs/site/start/_index.md   + {{< opm/what-opm-models >}}, {{< opm/two-models-one-boundary >}}
site/scripts/test-site.sh              both checks count nine
```

## Impact

- **Files.** The two shortcodes and two bodies above (all new), `site/scripts/lint-sources.sh`, `site/layouts/_partials/opm/figure-titles.html`, `site/scripts/test-site.sh`, `site/tests/fixtures/ws/opm/docs/site/start/_index.md`, `README.md`, `openspec/changes/deploy-site/orchestration.md`, and this change directory.
- **Build inputs.** None gained or lost; no CSS class or token is added, no Hextra file is copied, `site/overrides.sha256` is untouched.
- **Source repos.** The workspace `STYLE.md` ("Site Pages") lists the dialect's figure names and must name both new figures (the lint stays byte-identical to the contract there). `core` follow-up: `docs/site/concepts/application-and-platform-models.md` draws `{{< opm/what-opm-models >}}` and `{{< opm/two-models-one-boundary >}}`; that PR merges after this one, since the lint rejects an unknown figure name.
- **Published URLs.** None until core's page uses the figures; then the page `/v1.0/docs/concepts/application-and-platform-models/` and its Markdown output. The version set stays `v1.0`; this change does not touch 0021:OQ15.
- **Sections.** One implementation section, then verify and archive.

## Enhancement

None implemented, so no `enhancement.yaml`. The figures keep the dialect's visual language (one colour per role, published things neutral).
