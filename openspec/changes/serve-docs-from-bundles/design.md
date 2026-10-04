## Context

After `pull-reference-bundles`, the site mounts a bundle-backed repository's `content/` per site version (`gen-docs-bundles.sh`, `data/opm/docs-bundles.json`, the repository table in its design.md Decision 1, `versions.conf` `from-bundles` as the host mirror). `catalog-opm-docs` and `opm` are already rows of that table; adding them is configuration plus fixtures.

The Enhancements section today is git-built: `sections.sh` takes the archive `materialise.sh` wrote for `[section "enhancements"]`; `gen-mounts.sh` mounts its files at `assets/enhancements` and writes `.gen/enhancements/_index.md` from `INDEX.md` and `data/opm/enhancements.json` (every repository path, for the link hook); `site/enhancements/_content.gotmpl` adds every page with `url`, header data from `config.yaml`, cleaned by `opm/enh-clean.html`; `layouts/enhancements/_markup/render-link.html` resolves relative links. docs-kit `add-enhancements-bundle` (C21, read at `origin/plan/phases-1b-2-3`) moves the page building, comment stripping and link resolution to the producer (D2, D3), ships `data/enhancements.json` (D4) and pulls the section to `<out>/enhancements/edge/` with a lock `bundles` entry rooted at `/enhancements/` (D5).

## Goals / Non-Goals

**Goals:**

- Serve catalog_opm's docs, opm's docs and the enhancements from bundles, each as soon as its producer publishes, with no URL change.
- Keep every site behaviour of the Enhancements section that is the site's (placement outside versions, menu entry, header, Mermaid diagrams, noindex/llms exclusions), and drop the ones the producer took over.

**Non-Goals:**

- Deleting `resolve-versions.sh`, `materialise.sh`, `gen-lastmod.sh` or the source lint (`retire-git-pipeline`).
- Versioning the enhancements (`docs-kit DESIGN decision 18`: edge only).

## Decisions

### 1. catalog_opm and opm: configuration only

```cue
docs: {
	"catalog-opm-docs": {repo: "open-platform-model/catalog_opm"}
	opm:                {repo: "open-platform-model/opm"}
}
versions: "v1.0": tags: {"catalog-opm-docs": "4", opm: "1.0"}
```

`catalog-opm-docs` takes the major tag `4`, as `catalog-line = opm-v4` does today; `opm` takes `1.0`. `versions.conf` `from-bundles` gains `opm` (section 3, first), then `catalog_opm` (section 2); `catalog-line` is removed with catalog_opm. A version whose `from-bundles` names opm has no `opm` key and never reads opm's `main`. A version whose `from-bundles` names all six has no git row; `resolve-versions.sh` writes one row with empty repository fields (its label, weight and default), and `materialise.sh` and `gen-lastmod.sh` have nothing to do for it.

The `/docs/` landing (`_index.md`) and `start/_index.md` are opm's (C16 D4 refuses a second bundle shipping them; the site's A1 refuses a site-owned copy).

### 2. The Enhancements section from its bundle

The adapter stays, rewritten, because Hugo publishes a page outside `/<version>/` only with `url` set, and a bundle page's front matter cannot carry `url` (the page dialect forbids it). docs-kit's orchestration says to delete `site/enhancements/_content.gotmpl`; this design keeps a smaller one.

```text
mounts      <CAT_DIR>/enhancements/edge/{manifest.json,content/**,data/enhancements.json} -> assets/sections/enhancements
            site/enhancements/ and .gen/enhancements/ -> content/enhancements (default version only, unchanged)
adapter     for each manifest page except content/_index.md:
              path  = page path without .md (NNNN/_index -> NNNN)
              url   = /enhancements/<path>/
              title, description, weight, type: from the page's front matter
              params.enhancement = data entry whose page or documents[].page matches (header: status, category, affects, dates, links)
              params.source      = {repo, path: pages[].source, commit: source.commit}
              dates.lastmod      = entry.updated (README) or pages[].lastmod (documents)
              sitemap.disable = true; params.llms = false
section     .gen/enhancements/_index.md = content/_index.md with "url: /enhancements/" and the params block inserted
            into its front matter (gen-mounts.sh; an adapter cannot add the empty path)
```

`opm/enh-status.html` reads `params.enhancement` (C21 D4 field names) instead of `config.yaml`'s; `opm/source.html` names `params.source` and no Edit (C8 table: a section page has none). `enh-clean.html`, the section link hook and `data/opm/enhancements.json` are deleted: the producer has applied D3's transforms, and a link it could not resolve failed its build. The Mermaid render hook and the diagram scroller are unchanged; they key on the section, not on the source.

