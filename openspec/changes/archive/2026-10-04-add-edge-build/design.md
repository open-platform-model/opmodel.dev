## Context

Since `pull-reference-bundles` (opmodel.dev#38), v1.0 reads cli 1.0.0-beta.7, core 2.0.0-beta.2, library 1.0.0-beta.3 and opm-operator 1.0.0-beta.5 from their release docs bundles; opm and catalog_opm still come from git. `sources-main` (`.github/workflows/site.yml`) waits for `build`, pulls its `bundles-lock` artifact `--frozen`, deletes the lock's `docs` entries and `_versions/`, and runs `OPM_VERSIONS=v1.0=/src task build`, so all six repositories are read from their shallow `main` checkouts. It publishes nothing and `pages-deploy` does not wait for it.

The pieces this change reuses:

- `opm-docs pull` (docs-kit C7, C16) resolves a site version from `anchor`, `pinned` and `tags`; a tag may be `edge`. A missing anchor or `tags` tag exits 2 naming the repository and the tag. The pull is atomic: nothing is swapped in unless every site version, tab, history and the lock pass.
- Explicit mode with `OPM_DOCS_BUNDLES=1` reads the lock's `docs` entries for the versions it builds and every other repository from its root (`gen-docs-bundles.sh`); the `from-bundles` mirror check runs only in manifest mode.
- `run-in-image.sh pull` mounts `site/bundles.cue` as the config and writes `site/.bundles/` (the pull sweeps what it did not write there); it applies a committed `site/bundles.frozen.json` when `OPM_BUNDLES_FROZEN` is unset. `sections.sh` fails a lock whose `config` digest is not `bundles.cue`'s; `gen-docs-bundles.sh` reads each docs project's signing repository from `bundles.cue`. `OPM_BUNDLES=<dir>` builds from another unpacked tree.

Files under `site/` touched: `scripts/edge-config.sh` (new), `scripts/run-in-image.sh`, `scripts/test-site.sh`, `tests/checks/edge-*` (new), `tests/fixtures/edge/` (new). Outside: `Taskfile.yml`, `.gitignore`, `.github/workflows/site.yml`, `README.md`, `AGENTS.md`, `openspec/changes/retire-git-pipeline/`.

## Goals / Non-Goals

**Goals:**

- Every repository's `main` is linted, built and link-checked together, the generated reference of core, cli and opm-operator included, before and after step 8 deletes their committed copies.
- The published build's inputs, failure surface and recovery stay exactly as they are.
- Nothing to edit when a project joins `docs` (phase 3's `opm` and `catalog-opm-docs`): the edge config follows `bundles.cue`.

**Non-Goals:**

- A published `/edge/` docs version (Decision 2 says why, and what it would need).
- Changing what v1.0 publishes, or 0021:OQ15.

## Decisions

### 1. C16 expresses "every project at its own edge tag" under a `vN.N` key

```cue
// site/.edge/bundles.cue, written by edge-config.sh: bundles.cue's registry, signer, tabs
// and docs verbatim, then
versions: "v1.0": {
	anchor: {project: "cli", tag: "edge"}
	tags: {"core": "edge", "library": "edge", "opm-operator": "edge"}
}
```

C16 lets the anchor sit at `edge` and pulls `tags` projects at their own tag; with no `pinned`, the cli edge bundle's pins (released versions) are read into the lock and choose nothing. The pull cross-checks the four edge bundles for nested owned paths and colliding pages, which is the first thing a step-8 retirement could break. Verified 2026-10-04 with `opm-docs` at docs-kit `v0.6.0` (the site's pin) against GHCR, anonymously: cli (anchor) `ae60f00718`, core `9bee9726f5`, library `553b8555cd`, opm-operator `d2dda57e08` resolved, verified and unpacked, with the catalog tab beside them.

Implemented and re-verified 2026-10-04 (task 1.3): a real `task build:edge` in the implementing worktree, with opm and catalog_opm at their `origin/main` (`01b8ca5`, `6bb1e10`), pulled cli (anchor) `sha256:61a0e33663` at commit `2d939fb826`, core `sha256:ed78edb708` at `1a68ee3d6c`, library `sha256:5fdfb743d8` at `82412504b0` and opm-operator `sha256:7b6ca6f791` at `2f2d5ded5c` (each its repository's `main` head that day), with catalog-opm 4.5.1 and edge, and built green: v1.0 84 pages (the same count as the published build), the Enhancements section 218, the Catalogs section 152. `site/.bundles/lock.json` was byte-identical before and after. With `OPM_BUNDLES_LOCAL="core@v1.0=<core>/out/core"` (a `task docs:bundle` in a clone of core at `origin/main`) the stamp records core as `tag`, `local`, version `edge`, and the build is green. A local bundle's `source.repo` comes from the clone's `origin` URL, so a clone whose `origin` is a local path fails `gen-docs-bundles.sh`'s signing-repository check; build the local bundle in a checkout whose `origin` is the GitHub repository.

What C16 cannot express is a site version *named* `edge`: `#SiteVersion` in `schema/pull.cue` and `schema/lock.cue` is `^vN.N$`, and C16's `--local <project>@v<M>.<m>` and `serve --site-version` assume it. A CI-only build does not need the name (Decision 2), so docs-kit needs no change here. The key stays `"v1.0"`, the version the explicit build already builds, so `gen-docs-bundles.sh` accepts the entries as they are.

**Derived, not committed.** `edge-config.sh` copies `bundles.cue` line by line, keeping every top-level block and comment in order, before and after `versions` (a `sections` block that `serve-docs-from-bundles` adds after it included), drops only the top-level `versions:` block (from its line through its closing `}` at column 0), and appends the edge block at the end, listing every quoted key of `docs` except `cli` under `tags`. A second committed file would copy the trust policy (signer, each project's `repo`) and could drift from it; deriving makes drift impossible. It refuses a `bundles.cue` with no `"cli"` under `docs` or a `versions` block it cannot find, naming the file.

### 2. A CI-only build, not a published version

Owner answer, 2026-10-04, to "the edge site version as CI-only or published /edge/?": "CI-only (Recommended)".

Publishing `/edge/` would add the four products' `main` to every published build. The pull is atomic and a failing build holds the deploy ("the whole manifest fails, never one version", README "Site versions"), so any push to any product's `main` that breaks a cross-repository link, publishes a colliding page or fails a bundle check would stop the release docs from deploying until it was fixed upstream or frozen. Today `sources-main` gives that warning without holding anything, which is what OQ1 asked to keep. A published version would also need reader-facing choices the owner has not made (banner wording, search scope) and a docs-kit change first (Decision 1).

So: the edge build runs only in `sources-main` and `task build:edge`. It builds `v1.0` (its default `/v1.0/` URL and label) into a `site/public/` the job discards; it uploads no site, no Pages artifact and no stamp. Nothing reaches the sitemap, `llms.txt`, the switcher or search, so no `noindex` or "unreleased" marking applies. The only published trace is the job's summary.

**If publishing is wanted later**, it is its own pair of changes. docs-kit first: `#SiteVersion` admits `edge` in `pull.cue` and `lock.cue`; an `edge` site version must have no `pinned` and only `edge` tags (exit 1 otherwise, so the name cannot lie); `--local <project>@edge` names the site version when the project is a docs project (tabs and docs projects are disjoint, C16); `serve --site-version edge`; lock order puts `edge` after every `vN.N`. Then the site: the resolver accepts the name `edge`, `label = main (unreleased)` like the Catalogs tab's edge, `/edge/` with no `/latest/` stubs, `noindex`, out of the sitemap and `llms.txt`, last in the switcher, an unreleased banner on every page, its own Pagefind index; and a way to keep a broken edge from holding the release deploy (a second pull and build whose failure does not gate `pages-deploy`, or accept freezing).

### 3. Config and output selection

```text
OPM_BUNDLES_CONFIG   pull only: the pull config; default site/bundles.cue
OPM_BUNDLES_OUT      pull only: where the pull writes; default site/.bundles
OPM_BUNDLES          build only, unchanged: the unpacked tree a build reads
```

`run-in-image.sh pull` mounts `OPM_BUNDLES_CONFIG` and writes into `OPM_BUNDLES_OUT`; its quoted-key reads (`keys_of`, the site-version keys) read the same config. The pull never reads `OPM_BUNDLES`: that variable already means a tree a build reads (a saved tree, the committed fixtures), and since the pull sweeps its output directory, giving it a write meaning would let a plain `task bundles:pull` with `OPM_BUNDLES` exported wipe the fixtures. The build side changes nothing: with `OPM_BUNDLES` set, `sections.sh` already skips the lock's config-digest check, and `gen-docs-bundles.sh` reads each docs project's signing repository from `site/bundles.cue`, whose `docs` block the derived config copies verbatim, so neither script learns about `OPM_BUNDLES_CONFIG`. Because `opm-docs pull` sweeps its output (every entry it did not write is removed), `OPM_BUNDLES_OUT` must resolve to a dot-directory under `site/` (`site/.bundles`, `site/.edge/bundles`) that holds no tracked file and, when it is not empty, a `lock.json`; anything else is refused before a container starts (review finding, 2026-10-04). When `OPM_BUNDLES_CONFIG` names a file other than `site/bundles.cue`, a committed `site/bundles.frozen.json` is not applied, with a line saying so: it was pulled for `bundles.cue` and `opm-docs` would refuse it (C7, `--frozen`). An explicit `OPM_BUNDLES_FROZEN` still applies, which is how a failed edge run is reproduced from its `edge-lock` artifact.

```text
task build:edge
  sh site/scripts/edge-config.sh                          -> site/.edge/bundles.cue
  OPM_BUNDLES_CONFIG=site/.edge/bundles.cue OPM_BUNDLES_OUT=site/.edge/bundles  task bundles:pull
  OPM_BUNDLES=site/.edge/bundles OPM_VERSIONS=v1.0=/src OPM_DOCS_BUNDLES=1 OPM_REQUIRE_DATES=0  task build
```

Its own output directory, so a local `task build:edge` never replaces the lock `task build` reads. `site/.edge/` is gitignored.

`OPM_BUNDLES_LOCAL` passes through to the pull as it does for `bundles:pull`, so a product checks a branch against every other `main` before merging it: `OPM_BUNDLES_LOCAL="core@v1.0=<core>/out/core" task build:edge`. The step-8 retirements in core, cli and opm-operator use exactly this as their pre-merge check, with opmodel.dev, opm and catalog_opm at `origin/main` first (explicit mode reads opm and catalog_opm from the workspace checkouts).

**Author previews after step 8.** Explicit mode without `OPM_DOCS_BUNDLES=1` (`OPM_VERSIONS=v1.0=/src task build|serve`, the worktree builds) reads core's, the cli's and the operator's `docs/site/` in place; once step 8 deletes their committed reference, every page linking it fails that build's link crawl. From then on a local check of every `main` is `task build:edge`, and a live preview of one repository's pages is `opm-docs serve` or `OPM_DOCS_BUNDLES=1` after a pull. README and AGENTS say so (task 2.3).

### 4. `sources-main`

```yaml
sources-main:
  name: Source pages on main (not published)
  # no needs: it pulls its own edge bundles
  steps: [the eight shallow checkouts as today, setup-task,
          task build:edge,
          upload edge-lock (site/.edge/bundles/lock.json, 7 days, if: always() after the pull),
          summary: one row per docs entry (project, role, commit, digest) and per catalog segment]
```

The build job's lock is no longer downloaded: its `config` digest is `bundles.cue`'s, so `opm-docs` refuses it for the edge config, and this job's subject is the newest `main`, not what deploys. The four product checkouts stay because explicit mode checks every root before a container starts; `retire-git-pipeline` removes them with explicit mode.

**Failure modes.** Each fails this job only; `build`, `browser` and `pages-deploy` do not read it.

| Cause | What fails | Message names |
|---|---|---|
| A product has no `edge` tag (package deleted, made private, never published since adoption) | `opm-docs pull`, exit 2 | the repository and `edge` (C16; a 401 or 403 counts as missing) |
| An edge bundle fails lint, signature or placement | `opm-docs pull`, exit 2 | the project and digest |
| Two products' `main` own nested paths or publish one URL | `opm-docs pull`, exit 2 | both projects and the path |
| A `main` page links a page no `main` has | `task build` link crawl | the page and the link |
| GHCR or Sigstore outage | `opm-docs pull` | the registry error; rerun |

There is no fallback to git for a missing edge bundle: after step 8 a product's `main` checkout lacks its generated reference, so a git fallback would report false broken links or, worse, skip the check the job exists for.

### 5. `retire-git-pipeline`

That change removes explicit mode, `OPM_VERSIONS` and the source checkouts. `build:edge` then builds in manifest mode like `build` (the derived config's `v1.0` is the only version, every repository from a bundle once phase 3 is done), and `sources-main` checks out only this repository. One line each in its design (Decision 6) and its task 3.3 says so.

## Research & Decisions

### Can the pinned opm-docs pull an all-edge site version?

**Context**: OQ1 suggested "a second `bundles.cue` `versions` entry, or a CI-only config"; either needs C16 to accept an anchor at `edge` with every other project under `tags`.
**Explored**: `schema/pull.cue` and `internal/pull/versions.go` at docs-kit `v0.6.0`; a real pull with the config of Decision 1 (opm-docs built from docs-kit `af41101`, the `v0.6.0` release commit), anonymous, against `ghcr.io/open-platform-model/docs`.
**Decision**: a CI-only derived config under the key `"v1.0"`; no docs-kit change.
**Rationale**: the pull succeeds today; only the site-version name is constrained, and a CI-only build needs no new name.

## Risks / Trade-offs

- [A product's `main` breaks the edge build for days and nobody looks at a job that blocks nothing] -> The same as today's `sources-main`. The job turns every opmodel.dev PR's checks red. The step-8 retirements check their branch with `task build:edge` before merging and confirm the next `sources-main` run is green after their `edge` publish (their tasks and docs-kit's step 8 say so).
- [The edge build checks the catalog tab at its newest digests, not what deploys] -> Intended: the `browser` job still checks what deploys.
- [`edge-config.sh` misreads a reformatted `bundles.cue`] -> It refuses what it cannot find, and a check case derives from a fixture config (with a `sections` block after `versions`) and compares byte for byte.
- [Edge docs bundles name released pins nobody resolves] -> Expected; the lock records them on the anchor and nothing reads them in this build.

## Durable decisions

- The edge build: what it reads, that it is CI-only and never published, its derived config, and that a missing edge bundle fails it with no git fallback. Lands in `README.md` (CI: the `sources-main` row and bullet; "Docs bundles in a site version") and `AGENTS.md` (Site versions, "Docs bundles in a site version"; Build And Dev Commands: `task build:edge`).
- `OPM_BUNDLES_CONFIG` and `OPM_BUNDLES_OUT` (pull only; `OPM_BUNDLES` stays build only), and that a committed `bundles.frozen.json` applies only to `bundles.cue`. Lands in `AGENTS.md` (Environment Notes) and the `bundles:pull` comment in `Taskfile.yml`.
- After step 8, a local check of every `main` is `task build:edge`; explicit mode without `OPM_DOCS_BUNDLES=1` no longer resolves links into the generated reference. Lands in `README.md` (Quick Start, the worktree-build lines, Contributing "Preview") and `AGENTS.md` (Environment Notes "Source repositories", Build And Dev Commands `task serve`).
- What a published edge version would need (Decision 2). Stays with the change; the owner decides if it is wanted.
