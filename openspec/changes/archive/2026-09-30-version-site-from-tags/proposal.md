## Why

The Hugo site that `port-site-to-hugo-hextra` (A) ships publishes one version, `v1.0`, labelled "v1.0 (beta)". It is built from each source repository's `main`, and the build records the six SHAs (owner decision O3). Its version list is hand-written in `site/config/_default/hugo.toml`, and every build reads the source trees as they are checked out.

When `v1.0.0-beta.N` tags exist, `v1.0` must move onto them, and later versions must be added. That should be a one-file edit reviewed as a commit, not a change to layouts and scripts. O3 also fixes how it works: each version pins a fixed anchor ref, bumped by commit. It never follows a moving `v1.0.*` line resolved at build time. The catalog ref is explicit, because the CLI pins no catalog. Core is read from library's `DefaultSchemaModule` at the library tag the CLI pins, and the stamp shows it.

## What Changes

- **Manifest.** New `site/versions.conf` is the only list of site versions. It uses git-config syntax, so `git config --file` parses it on the host and nothing new enters the build image. Each version has a name, a label, a weight and the default flag, plus one of two sources:
  - `source = main`: every repository at its checked-out `HEAD`. This is marked in the file as allowed only until beta tags exist (O3). The build records the SHAs.
  - A fixed anchor: `cli = <tag or SHA>`, with explicit `catalog` and `opm` refs, and optional overrides. Each override carries a reason.
- **Dialect floors.** The manifest records each repository's dialect floor: the SHA of its `adopt-hugo-page-dialect` merge (S1-S6). The resolver refuses any ref that does not contain its floor, naming the repository and the ref.
- **Resolver.** New `site/scripts/resolve-versions.sh` runs on the host. It reads library from `cli/go.mod` at the anchor, core from library's `opm/schema/loader.go` `DefaultSchemaModule`, and the operator from cli `internal/operator/manifest.go` `PinnedOperatorVersion`. It never reads `cli/hack/platform/`, which is a test fixture. It fails on:
  - a ref without `docs/site`, naming the repository;
  - a ref that does not contain its floor;
  - a moving ref in an anchored version;
  - a pseudo-version pin;
  - an unknown manifest key.

  It has two read-only modes: `--check` resolves and prints, and `--pins <cli-ref>` prints the pins alone. Before any ref, it checks that each source root exists and is its own git top level, naming `OPM_SRC_<REPO>`. A's fixture workspace sits inside opmodel.dev, so a fixture build runs in explicit mode, with `OPM_VERSIONS=v1.0=/src`, which skips resolution.
- **Materialisation.** New `site/scripts/materialise.sh` runs on the host. It runs `git archive` on each anchored version's `docs/site` into `site/.versions/<v>/<repo>/docs/site`. It computes every git date on the host, because a worktree's `.git` file points at a path the container does not mount: source pages at each version's ref, and the site-owned pages (the landing and the section overviews) at the opmodel.dev checkout's `HEAD`. gen-lastmod then runs no `git` and still fails on a missing date when `OPM_REQUIRE_DATES=1`, as E's CI sets it. Worktree builds now date every page too.
- **Taskfile.** A's no-op `versions:prepare` now runs both scripts. New tasks: `versions:check` and `versions:test`.
- **Generated config.** A generated versions config, written from the manifest, replaces the hand-written `[versions]` block and `defaultContentVersion` in `site/config/_default/hugo.toml`.
- **Every version-aware output follows the manifest:** Pagefind, `_redirects`, the `/latest/` stubs, the root `index.html` and `404.html`, `robots.txt` and the sitemaps. Nothing globs `v*/`.
- **Stamp and links.**
  - The footer stamp says which refs each version documents: "Documents cli X, library L, core Y, catalog Z, operator W" for an anchored version, and the SHAs for `main`.
  - "View source at <ref>" links to the resolved ref, not the version name. It shows on every anchored version. "Edit this page" (`edit/main`) stays on the default version and on a `source = main` version, so the default keeps its edit links when it moves onto tags.
  - With two or more versions, the version switch lists every label.
  - Every version other than the default shows the outdated bar.
