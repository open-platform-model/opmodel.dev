## Why

CI's `sources-main` job builds every source repository's `main` together (explicit mode, `OPM_VERSIONS=v1.0=/src`), so a page that breaks the lint, a build check or a link fails here before it is released. It reads all six repositories from their git checkouts. docs-kit orchestration step 8 deletes the committed generated reference in core, cli and opm-operator (their generators move into the docs bundles they publish); after that their `main` checkouts hold no `reference/definitions/`, `reference/cli/` or the generated half of `reference/operator-resources.md`, and every `main` page linking one fails the job.

`pull-reference-bundles` left this as its OQ1. Owner decision, 2026-10-04, asked "(a) an edge site version for sources-main versus (b) keeping the four products on their bundles there": **(a)**. This change builds it: the four products come from their `edge` docs bundles (every product publishes one on each push to `main`), opm and catalog_opm from their `main` checkouts, all checked together.

## Gates

- **Section 1:** none. The pinned `opm-docs` (0.6.0) already pulls a site version whose anchor and every other project sit at `edge`: a scratch pull on 2026-10-04 resolved and verified cli, core, library and opm-operator `edge` and passed the cross-bundle checks (design.md Decision 1).
- **Section 2:** section 1 merged. Merging it is the `sources-main` switch, docs-kit's **G2-edge** (docs-kit#43): the step-8 retirements in core, cli and opm-operator wait for it, beside G2-switch.

## What Changes

- **Not a published version.** The edge build is CI-only: nothing it builds is uploaded or deployed, and the published site's version set, URLs, sitemap and switcher do not change (design.md Decision 2).
- `site/scripts/edge-config.sh` derives the edge pull config from `site/bundles.cue`: every top-level block kept in order, with `versions` replaced by one entry, `"v1.0"`, whose anchor is `cli` at `edge` and whose `tags` put every other `docs` project at `edge` (no `pinned`).
- `OPM_BUNDLES_CONFIG` and `OPM_BUNDLES_OUT` name the pull's config and output directory (defaults `site/bundles.cue`, `site/.bundles`); `OPM_BUNDLES` keeps meaning only the tree a build reads. With another config, a committed `site/bundles.frozen.json` is not applied (it was pulled for `bundles.cue`).
- `task build:edge`: derive, pull into `site/.edge/bundles/`, then build in explicit mode with the lock's docs entries (`OPM_VERSIONS=v1.0=/src OPM_DOCS_BUNDLES=1`).
- `sources-main` runs `task build:edge`, pulls on its own (no longer the build job's lock, so it no longer waits for `build`), and records the edge digests in its summary and an `edge-lock` artifact.
- `retire-git-pipeline` keeps the edge build working when explicit mode goes (one line in its design and tasks).

## Before / After

**Before**

```text
sources-main          needs: build; pulls bundles-lock --frozen; drops the lock's docs entries
                      OPM_VERSIONS=v1.0=/src task build      six repositories from their main checkouts
site/bundles.cue      the only pull config
```

**After**

```text
site/scripts/         + edge-config.sh   site/bundles.cue -> site/.edge/bundles.cue
site/.edge/           (gitignored) bundles.cue, bundles/{lock.json, catalog-opm/..., _versions/v1.0/...}
Taskfile              + build:edge
sources-main          no needs; task build:edge
                      v1.0  cli (anchor, edge), core, library, opm-operator (tags, edge)  <- docs bundles
                            opm, catalog_opm                                               <- main checkouts
                      uploads edge-lock (7 days); publishes nothing
site/.edge/bundles.cue
  versions: "v1.0": {
      anchor: {project: "cli", tag: "edge"}
      tags: {"core": "edge", "library": "edge", "opm-operator": "edge"}
  }
```

## Impact

- **Files.** `site/scripts/{edge-config (new),run-in-image,test-site}.sh`, `Taskfile.yml`, `.gitignore`, `.github/workflows/site.yml` (`sources-main`), `site/tests/checks/` (new cases), `site/tests/fixtures/edge/` (new), `README.md` (CI, "Docs bundles in a site version", Quick Start, Contributing), `AGENTS.md` (Site versions, Environment Notes, Build And Dev Commands), `openspec/changes/retire-git-pipeline/{design,tasks}.md`.
- **Build inputs.** The published build: none change. `sources-main`: gains the four products' `edge` docs bundles and the catalog tab resolved fresh; loses the build job's frozen lock.
- **Published URLs.** None. The version set is unchanged and 0021:OQ15 is not touched.
- **Other repositories.** docs-kit's orchestration names G2-edge as a gate of step 8; core, cli and opm-operator name it on their retire sections. No docs-kit contract changes: C16 already expresses an all-edge site version under a `vN.N` key (design.md Decision 1).

## Enhancement

None. It answers `pull-reference-bundles` OQ1 (owner, 2026-10-04) against docs-kit contracts C7 and C16.
