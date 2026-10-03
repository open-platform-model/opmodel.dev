## Why

Once `serve-docs-from-bundles` has merged, no site version reads a source repository from git: every `/docs/` page, the Catalogs tab and the Enhancements section come from signed docs bundles that `opm-docs pull` resolves, verifies, lints and locks. What remains of the git pipeline (a 900-line resolver, archives, host-side dates, dialect floors, a frozen-manifest recovery path, a shell copy of the page-dialect lint, six source checkouts in CI) has no input left to act on, and every line of it is a way for the build to disagree with the bundles. This change deletes it. It finishes docs-kit's plan for the site (`DESIGN.md` "Phase 3": the site build reads no git repository except its own) and unblocks docs-kit `retire-lint-conformance-binding` (G3.5).

## Gates

Named as in docs-kit's `docs/orchestration.md` (PR #13, `plan/phases-1b-2-3`).

- **Section 1 (spike) and section 2: no producer gate.** They need `serve-docs-from-bundles` section 1 merged (every fixture can be a bundle) and change nothing the real build reads.
- **Sections 3 and 4: G3.4**, the opm and enhancements bundles published and `v1.0` reading them: `serve-docs-from-bundles` sections 2, 3 and 4 merged. Merging this change is docs-kit's **G3.5**, which starts docs-kit `retire-lint-conformance-binding`.

## What Changes

- **Deleted:** `site/scripts/{resolve-versions,materialise,gen-lastmod,lint-sources}.sh`; `site/tests/versions/test-resolve.sh` and the resolver fixtures; `site/tests/lint/` and the shell-lint half of `test-site.sh`; the fixture workspace `site/tests/fixtures/ws/` (its pages become bundle fixtures); `frozen.conf` and the `build-manifest` artifact (the lock and a committed `site/bundles.frozen.json` replace them); the `versions:prepare`, `versions:check`, `versions:fetch` and `lint:sources` tasks; the six source checkouts and the source-root mounts (`OPM_WS`, `OPM_SRC_*`, `OPM_SRC_WORKTREE`); the git branches of `gen-mounts.sh`, `gen-stamp.sh`, `sections.sh` and `opm/source.html`; the byte-identical dialect contract copy in `openspec/changes/deploy-site/orchestration.md`.
- **Reduced:** `site/versions.conf` keeps only what C16 has no place for: each site version's `label`, `weight` and `default`. The version list itself is `bundles.cue` `versions`; the build fails when the two name different versions.
- **Replaced:** site-owned page dates (today from `materialise.sh`) by the mechanism section 1's spike picks; live editing of a source repository's pages (`OPM_VERSIONS=v1.0=/src task serve`) by `opm-docs serve`, or `opm-docs serve --site` through this repository's `task bundles:pull` and `task serve` with `OPM_BUNDLES_LOCAL`.
- **BREAKING (for contributors, not readers):** `OPM_VERSIONS`, `OPM_SRC_*`, `OPM_WS` and the `versions:*` tasks stop existing.

## Before / After

**Before**

```text
site/versions.conf      [repo "<six>"] floor = <sha>; [version "v1.0"] label, weight, default, from-bundles = <six>
site/scripts/           resolve-versions.sh (host), materialise.sh (host), gen-lastmod.sh, lint-sources.sh, gen-mounts.sh (git + bundles)
site/.versions/         versions.tsv, frozen.conf, <v>/<repo>/ archives, lastmod.tsv
site/tests/             fixtures/ws/<seven repos>, versions/{test-resolve,check-two-versions}.sh, lint/<34 cases>
Taskfile                versions:prepare, versions:check, versions:fetch, versions:test, lint:sources, bundles:pull, build, serve
.github/workflows/      site.yml checks out opmodel.dev + 7 repositories; build-manifest artifact (frozen.conf)
network                 task image, task qa:image, task versions:fetch, task bundles:pull
```

**After**

```text
site/versions.conf      [version "v1.0"] label = v1.0 (beta), weight = 1, default = true      (names must equal bundles.cue versions)
site/scripts/           gen-mounts.sh (bundles + site content), gen-site-dates.sh (if section 1 picks the host step)
site/.versions/         none
site/tests/             fixtures/bundles/ (every source page), versions/check-two-versions.sh (two bundle-backed versions)
Taskfile                bundles:pull, build, serve, versions:test (two bundle versions), ...
.github/workflows/      site.yml checks out opmodel.dev only; bundles-lock artifact is the build record
network                 task image, task qa:image, task bundles:pull
```

## Impact

- **Files.** The deletions above; `site/versions.conf`, `site/scripts/{gen-mounts,gen-stamp,sections,build-all,serve,run-in-image,check-pages,test-site}.sh`, `site/layouts/_partials/opm/{source,build-stamp}.html`, `site/layouts/_partials/components/last-updated.html`, `site/tests/versions/`, `Taskfile.yml`, `.github/workflows/site.yml`, `README.md`, `AGENTS.md`, `CONSTITUTION.md` (if it names the source lint), `openspec/config.yaml` (context and Principles I, II, III name the source lint and six repositories assembled from git).
- **Build inputs.** Lost: every source repository's git tree, the enhancements repository's, and the host-side resolve step. Kept: the docs bundles (by lock digest) and this repository. No theme file's override changes beyond branches removed from existing overrides.
- **Published URLs.** None. The version set is unchanged; 0021:OQ15 is not touched.
- **Source repos.** None must change. docs-kit follow-up: `retire-lint-conformance-binding` (G3.5).
- **Depends on.** `serve-docs-from-bundles` fully merged (G3.4).

## Enhancement

None implemented, so no `enhancement.yaml`. It completes the site half of docs-kit phase 3 against docs-kit contracts C7, C11 and C16.
