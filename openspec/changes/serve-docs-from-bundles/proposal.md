## Why

After `pull-reference-bundles`, `v1.0` still reads two repositories from git (catalog_opm's `docs/site/` by the catalog line, opm's `docs/site/` at the head of `main`) and the Enhancements section from the enhancements repository's `main`. docs-kit phase 3 moves all three to signed bundles: catalog_opm publishes a second, docs-placed bundle `catalog-opm-docs` from its `opm-v*` tags, opm gains release-please releases (`docs-kit DESIGN decision 17`; first release `1.0.0-beta.1`, `docs-kit DESIGN decision 21`, so its minor tag `1.0` follows the `v1.0` site version) and a bundle, and the enhancements repository publishes an edge-only section bundle (`docs-kit DESIGN decision 18`). This change serves each from its bundle as it appears, so each repository cuts over on its own; `retire-git-pipeline` then deletes what is left.

## Gates

Named as in docs-kit's `docs/orchestration.md` gates table (PR #13, `plan/phases-1b-2-3`). Section 1 here is fixture work that needs no producer.

- **Section 1: no producer gate.** Needs `pull-reference-bundles` section 2 merged (the pinned tool pulls docs bundles). Fixtures for `catalog-opm-docs` and `opm` pull through that tool; the enhancements fixture is hand-written to C21 (`add-enhancements-bundle` design D1 to D5) and layered by `test-site.sh`, because the pinned tool does not know sections yet.
- **Section 2: G3.1**, the first `catalog-opm-docs` release bundle published, from the next opm release after catalog_opm adopts it (no backfill dispatch: an older `opm-v4.*` tree's config has no `catalog-opm-docs`), so `ghcr.io/open-platform-model/docs/catalog-opm-docs` is public and its major tag `4` resolves and verifies anonymously.
- **Section 3: opm's first release bundle.** opm's release-please PR and docs PR merged (owner: release App, secrets, rulesets), its first release (`1.0.0-beta.1`) published `docs/opm`, public, and the tag `1.0` verifies. This is docs-kit's **G3.2**.
- **Section 4: `add-enhancements-bundle` released, and the enhancements bundle published.** The enhancements repository's spike fixes and its `ci(docs)` PR merged, `docs/enhancements` public and `edge` verifying. This is docs-kit's **G3.3**. The site's pin moves to the release carrying `add-enhancements-bundle` in this section, and before the enhancements repository pins it (`pull-reference-bundles` design.md Decision 8).

Merging section 4 with sections 2 and 3 merged is docs-kit's **G3.4** (the opm and enhancements bundles are published and v1.0 reads them), which starts `retire-git-pipeline`.

## What Changes

- `site/bundles.cue` gains `docs."catalog-opm-docs"` and `docs.opm`, `versions."v1.0".tags: {"catalog-opm-docs": "4", opm: "1.0"}`, and `sections: enhancements: {repo: "open-platform-model/enhancements", root: "/enhancements/"}` (C16, C21).
- `site/versions.conf` `from-bundles` for `v1.0` gains `catalog_opm` (section 2) and `opm` (section 3); `catalog-line` goes in section 2.
- The Enhancements section is built from `site/.bundles/enhancements/edge/`: pages from its `content/`, header data from its `data/enhancements.json`. The adapter `site/enhancements/_content.gotmpl` is rewritten to read the bundle (it still sets `url` on every page, so the section stays outside `/<version>/`); `layouts/_partials/opm/enh-clean.html`, `layouts/enhancements/_markup/render-link.html`, the git-tree block of `gen-mounts.sh`, `data/opm/enhancements.json`'s path list and `versions.conf`'s `[section "enhancements"]` go (the producer resolves links and strips comments now).
- The source lint accepts `/enhancements/graph/` (docs-kit's `link-enhancements-graph` conformance fixture, copied in section 4).

## Before / After

**Before**

```text
site/bundles.cue     docs: {cli, core, library, "opm-operator"}; versions."v1.0": {anchor: cli 1.0, pinned: [library, core, opm-operator]}
site/versions.conf   [version "v1.0"] catalog-line = opm-v4, from-bundles = cli core library opm-operator
                     [section "enhancements"] ref = origin/main
v1.0 /docs/ git      opm (main), catalog_opm (opm-v4 line)
/enhancements/       git archive of enhancements origin/main -> adapter (config.yaml, README.md, 0N-*.md), enh-clean, link hook
```

**After**

```text
site/bundles.cue     docs: + "catalog-opm-docs": {repo: "open-platform-model/catalog_opm"}, opm: {repo: "open-platform-model/opm"}
                     versions."v1.0": + tags: {"catalog-opm-docs": "4", opm: "1.0"}
                     + sections: enhancements: {repo: "open-platform-model/enhancements", root: "/enhancements/"}
site/versions.conf   [version "v1.0"] from-bundles = cli core library opm-operator catalog_opm opm   (no git rows left)
v1.0 /docs/ git      none
site/.bundles/       + _versions/v1.0/{catalog-opm-docs,opm}/   + enhancements/edge/{manifest.json,content/,data/enhancements.json}
/enhancements/       bundle edge -> adapter reads content/ and data/enhancements.json; no enh-clean, no section link hook
site/tests/lint/     + link-enhancements-graph/
```

## Impact

- **Files.** `site/Dockerfile` (section 4), `site/bundles.cue`, `site/versions.conf`, `site/scripts/{sections,gen-mounts,gen-catalogs,gen-docs-bundles,gen-stamp,check-pages,run-in-image,resolve-versions,lint-sources,test-site}.sh`, `site/enhancements/_content.gotmpl`, `site/layouts/_partials/opm/{source,enh-status,build-stamp}.html`, `site/layouts/_partials/opm/enh-clean.html` and `site/layouts/enhancements/_markup/render-link.html` (deleted), `site/tests/{fixtures,checks,lint,versions,browser}/`, `.github/workflows/site.yml` (the enhancements checkout and Summary), `README.md`, `AGENTS.md`, the dialect contract copy in `openspec/changes/deploy-site/orchestration.md` (graph form).
- **Build inputs.** Gained: `catalog-opm-docs` and `opm` docs bundles per site version, the `enhancements` section bundle (edge). Lost: the git archives of catalog_opm and opm for `v1.0`, and the enhancements repository's git archive. The pinned `opm-docs` moves in section 4. The theme override set loses nothing it did not add (`render-link.html` under `layouts/enhancements/_markup/` is site-owned, not an override copy).
- **Published URLs.** None added or removed: `/docs/` pages of catalog_opm and opm keep their paths; `/enhancements/`, `/enhancements/<NNNN>/`, `/enhancements/<NNNN>/<slug>/` and `/enhancements/graph/` keep theirs. The version set is unchanged; 0021:OQ15 is not touched.
- **Behaviour change.** A docs-only merge to opm or catalog_opm reaches `v1.0` through a docs revision or a release, no longer at the next build; an enhancements merge reaches the site after its `edge` publish, not at the next site build from git.
- **Source repos (follow-ups, never edited from here).** catalog_opm `publish-site-docs-bundle` (G3.1); opm's two PRs and first release (G3.2), keeping `start/_index.md` and the `/docs/` landing `_index.md` (C16 D4: no other bundle may ship them); enhancements: the spike fixes and its `ci(docs)` PR, enhancements#86 (G3.3).
- **Depends on.** `pull-reference-bundles` section 2 merged (section 1 here); section 3 of it (the v1.0 switch) merged before section 2 here, so `v1.0` has a `versions` entry to add `tags` to.

Delivery: one PR per section (retire-git-pipeline needs all four merged; each section waits on its own producer's first bundle)

## Enhancement

None implemented, so no `enhancement.yaml`. It implements the site half of docs-kit phase 3 (`docs-kit DESIGN decision 9`, `17`, `18`, `19`, `21`) against docs-kit contracts C8, C15, C16 and C21.
