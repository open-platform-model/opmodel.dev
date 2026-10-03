## Context

Today every site version mounts the six source repositories' `docs/site/` at `content/docs`, from archives `materialise.sh` writes per version (`gen-mounts.sh`); "Edit", "View source" and "Last updated" come from git (`opm/source.html`, `gen-lastmod.sh`); the source lint runs over every tree first (`lint-sources.sh`); two site-owned placeholders stand in for the cli and definitions reference until a tree publishes the same page. The Catalogs tab already pulls signed bundles (`site/bundles.cue`, `task bundles:pull`, `gen-catalogs.sh`).

docs-kit's phase-2 contracts, read at `origin/plan/phases-1b-2-3`: C15 (docs placement, `owns`, completable pages, pins in `manifest.json`; `generalize-build-assembly` D2/D3/D7), C16 (pull config `docs`/`versions`, the `_versions/` layout, the lock's `docs` key, `--local <project>@v<M>.<m>`; `pull-docs-placement` D1 to D6), and `pages[].edit` with the Edit/View-source table (`add-authored-docs` D1, recorded in C8). Cross-bundle `/docs/` links are left to the site's post-build link check (C15).

The build gains one input set (docs bundles per bundle-backed site version) and, in section 2, loses four git archives for `v1.0`. URLs and the version set do not change. `last-updated.html`, already an override, gains a branch; no new theme file is overridden.

## Goals / Non-Goals

**Goals:**

- A site version reads a repository from its docs bundle or from git, per version, decided by the lock alone, so one repository can cut over at a time.
- Bundle pages behave like git pages for every check (A1, page set, links, front matter) and carry the manifest's page data.
- Section 1 (support) is built and tested on fixtures and merges with no change to the real output: the real config gains only `docs`, without `versions`.

**Non-Goals:**

- catalog_opm's docs, opm, the enhancements (`serve-docs-from-bundles`), deleting the git pipeline (`retire-git-pipeline`).
- Computing pins or resolving bundle tags in the site (`opm-docs pull` does both, C16 D2).

## Decisions

### 1. Which repository a version reads from where

The pull's lock is the only source of truth inside the build. `gen-docs-bundles.sh` maps lock `docs` entries to repositories with one fixed table:

```text
project            repository
cli                cli
core               core
library            library
opm-operator       opm-operator
catalog-opm-docs   catalog_opm     (serve-docs-from-bundles)
opm                opm             (serve-docs-from-bundles)
```

For each site version, a repository whose project the lock names for that version is bundle-backed; the others come from git. `resolve-versions.sh` runs on the host before the build and cannot read CUE, so `site/versions.conf` mirrors the set as `from-bundles = <repo> ...` on the version; `gen-docs-bundles.sh` fails when the mirror and the lock disagree ("v1.0: versions.conf from-bundles names cli core library opm-operator, the lock's docs entries name cli core; run task bundles:pull, or fix versions.conf"). With `from-bundles` naming cli, a line version needs no `cli-line`; the resolver refuses both together.

### 2. `data/opm/docs-bundles.json`

```json
{
  "lock": "sha256:<lock.json>",
  "versions": {
    "v1.0": {
      "cli": {
        "project": "cli", "role": "anchor", "tag": "1.0", "version": "1.0.0-beta.6", "revision": 0,
        "commit": "<sha>", "digest": "sha256:...", "local": false, "repo": "open-platform-model/cli",
        "dir": "_versions/v1.0/cli", "pins": {"core": "2.0.0-beta.1", "library": "1.0.0-beta.1", "opm-operator": "1.0.0-beta.4"},
        "pages": {"reference/cli/opm-module.md": {"source": "", "lastmod": "...", "edit": "", "generated": true}}
      }
    }
  }
}
```

Refusals, each naming version, project and digest (or `local`): a lock that is not `lock/v1`; a manifest whose `project`, `version`, `revision` or `source.commit` differs from its lock entry; a placement that is not `docs`; a page under `content/` that the manifest does not list (C3 says they are equal; checked again because the site mounts the directory whole).

### 3. Mounts

`gen-mounts.sh`, per version and per repository:

```toml
# bundle-backed: the bundle's content, read-only, instead of the repository's docs/site
[[mounts]]
  source = "<CAT_DIR>/_versions/v1.0/cli/content"
  target = "content/docs"
  [mounts.sites.matrix]
    versions = ["v1.0"]
```

The git mount for that repository and version is not written. A placeholder yields to a bundle page exactly as to a git page (the yield test also looks in `_versions/<v>/<project>/content/`). The catalogs mount (`*/*/manifest.json`, ...) does not match `_versions/<v>/<project>/` (a `*` does not cross `/`), so the tab adapter never sees docs bundles; `gen-catalogs.sh` ignores the lock's `docs` key.

