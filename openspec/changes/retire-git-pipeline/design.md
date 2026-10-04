## Context

After `serve-docs-from-bundles`, `v1.0`'s `from-bundles` names all six repositories and the Enhancements section comes from its bundle, so `resolve-versions.sh` resolves no row, `materialise.sh` archives nothing, `gen-lastmod.sh` dates only site-owned pages, and the source lint (`lint-sources.sh`) runs over no tree. Their remaining users are the tests: the fixture workspace `site/tests/fixtures/ws/` (a git-shaped tree of the seven repositories, read in explicit mode), the resolver tests and the two-version build (`site/tests/versions/`), and the shell half of the conformance set (`site/tests/lint/`, which binds the shell lint to docs-kit's until this change, AGENTS.md Repository Rules).

Hugo's own GitInfo is off (`enableGitInfo = false`): site-owned page dates come from `materialise.sh` on the host, because a worktree's `.git` is a file naming a host path the build container does not mount (AGENTS.md Environment Notes, "Git dates"). docs-kit's orchestration says "site-owned pages keep Hugo's GitInfo"; that does not work in a worktree build, which is how this repository is usually built, so section 1 is a spike.

## Goals / Non-Goals

**Goals:**

- The build reads no git repository but its own, and no source-root environment variable exists.
- Every test that built from the fixture workspace builds from bundle fixtures and still fails on its fixture.
- Site-owned pages keep their "Last updated" date in a worktree build and in CI.

**Non-Goals:**

- Changing docs-kit's conformance set (`retire-lint-conformance-binding` does, after this merges).
- A second site version (none is planned; the two-version test keeps proving the machinery).

## Decisions

### 1. Site-owned dates (spike, section 1)

Candidates, measured in section 1 in a worktree build, a main-checkout build and CI:

```text
a  enableGitInfo = true, mount the git common dir read-only into the container      Hugo's own dates; needs a second mount and GIT_DIR wiring
b  gen-site-dates.sh on the host (git log -1 --format=%cI per site/content page)    ~10 pages; writes data/opm/lastmod.json as today
   -> data/opm/lastmod.json, run by build and serve before the container
c  no date on site-owned pages                                                     simplest; a visible regression on the landing and overviews
```

Expected outcome, to confirm: **b**, because it is `materialise.sh`'s date step reduced to one repository, keeps `last-updated.html`'s data path, and needs no new mount. The spike writes the measured result into this section and the choice is final then.

### 2. Site versions

```ini
; site/versions.conf: display data for the site versions bundles.cue lists. The list itself is
; bundles.cue `versions`; a name here that is not there, or the reverse, fails the build.
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
```

Any other key fails the build naming it. `sections.sh` reads the version list from the lock's `docs` entries (`site` values), checks it against `versions.conf`, and passes `VERSIONS` as `v1.0=<CAT_DIR>/_versions/v1.0` pairs; `gen-mounts.sh` loses its `REPOS` loop and mounts only bundles and `site/content`. `from-bundles` is deleted (every repository is bundle-backed).

### 3. Tests

```text
site/tests/fixtures/ws/                -> deleted; its docs/site pages become the content of
site/tests/fixtures/bundles/_versions/v1.0/<project>/   (already there for most since pull-reference-bundles and serve-docs-from-bundles)
site/tests/fixtures/bundles/_versions/v0.9/<project>/   a second version (fewer pages, an older cli pin)
site/tests/versions/check-two-versions.sh               builds v1.0 and v0.9 from bundles; asserts each publishes its own pages,
                                                         the switcher, the catalogs and enhancements published once outside both
site/tests/subpath/                                     unchanged, built from the bundle fixtures
```

Every check case that used the fixture workspace takes a bundle fixture instead; a case that only exercised the resolver, archives or floors is deleted with them. The drift test (re-pull every fixture offline, byte-compare) covers all fixtures.

### 4. Lint

`lint-sources.sh`, its contract copy in `openspec/changes/deploy-site/orchestration.md` and `site/tests/lint/` are deleted: every page the site publishes from a source repository was linted by `opm-docs lint --bundle` at pull (C11), and site-owned pages were never in the shell lint's scope. The site keeps no conformance copy (decided here; docs-kit's orchestration leaves it to the site). `deploy-site` is an active change; this edits only its dialect-contract appendix, replacing the copy with a pointer to docs-kit C11.

### 5. Recovery and record

`frozen.conf` and the `build-manifest` artifact go: a bad bundle is recovered with a committed `site/bundles.frozen.json` (already the rule, AGENTS.md Repository Rules), and the `bundles-lock` artifact plus `build-stamp.json` are the build's record. `gen-stamp.sh` drops `sources` and `versions.<v>.refs`, keeps `site`, `sections` and `versions.<v>.bundles`.

### 6. CI and Taskfile

`.github/workflows/site.yml` checks out only this repository in every job; the source-checkout steps, their `fetch-depth: 0`, `OPM_REQUIRE_DATES` for source pages and the `build-manifest` upload go. Taskfile loses `versions:prepare`, `versions:check`, `versions:fetch`, `lint:sources`; `build` and `serve` depend on a current lock instead of `versions:prepare`; `versions:test` builds the two bundle versions. `run-in-image.sh` loses `sources()`, the `/src/<repo>` mounts and `OPM_BUILD_REFS`. `task build:edge` (`add-edge-build`) then builds in manifest mode like `build`, over the derived config's `v1.0`, every repository from a bundle once phase 3 is done, and `sources-main` checks out only this repository like every other job.

## Research & Decisions

### Keep a conformance copy of the lint fixtures?

**Context**: docs-kit's orchestration says keep `site/tests/lint/` only if the site still wants it.
**Decision**: no. With no shell lint there is nothing for the copy to test; docs-kit's own tests keep the cases.
**Rationale**: a copy no check reads drifts silently (Principle II).

### Site-owned dates

**Context**: docs-kit's plan assumes Hugo GitInfo; the container cannot read a worktree's git.
**Decision**: spike first (section 1), expected option b.
**Rationale**: worktree builds are the norm here; a date mechanism that works only from a main checkout would leave every worktree build undated while CI passes, so local and CI output would differ.

## Risks / Trade-offs

- [Contributors lose `OPM_VERSIONS=v1.0=/src task serve`] -> `opm-docs serve` (embedded preview, live reload) and `opm-docs serve --site` (this site, `OPM_BUNDLES_LOCAL`); README's contributor section says which to use.
- [A bundle pulled with a lint bug passes] -> the same risk as any docs-kit bug; fixed in docs-kit and re-pulled, never patched here.
- [versions.conf and bundles.cue drift] -> the build fails on any difference.

## Durable decisions

- The site build reads no git repository except its own; every source page arrives in a signed docs bundle. Lands in `AGENTS.md` (Purpose, Repository Rules, Site versions), `README.md` ("Sources", "Site versions") and `openspec/config.yaml` (context, Principles I, II, III).
- `site/versions.conf` holds only display keys; the version list is `bundles.cue` `versions`. Lands in `AGENTS.md` (Site versions, "One manifest").
- The page dialect is enforced by `opm-docs lint` at pull; the site has no shell lint and no conformance copy. Lands in `AGENTS.md` (Repository Rules, "The source lint is the page dialect" rewritten) and `README.md` ("Page dialect").
- Previewing a source repository's pages: `opm-docs serve` or `opm-docs serve --site`. Lands in `README.md` ("Contributing") and `AGENTS.md` (Build And Dev Commands).
- Site-owned page dates: as section 1 decides. Lands in `AGENTS.md` (Environment Notes, "Git dates").
