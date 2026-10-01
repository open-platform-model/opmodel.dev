## Why

The owner reviewed the overview figures on 2026-10-01 and asked for three changes. The landing figure draws a watcher only for the backup object, so its cluster row is lopsided; it needs a matching box for what Kubernetes itself runs. The Start here figure "From module to running objects" still tells the older, two-transformer story, while the landing now tells it with three; it should be the landing's drawing with the explanations put back. The Helm comparison on What OPM is shows that OPM takes Helm's roles but not what OPM adds: typed values, and traits that are published contracts, so a platform fulfils a capability such as backup once for every module that asks. The owner approved the drafts of all four figures ("looks good, implement").

## What Changes

- **Landing** (`opm/landing-overview`, site-owned): a "Built-in controllers" box under the Deployment and Service columns joins the backup box, with its own "watched by" arrow. The backup box is renamed "Backup controller" (in core's terms the provider is the catalog). The CLUSTER label moves to the zone's top row. 372 x 472 becomes 372 x 498.
- **From module to running objects** (`opm/module-to-cluster`): redrawn as the landing's layout (three transformer chips including Backup, the emitted rail, one "Kubernetes objects" bar, the two watchers) plus body lines: the component with the backup trait, the configuration schema, the values, where transformers come from, the two appliers, the ModuleInstance record, what each watcher does. 360 x 622 becomes 360 x 680, with a new claim.
- **Helm and OPM** (`opm/helm-and-opm`): the role mapping as before, plus a values line on each author card ("values schema: optional" against "values schema: CUE, unified"). 360 x 586 becomes 360 x 606, with a new claim.
- **One trait, any provider** (`opm/one-trait-any-provider`, new dialect figure, id `otp`, 360 x 658): three Helm charts with three different backup values keys and templates beside three OPM modules with the identical backup trait, checked against one catalog trait, fulfilled by the platform's one provider (k8up and Velero marked as examples), both sides ending in three Schedules.
- The page dialect gains its seventh figure name: `lint-sources.sh` `FIGURES`, `figure-titles.html`, README, and the dialect contract in `openspec/changes/deploy-site/orchestration.md` (its figure table and its embedded lint, with the new sha256). The fixture start page draws the new figure, and `test-site.sh` counts seven figures. Nothing is **BREAKING**: no URL, page, version or theme override changes, and the dialect only gains a name.

## Before / After

**Before**

```text
site/layouts/_shortcodes/opm/
  landing-overview.html     lov 372 x 472  (backup provider only)
  module-to-cluster.html    mtc 360 x 622  (two transformers, objects drawn twice)
  helm-and-opm.html         hao 360 x 586
site/layouts/_partials/opm/figures/   the matching bodies
site/scripts/lint-sources.sh          FIGURES = six names
site/layouts/_partials/opm/figure-titles.html   six entries
README.md                             "All six figures of the page dialect"
openspec/changes/deploy-site/orchestration.md   dialect contract: six names, lint sha256 dae9717a...
site/tests/fixtures/ws/opm/docs/site/start/_index.md   six figure shortcodes
site/scripts/test-site.sh             dialect/shortcodes and markdown/figure-titles count six
```

**After**

```text
site/layouts/_shortcodes/opm/
  landing-overview.html     lov 372 x 498  (built-in controllers + backup controller)
  module-to-cluster.html    mtc 360 x 680  (landing layout + detail, new claim)
  helm-and-opm.html         hao 360 x 606  (+ values-schema line, new claim)
  one-trait-any-provider.html   + otp 360 x 658, "One trait, any provider"
site/layouts/_partials/opm/figures/   the four bodies, one new
site/scripts/lint-sources.sh          FIGURES = + one-trait-any-provider
site/layouts/_partials/opm/figure-titles.html   + "one-trait-any-provider" "One trait, any provider"
README.md                             "All seven figures of the page dialect"
openspec/changes/deploy-site/orchestration.md   + one-trait-any-provider row; embedded lint and sha256 match lint-sources.sh
site/tests/fixtures/ws/opm/docs/site/start/_index.md   + {{< opm/one-trait-any-provider >}}
site/scripts/test-site.sh             both checks count seven
```

## Impact

- **Files.** The four shortcodes and four bodies above (two new), `site/scripts/lint-sources.sh`, `site/layouts/_partials/opm/figure-titles.html`, `site/scripts/test-site.sh`, `site/tests/fixtures/ws/opm/docs/site/start/_index.md`, `README.md`, `openspec/changes/deploy-site/orchestration.md`, and this change directory.
- **Build inputs.** None gained or lost; no CSS class or token is added, no Hextra file is copied, `site/overrides.sha256` is untouched.
- **Source repos.** The workspace `STYLE.md` ("Site Pages") lists the dialect's figure names and must name `one-trait-any-provider` (the lint stays byte-identical to it). `opm` follow-up: `docs/site/start/what-is-opm.md` draws `{{< opm/one-trait-any-provider >}}` after `helm-and-opm` in "In Kubernetes terms", with a paragraph introducing it; that PR merges after this one, since the lint rejects an unknown figure name.
- **Published URLs.** Content only: `/v1.0/` (landing), `/v1.0/docs/start/` and `/v1.0/docs/start/what-is-opm/`, and the Markdown outputs of those pages. The version set stays `v1.0`; this change does not touch 0021:OQ15.
- **Sections.** One implementation section, then verify and archive.

## Enhancement

None implemented, so no `enhancement.yaml`. The figures keep 0018:D14's visual language. The new figure describes shipped 0015 behaviour (provider-fulfilled traits, one provider per contract); no provider catalog is published, so its providers are labelled as examples.