### 4. Page data

`opm/source.html` gains a branch before the git one: a file whose path contains `/_versions/<v>/<project>/content/<path>` is a bundle page; it looks up `docs-bundles.json`:

| Page | editURL | viewURL | date |
|---|---|---|---|
| authored, `edit` set | `https://github.com/<repo>/edit/main/<edit>` | `https://github.com/<repo>/blob/<commit>/<source>` | `lastmod` |
| authored, no `edit` | none | as above | `lastmod` |
| generated | none | as above when `source` is set | `lastmod` |

`last-updated.html` shows Edit for a bundle page on every version, not only the default: the link names `main`, where a fix lands (`docs-kit DESIGN decision 19`, `add-authored-docs` D1). `gen-lastmod.sh` skips bundle-backed repositories (their dates are in the manifest), and `OPM_REQUIRE_DATES=1` does not count a generated page without `lastmod` as missing.

### 5. Checks

- The source lint (`lint-sources.sh`) runs only over git-sourced trees; bundle pages were linted by `opm-docs pull` in bundle mode.
- `check-pages.sh pre`: A1 over site-owned, git and bundle files of one version (a bundle `reference/_index.md` against the site's own is a collision naming both; C16 D4 checks only bundle against bundle).
- `check-pages.sh post`: a bundle page's expected URL comes from its manifest `pages` entry; the existing link crawl already fails a `/docs/` link to a page that does not exist, which is the cross-bundle check C15 assigns to the site.
- Mermaid stays refused outside the Enhancements section, by the existing post-build check, for bundle pages too (docs-kit's lint accepts any tagged fence).

### 6. Pull wiring

`run-in-image.sh pull` accepts `<project>@v<M>.<m>=<dir>` pairs in `OPM_BUNDLES_LOCAL` (passed as `--local` unchanged; C16 D6). The pull runs with `--network none` only when every tab segment and every project of every site version (anchor, pinned and tags, read from `bundles.cue` by the same quoted-key awk as the tabs) is local; otherwise `bridge`. `task build` in manifest mode fails without a lock whose `docs` entries cover every `from-bundles` repository. `gen-stamp.sh` adds `versions.<v>.bundles: [{project, role, tag, version, revision, digest, commit, local, pins}]` from `docs-bundles.json`. CI's Summary step prints that table.

### 7. Fixtures

```text
site/tests/fixtures/bundles/
  _versions/v1.0/cli/            manifest.json (placement docs, owns reference/cli/, pins), content/reference/cli/{_index,opm-module}.md
  _versions/v1.0/core/           owns reference/definitions/, content/reference/definitions/{_index,module}.md + an authored page
  _versions/v1.0/library/        owns reference/go-api/, content/reference/go-api/_index.md, content/embedding/embed-the-kernel.md
  _versions/v1.0/opm-operator/   owns reference/operator-resources.md (a completed page)
site/tests/fixtures/bundles.cue  + docs, + versions."v1.0"
```

The trees live in `site/tests/fixtures/bundles/`, pulled with the pinned tool (`--local cli@v1.0=... --local core@v1.0=...`), and the drift test covers them. (Planned: under `site/tests/fixtures/docs-bundles/`, layered by `test-site.sh` until G2-site; G2-site held before work started.) Only a fixture build that asks for them keeps the lock's `docs` entries (`copy_site CASE docs`, `CASE_DOCS_BUNDLES=1`); the others drop them and read git, so every existing case keeps its meaning. The fixture workspace `site/tests/fixtures/ws/` keeps its git trees for the other repositories, and loses `cli/core/library/opm-operator`'s reference pages only in section 2.

Two-version test: on fixtures in section 1 (`test-site.sh` `docs-bundles/manifest`, v0.9 from git and the default, v1.0 from bundles); in `site/tests/versions/` on the real repositories in section 2, `v1.0` bundle-backed for the four from the real pull, an anchored `v0.9` reading all six from git; the assertions check that each version publishes its own reference and that `v0.9` has no `/docs/reference/go-api/`.

### 8. The pin of `opm-docs` (forward compatibility)

docs-kit validates every `manifest.json` against the closed `#Manifest` of the tool that pulls it (`internal/bundle/manifest.go` `Parse`, docs-kit `main`): a field added by a newer docs-kit (`pins`, `owns`, `pages[].edit`) is refused by an older pull. So the site's pin is bumped to a release no older than any producer's `.opm-docs-version`, and the site bumps first: docs-kit C12 records this rule (docs-kit#13 review). docs-kit also writes `pages[].edit` only for docs placements, so a tab bundle such as `catalog-opm` gains no new field; the rule still holds for every future manifest field. The support section needs a pin at or after the first release carrying `pull-docs-placement` and `add-authored-docs` (0.4.0; the site pinned 0.5.0 when it started); G3.0 for catalog_opm includes this pin being at least that release.

### 9. Section 2: the switch

```cue
versions: "v1.0": {
	anchor: {project: "cli", tag: "1.0"}
	pinned: ["library", "core", "opm-operator"]
}
```

`versions.conf` `[version "v1.0"]` replaces `cli-line = v1.0` with `from-bundles = cli core library opm-operator`; `resolve-versions.sh` resolves only `catalog_opm` (catalog-line) and `opm` (head of `main`) for it, and its tests gain that case. The placeholders `content/docs/reference/{cli,definitions}/_index.md` and the placeholder machinery in `gen-mounts.sh` and `check-pages.sh` are deleted with their exemption and their check case (no other placeholder exists).

## Research & Decisions

### Lock as the source, a host mirror in versions.conf

**Context**: `resolve-versions.sh` runs on the host before the build, without CUE or a parsed lock; the build reads the lock.
**Explored**: reading `bundles.cue` on the host (needs `cue`); reading `site/.bundles/lock.json` on the host (needs `jq`, and the lock may be absent before `bundles:pull`); a mirrored key checked for equality.
**Decision**: the mirror `from-bundles`, checked against the lock in the build.
**Rationale**: explicit configuration (Principle V), no new host tool, and a disagreement fails loudly. `retire-git-pipeline` deletes it with the resolver.

### Edit on every version for bundle pages

**Context**: today Edit shows only on the default version, because older versions' branches may be gone.
**Decision**: a bundle page's Edit names the file on `main` only when the producer saw it there (`edit` set), so it is valid on every version.
**Rationale**: `docs-kit DESIGN decision 19` (owner, 2026-10-03: Edit goes to the file on `main`); the producer, not the site, knows whether the path exists.

## Risks / Trade-offs

- [The cli releases before every pin has a bundle] -> the site's next pull fails for every version (C16 D2); G2-pins is checked before the cli release PR merges, and a committed `site/bundles.frozen.json` is the recovery.
- [A producer bumps docs-kit ahead of the site] -> the pull refuses its manifests (Decision 8); the site bumps first (docs-kit C12).
- [Docs-only fixes no longer reach v1.0 at the next build] -> a docs revision dispatch per repository; named in each product repository's `AGENTS.md` "Docs bundles" paragraph by its own change.
- [Generated pages without `lastmod`] -> shown without a date rather than failing CI.

## Open Questions

- **OQ1 (owner, before docs-kit orchestration step 8).** CI's `sources-main` job builds all six repositories' `main` from git (explicit mode, the lock's docs entries dropped), so the four whose released docs v1.0 reads from bundles are still linted and link-checked at `main`. Step 8 deletes the committed generated reference in core, cli and opm-operator; their `main` checkouts then hold no `reference/cli/`, `reference/definitions/` or `reference/operator-resources.md`, and any `main` page linking one fails that job. Two ways out: (a) an edge site version for `sources-main`, reading the four products' `main` docs from their `edge` docs bundles (a second `bundles.cue` `versions` entry, or a CI-only config), so `main` pages are checked with their generated reference; (b) keep the four on their release bundles in `sources-main`, which then checks only opm's and catalog_opm's `main` and leaves each product's `main` pages to its own docs workflow's bundle lint (cross-repository `/docs/` links unchecked until a release). Recommendation: (a), which keeps the cross-repository link check that motivated the job; it fits `retire-git-pipeline` or `serve-docs-from-bundles`.

## Durable decisions

- A site version reads a repository from its docs bundle exactly when the lock's `docs` entries name it for that version; `versions.conf` `from-bundles` mirrors it until `retire-git-pipeline`. Lands in `AGENTS.md` (Site versions, "Docs bundles in a site version") and `README.md` ("Docs bundles in a site version", under "Site versions").
- The site's `opm-docs` pin is never older than any producer's `.opm-docs-version`. Lands in `AGENTS.md` (Repository Rules, "Docs bundles are signed and pinned").
- Edit on a bundle page goes to `main` at the manifest's `edit`, on every version; generated pages have none. Lands in `README.md` ("Docs bundles in a site version"; the README has no "Sources" section).
- Generated reference now comes from bundles for these four repositories; Principle III's committed-reference sentence changes. Lands in `openspec/config.yaml` and `AGENTS.md` (Patterns, "Generated reference").
- Placeholders are gone. Lands in `AGENTS.md` (Durable decisions, "Placeholders" removed).