- **Tests.**
  - Resolver tests run on small fixture repositories.
  - A resolver-only test reads the pins at cli `v1.0.0-alpha.25`.
  - A negative test proves that a pre-S ref fails its floor.
  - A two-version build is pinned to post-S SHAs. It never writes `site/public/`.
- **Not breaking.** The published URLs and the version set do not change. `v1.0` still builds from `main`.

**Complexity (Principle V).**
- Two host scripts are required. `git archive`, `git log <ref>` and `git merge-base` cannot run in the container against a worktree.
- git-config syntax replaces YAML. With YAML, the Dockerfile would need a pinned `yq`, and the host resolver would need a YAML parser that the host rules do not allow.

## Before / After

**Before** (as A ships it)

```text
site/config/_default/hugo.toml
  defaultContentVersion = 'v1.0'
  defaultContentVersionInSubdir = true
  [versions.'v1.0']
    weight = 1
  [[params.opm.versions]]
    name = 'v1.0'
    label = 'v1.0 (beta)'
Taskfile.yml
  versions:prepare             no-op
build-all.sh
  OPM_VERSIONS                 default v1.0=/src (every repo read in place)
```

**After**

```text
site/
  versions.conf                        NEW  the only list of site versions (hand-edited, bumped by commit)
  config/_default/hugo.toml            keeps defaultContentVersionInSubdir = true; [versions], defaultContentVersion, [[params.opm.versions]] removed
  config/<env>/  (generated, ignored)  the same three, written from the manifest
  scripts/resolve-versions.sh          NEW  host: manifest -> refs and SHAs; --check, --pins
  scripts/materialise.sh               NEW  host: git archive + git dates per version
  tests/versions/                      NEW  resolver tests, two-versions.conf, two-version build assertions
  .versions/versions.tsv   (generated) one row per version and repository: label, weight, default, ref, SHA, how
  .versions/<v>/<repo>/docs/site/      (generated) archive of an anchored version
  .versions/<v>/lastmod.tsv            (generated) git dates at the version's refs
Taskfile.yml
  versions:prepare                     resolve-versions.sh, then materialise.sh
  versions:check, versions:test        NEW
```

`site/versions.conf` on day one (the six floors are the S merge SHAs the supervisor hands over at launch):

```ini
[repo "opm"]
	floor = <S1 merge SHA>
[repo "core"]
	floor = <S2 merge SHA>
[repo "catalog_opm"]
	floor = <S3 merge SHA>
[repo "cli"]
	floor = <S4 merge SHA>
[repo "library"]
	floor = <S5 merge SHA>
[repo "opm-operator"]
	floor = <S6 merge SHA>

[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	; O3: every repository at main until v1.0.0-beta.N tags exist; the build records the SHAs.
	source = main
```

Moving `v1.0` onto beta tags later is this edit. The tag names below are examples:

```ini
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	cli = v1.0.0-beta.1
	catalog = opm-v4.6.0
	opm = 0123456789abcdef0123456789abcdef01234567
```

## Impact

- **Files.** New: `site/versions.conf`, `site/scripts/resolve-versions.sh`, `site/scripts/materialise.sh` and `site/tests/versions/`. Edits are listed under Touches.
- **Build inputs.**
  - The build gains the manifest.
  - For anchored versions it also gains git archives of the source repositories at fixed refs. There are none on day one.
  - It needs each source repository's git history on the host, and the opmodel.dev checkout's own, for the site-owned dates. It needs that already for dates; CI checks out with `fetch-depth: 0`, from `add-site-ci` (E).
  - No new tool, and no Dockerfile change.