`gen-catalogs.sh` reads only lock `bundles` entries whose `root` starts with `/catalogs/` (the section's entry has root `/enhancements/`); the catalogs mount `*/*/content/**` also matches `enhancements/edge/content/**`, which the catalogs adapter never lists, so its "file that is no listed page" refusal is scoped to catalog projects in `catalogs.json` (checked by a case).

`sections.sh`: the section exists when the lock has a `/enhancements/` entry (manifest mode) or `OPM_BUNDLES` holds `enhancements/edge/` (explicit and fixture mode); `ENH_TREE`, `ENH_PATHS`, `ENH_REF`, `ENH_HOW` give way to `ENH_DIR` and the lock entry. `gen-stamp.sh` `sections.enhancements` becomes `{project, digest, commit, local}`.

**As built (2026-10-04).** Three simplifications, each keeping the behaviour above. (1) No new mount: the catalogs mount of `CAT_DIR` at `assets/bundles` already holds `enhancements/edge/{manifest.json,content/**,data/*.json}`, so the adapter reads `bundles/enhancements/edge/`. (2) The page params keep their old flat names (`status`, `category`, `affects`, `created`, `updated`, `dependsOn`, `amends`, `supersedes`, `revives`, `supersededBy`, `enhId`, `repoPath`), because C21 D4's field names are the same. So `opm/enh-status.html` and `opm/source.html` read the data unchanged: `repoPath` is the page's manifest `source`, and `sections.enhancements.sha` is the bundle's commit. (3) The page's `type` from its front matter is dropped, so the section's own layouts and Mermaid hook still apply. `gen-stamp.sh` writes `{project, ref, sha, how, digest, local}`, keeping `ref`, `sha` and `how` for the footer and the CI summary. The bundle checks (placement, content against manifest, a data entry per entry page) run in `gen-mounts.sh`. Also as built: the section cut over in one step (no period with both paths), so the git path and its `[section]` resolver code, archive, root mount and CI checkouts went in the same PR.

### 3. Fixtures

```text
site/tests/fixtures/bundles/_versions/v1.0/catalog-opm-docs/   a catalog how-to page linking /catalogs/opm/4/ and a /docs/ page of opm
site/tests/fixtures/bundles/_versions/v1.0/opm/                _index.md (the /docs/ landing), start/_index.md, one concept page
site/tests/fixtures/bundles/enhancements/edge/                 opm-docs build output of ws/enhancements committed as one commit (as built: not hand-written)
```

The two docs fixtures pull through the tool pinned since `pull-reference-bundles` section 2 (`--local catalog-opm-docs@v1.0=...`, `--local opm@v1.0=...`) and join the drift test in section 1. The enhancements fixture is the current `site/tests/fixtures/ws/enhancements/` run through D2/D3 by hand: one live and one archived entry, the graph, a Mermaid fence, a link of each kind already resolved. Section 4 re-pulls it with `--local enhancements@edge=...` and the drift test covers it. As built, the enhancements fixture is not hand-written: `opm-docs build` (the pinned 0.6.0) writes it from `site/tests/fixtures/ws/enhancements/` committed in a throwaway repository with fixed author and dates, so the fixture is exactly what the producer writes, and no hand-written tree can drift from C21 (README "The Enhancements section").

### 4. Lint

Section 4 copies docs-kit's `link-enhancements-graph` conformance case into `site/tests/lint/`, and `lint-sources.sh` and its byte-identical contract copy accept `/enhancements/graph/` (with an optional fragment) on docs pages, matching the fixture's expected output (C11 re-sync rule). The shell lint runs over no tree once `v1.0` has no git row; it stays, with its cases, until `retire-git-pipeline`.

## Research & Decisions

### Keep a bundle-reading adapter instead of deleting it

**Context**: docs-kit's orchestration deletes `site/enhancements/_content.gotmpl` in phase 3.
**Explored**: Hugo's `url` front matter is the only way the site publishes a page outside the `/<version>/` prefix (the Catalogs and Enhancements sections both rely on it); a mount cannot add front matter; the page dialect bans `url` in bundle pages; a `cascade` cannot compute a per-page `url`.
**Decision**: keep an adapter that reads the bundle and sets `url` and the page params, about a third of today's size.
**Rationale**: it is the same mechanism the Catalogs section uses for the same reason.

### One section per producer, plus a fixture section

**Context**: docs-kit's plan has three site sections, each gated on a producer.
**Decision**: a first section with every fixture and the site-side machinery, mergeable before any producer is ready; the three gated sections are then configuration, a real-pull check and deletions.
**Rationale**: fixture work starts at once and survives a session boundary as a commit; each gated section is small when its producer lands.
**Revised 2026-10-04**: every producer had published before section 1 started, so its fixtures ride their producers' sections (tasks.md, the revision note), delivered as opm, catalog_opm, enhancements.

## Risks / Trade-offs

- [The enhancements bundle's lint refuses what the repository's own link check accepts] -> blocks the enhancements repository's `main`, not the site; docs-kit `add-enhancements-bundle`'s spike sizes it first, and enhancements#86 fixes the sources.
- [opm has no release before the owner sets up release-please] -> did not happen: opm released `1.0.0-beta.1` (G3.2) before section 3 started.
- [The site loses the per-build enhancements SHA from git] -> the bundle's `source.commit` names it, in the stamp and on every page's View source.

## Durable decisions

- The Enhancements section is built from the `enhancements` section bundle at `edge`; the site sets `url` and header params only, and never rewrites its pages. Lands in `AGENTS.md` (Site versions, "The Enhancements section") and `README.md` ("The Enhancements section").
- `catalog-opm-docs` follows the catalog's major tag, `opm` the site version's minor. Lands in `README.md` ("Site versions").
- Every `v1.0` page under `/docs/` comes from a docs bundle. Lands in `AGENTS.md` (Purpose, Site versions) and `openspec/config.yaml` (context, Principle I).