- **Source repositories.** None has to change for this change. Moving `v1.0` onto tags later needs a tag cut after each repository's S merge, because no existing tag can be built. Every tag before S carries `sidebar:` front matter, which A's lint rejects: cli `v1.0.0-alpha.25`, library `alpha.35`, core `v2.0.0-alpha.12`, catalog `opm-v4.4.2` and operator `alpha.21`. What that takes is the owner's call:
  - cli, library and opm-operator show `docs` commits in their changelogs, so the S4-S6 merges open or grow release PRs there. Only the owner merges them.
  - core and catalog_opm hide `docs`, so S2 and S3 cut no release. A post-S tag there needs another releasable commit or a `Release-As:` footer.
  - opm has no repository-level tag, so it stays at a SHA.
  - The anchor's own pins must name post-S tags: the library in `cli/go.mod`, `DefaultSchemaModule` in library, and `PinnedOperatorVersion` in cli. Any pin that does not needs an override, with a reason.
- **Published URLs and versions.** No change on day one: `/v1.0/...`, `/latest/` to `/v1.0/`, and `/` to `/latest/`. A later version publishes under `/<name>/`, where the name matches `vN.N`. `/reference-archive/` stays reserved. Moving `v1.0` onto tags changes what a reader sees in two places: each page gains "View source at <ref>" beside "Edit this page", and the footer stamp names the refs instead of SHAs.
- **What stays open.** Which core the site presents, the CLI's pin or the newest major, is 0021:OQ15 and stays open. This change shows the core that the CLI's library pins and does not settle the question. 0021:OQ14 stays open too.
- **Depends on.**
  - Starts when A (`port-site-to-hugo-hextra`) is merged by the owner. The supervisor hands over the six S merge SHAs at launch. If A's merge needed source fixes after the S merges, it also names six buildable post-S SHAs for the two-version test.
  - Merges when verify is green, after E (`add-site-ci`).
  - B is not on the go-live path.
- **Touches.**
  - This change directory, `openspec/changes/version-site-from-tags/` (tasks 1.1 and 1.2 write findings into design.md; the archive moves it).
  - New files: `site/versions.conf`, `site/scripts/{resolve-versions,materialise}.sh`, `site/tests/versions/*`.
  - Scripts: `site/scripts/{build-all,gen-mounts,gen-lastmod,check-pages,serve}.sh`.
  - Config: `site/config/_default/hugo.toml`.
  - Layouts: `site/layouts/_partials/opm/{build-stamp,source,version-switch,version-links}.html`, `site/layouts/_partials/components/last-updated.html`, `site/layouts/_partials/navbar-title.html` and `site/layouts/_partials/banner.html`.
  - CSS: `site/assets/css/opm/versions.css`.
  - Tests: `site/tests/browser/` (per-version search, shots of the switch and the bar), and the fixture call sites of A's `test:site` harness (A plans `site/scripts/test-site.sh`), only if they conflict.
  - `site/layouts/{robots.txt,sitemap.xml}`, only if they do not already range over versions.
  - `Taskfile.yml`: the `versions:*` tasks, plus one line in `test:site` that runs `versions:test`, if the supervisor allows it.
  - The ignore rule for the generated versions config, only if A's rule misses it.
  - One heading each in `README.md` and `AGENTS.md`, both `## Site versions`. A's `## Durable decisions` section and the `AGENTS.md` layout tree are not edited.
  - Not touched: `site/Dockerfile`, `custom/head-end.html` (its `/latest/` stubs follow the generated default version), `docs-main.html` and `custom/content-begin.html` (D), `.github/workflows/*` (E, F), figures (C), and brand marks (M).

## Enhancement

None delivered. Related: 0018:D8, under which a page lives in the repository whose change would make it wrong. This change assembles each version from those repositories at recorded refs, but it claims no decision. 0021:OQ14 and 0021:OQ15 stay open. No `enhancement.yaml` (this change set records no delivery claims).
