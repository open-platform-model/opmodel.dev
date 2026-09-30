## Context

This change starts after the owner merges `port-site-to-hugo-hextra` (A). It codes against A's merged `main` and against interface A in `orchestration.md` section 6. That interface gives this change:

- `task versions:prepare`: a host-side no-op that `build` and `serve` run first. This change fills its body.
- `OPM_VERSIONS`: the internal seam `name=root ...`, defaulting to `v1.0=/src`. Each root holds `<repo>/docs/site`.
- Container paths: the worktree is at `/work/repo`, read-write. Each source root is at `/src/<repo>`, read-only.
- `OPM_SRC_<REPO>`, `OPM_SRC_WORKTREE`, `OPM_WS`, `OPM_BUILD_REFS` and `OPM_REQUIRE_DATES`.
- Generated inputs: `site/.versions/<v>/` (reserved for this change), `site/data/opm/{lastmod,build}.json` and `site/config/{production,development}/module.toml`.
- Outputs: `site/public/` (with `build-stamp.json`) and `site/.check/<v>/nav-order.txt`.
- Partials this change may edit:
  - `_partials/opm/{source,build-stamp,version-switch,version-links}.html`;
  - `_partials/navbar-title.html` and `_partials/banner.html`;
  - `_partials/components/last-updated.html`;
  - `site/assets/css/opm/versions.css`.

A publishes one version, `v1.0`, labelled "v1.0 (beta)". It is built from each source root as checked out. Its `[versions]` block and `defaultContentVersion` are hand-written in `site/config/_default/hugo.toml`.

Two owner decisions bind this change. **O3**: day one publishes one version, `v1.0`, labelled beta, built from each repository's `main` with the six SHAs recorded; moving it onto `v1.0.0-beta.N` tags must be a manifest edit that pins a fixed anchor ref bumped by commit, never a moving line resolved at build time; the catalog ref is explicit, because the CLI pins no catalog; core is read from library's `DefaultSchemaModule` and shown in the stamp; which core the site presents stays 0021:OQ15. **O4**: the source repositories were rewritten to the Hugo page dialect (the S1-S6 changes in `orchestration.md` section 2), with no compatibility layer, and A's lint rejects the old dialect.

A's own plan (`port-site-to-hugo-hextra/design.md`, drafted beside this one) adds details this design relies on. Task 1.1 re-reads A's merged `main` for each of them:
- The label sits beside the versions block as `[[params.opm.versions]]` (`name`, `label`).
- `site/.gitignore` and `task clean` cover `site/config/production/` and `site/config/development/` whole.
- `opm/source.html` finds the repository from the `<repo>/docs/site/` segment of a file's path (`/src/<repo>/docs/site/<path>` in a normal build), and maps any other content file to `opmodel.dev` `site/content/<path>`. It never matches the literal `/work/repo/site/` prefix (A's decision 11).
- The ported scripts take the site directory as `SITE_DIR` (default `/work/repo/site`) and write only below it, so `test-site.sh` can run the pipeline on a copy (A's decision 15).
- `gen-lastmod.sh` runs `git log` in the container. It dates source pages under the key `<repo>/docs/site/<path>` and site-owned pages under `opmodel.dev/site/content/<path>`, as the prototype's does (it loops over the six repositories and `opmodel.dev`). In a worktree build both miss, because the worktree's `.git` file points at a host path.
- `custom/head-end.html` publishes the `/latest/<path>/` stubs for every page of the version whose `.Site.Version.IsDefault` is true, as the prototype's does.
- One host script, `site/scripts/run-in-image.sh`, resolves `OPM_WS` and `OPM_SRC_<REPO>`, with the environment winning over the defaults. Before any `docker run` it checks that each root exists and holds `docs/site`, and it records `OPM_BUILD_REFS` as `none` for a root that is not its own git top level (the fixture workspace).
- `site/scripts/test-site.sh` runs in the build image. It feeds fixture roots through `OPM_VERSIONS` and writes only under `site/.check/tests/`.
- A's section 1 build target is the fixture workspace, `OPM_WS=<wt>/site/tests/fixtures/ws`. Its roots sit inside the opmodel.dev repository, so they are not git top levels.

Constraints that shape the approach:
- **git runs on the host.** A worktree's `.git` is a file that points at a host path the container does not mount (trap 21). Every `git` call against a source repository (`rev-parse`, `show`, `archive`, `log`, `merge-base`) therefore runs on the host, inside `versions:prepare`.
- **No new build tool.** The Dockerfile stays as A ships it. The host may use `git`, `sh` and `awk`; it has no `yq`.
- **The build never writes to a source repository** (Principle IV). `git worktree add` would write into the source repository's `.git`. `git archive` only reads.
- **Taskfile scope.** This change edits only the `versions:*` tasks, including the body of `versions:prepare`. The change-set plan limits it to those, so they do not collide with E's `ci:*` and M's `brand:*`. The one exception it asks for is under Open Questions.
- **No existing tag can be built** (O4, trap 36). Every tag cut before a repository's S merge carries `sidebar:` front matter, which A's lint rejects.

Files under `site/`:

| File | Change | Build input |
|---|---|---|
| `site/versions.conf` | new | gained: the manifest |
| `site/scripts/resolve-versions.sh` | new, host | reads the source repositories' git history on the host |
| `site/scripts/materialise.sh` | new, host | gained: archives of anchored refs (none on day one), and git dates computed on the host for source and site-owned pages |
| `site/scripts/build-all.sh`, `serve.sh` | edit: load the version list and the default version from the resolved file | none |
| `site/scripts/gen-mounts.sh` | edit: also write the generated versions config | none |
| `site/scripts/gen-lastmod.sh` | edit: in manifest mode, read the host-computed dates instead of running `git` | none |
| `site/layouts/_partials/custom/head-end.html` | not edited: its `/latest/` stubs follow the generated `defaultContentVersion` through `.Site.Version.IsDefault` | none |
| `site/scripts/check-pages.sh` | edit only if it assumes one version or globs `v*/` | none |
| `site/config/_default/hugo.toml` | edit: drop `[versions]` and `defaultContentVersion` | none |
| `site/layouts/_partials/opm/{build-stamp,source,version-switch,version-links}.html`, `site/layouts/_partials/{navbar-title,banner}.html`, `site/layouts/_partials/components/last-updated.html` | edit | none |
| `site/assets/css/opm/versions.css` | edit (create it if A's CSS split did not) | none |
| `site/layouts/{robots.txt,sitemap.xml}` | edit only if they do not range over every version | none |
| `site/tests/versions/*` | new | test only |
| `site/tests/browser/*`, A's `site/scripts/test-site.sh` | edit: search per version, and shots of the switch and the bar. The harness only if its fixture call sites or label assertions conflict | test only |

No theme file is copied or overridden anew, so `site/overrides.sha256` is unchanged. The published URLs and the version set do not change on day one.

## Goals / Non-Goals

**Goals:**
- One manifest is the only list of site versions. Moving `v1.0` from `main` onto `v1.0.0-beta.N` tags is an edit of that file, reviewed as a commit (O3).
- Each anchored version resolves its six refs from a fixed anchor, following the CLI's forward pins (0021:OQ15's position), with an explicit catalog ref and explicit `opm` ref.
- A ref older than its repository's S merge fails before Hugo starts, naming the repository and the ref.
- Each version publishes the refs it documents, and "View source" links point at those refs.
- Every version-aware output iterates the manifest's versions.

**Non-Goals:**
- Settling 0021:OQ14 or 0021:OQ15. Which core the main site presents, the CLI's pin or the newest major, stays open. This change shows the core that the CLI's library pins (O3).
- Cutting tags or releases in any repository, or scheduling them.
- A `docs-pins.yaml` published by CLI releases. That is a cli follow-up.
- The component archive (`/reference-archive/`) beyond its reservation, and the generated reference (`site/.gen/<v>/`).
- Changing CI (E), deploy (F), the docs layout (D), the figures (C) or the brand (M).

## Decisions

### 1. The manifest is `site/versions.conf`, in git-config syntax

```ini
; site/versions.conf: the versions opmodel.dev publishes. The only list; edit it by commit.
; git-config syntax (read with `git config --file`); see README "Site versions".

[repo "opm"]
	floor = <S1 merge SHA>        ; dialect floor: no ref older than this builds
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

An anchored version, as it will look once tags exist. The tag names are examples:

```ini
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	cli = v1.0.0-beta.1                           ; the anchor: library, core and opm-operator come from its pins
	catalog = opm-v4.6.0                          ; explicit: the CLI pins no catalog
	opm = 0123456789abcdef0123456789abcdef01234567 ; explicit: opm has no repository-level tag
	override = opm-operator v1.0.0-beta.2 the pinned beta.1 predates its upgrade page
```

**Grammar.** The resolver MUST reject any key not listed here, naming the key.

| Key | Where | Rule |
|---|---|---|
| `repo.<name>.floor` | one per repository, all six required | A full 40-hex SHA. `<name>` is one of `opm`, `core`, `catalog_opm`, `cli`, `library`, `opm-operator` |
| `version.<name>` | one section per version | `<name>` matches `^v[0-9]+\.[0-9]+$`. It is a URL segment, so no version can take `latest` or `reference-archive` |
| `label` | required | Non-empty, one line, with no tab, `'`, `"` or `\` in the value as git reads it. A tab would split a `versions.tsv` column, a `'` would end the single-quoted TOML literal, and a `"` or `\` would break the JSON strings the build writes. Shown in the switch, the outdated bar and the stamp |
| `weight` | required | A positive integer, unique across versions. Hugo orders versions by weight, then by semver, descending |
| `default` | exactly one version | `true`. `/latest/` and `/` point at it |
| `source = main` | at most one version | Means every repository at its checked-out `HEAD` (Decision 2). Excludes `cli`, `catalog`, `opm` and `override` |
| `cli` | required unless `source = main` | The anchor: a tag (`refs/tags/<x>` exists) or a full 40-hex SHA. Never a branch, `HEAD`, a pattern or a partial SHA |
| `catalog` | required with `cli` | The catalog_opm ref: a tag (`opm-v*` or `k8s-v*`) or a full SHA |
| `opm` | required with `cli` | The opm ref: a tag or a full SHA |
| `override` | optional, several allowed, one per repository | `<repo> <ref> <reason>`. The ref follows the anchor rule, and the reason is required. It replaces the derived or explicit ref for that repository. The reason follows the `label` character rule, because it lands in the `how` column of `versions.tsv` and in `build-stamp.json`. git-config treats an unquoted `;` or `#` as the start of a comment, so a reason that needs one is quoted in the file (git strips those quotes) |

**Why git-config.**
- git parses it on the host, where the resolver must run, and in the image if ever needed. `.gitmodules` uses the same syntax.
- A syntax error fails with the line number.
- Multi-valued keys carry overrides.
- `--type=bool` reads `default`.

**Alternatives considered.**
- YAML read with a pinned `yq` in the Dockerfile: the resolver runs on the host, where `yq` is not a sanctioned tool, and every worker would get a new image hash.
- YAML parsed by awk: a fragile subset.
- A Go resolver: `go.mod` has no YAML library, and docgen is unrelated code.
- TOML: no host parser.

The change-set plan asked for YAML, or for a line-oriented file if the Dockerfile stays unchanged. This is that file.

### 2. Two kinds of version, and what `main` means

- **`source = main`** reads every repository's source root in place: the root that A mounts at `/src/<repo>`, with live reload under `task serve`.
  - Its ref is the root's checked-out `HEAD`. The resolver records `git -C <root> rev-parse HEAD`.
  - The resolver MUST NOT run `git rev-parse main`. The local `main` branch is stale by rule in the owner's checkouts, and the `site-src` worktrees are detached at `origin/main`.
  - In CI, `HEAD` is `main` (E checks out `main`). Locally it is whatever `OPM_SRC_WORKTREE=site-src` points at.
  - At most one version may use it. Per O3 it is for `v1.0` until beta tags exist. The manifest comment says so, and every build records the SHAs.
- **An anchored version** pins fixed refs, bumped by commit. Nothing is resolved from a moving line at build time. So a nightly build changes an anchored version only when a commit to `site/versions.conf` does.

### 3. Resolution of an anchored version

| Repository | Ref | Read from |
|---|---|---|
| cli | the anchor | `cli = ...` |
| library | the require line `github.com/open-platform-model/library vX` in `go.mod` at the anchor | tag `vX` |
| core | `const DefaultSchemaModule = "opmodel.dev/core@vX"` in `opm/schema/loader.go` at the **effective** library ref | the plain core tag `vX` |
| opm-operator | `const PinnedOperatorVersion = "vX"` in `internal/operator/manifest.go` at the anchor | tag `vX` |
| catalog_opm | `catalog = ...`, explicit | the CLI pins no catalog (O3) |
| opm | `opm = ...`, explicit | opm has no repository-level tag |

**Pin rules.**
- An `override` replaces a row, and a pin it replaces is not read. A library override moves where core is read.
- Never read `cli/hack/platform/`. It is a test fixture, not a pin.
- A pin MUST resolve to an exact release. The resolver fails, naming the repository, the file and the anchor, when:
  - a pin is a Go pseudo-version;
  - `go.mod` carries a `replace` for the library;
  - `DefaultSchemaModule` carries only a major (`@v2`);
  - a pin file or its line is missing.
  In each case the fix is an override with a reason.

**Checks on every resolved ref, including `HEAD` for `source = main`.** Each failure names the repository and the ref:
1. `git -C <root> rev-parse --verify --quiet '<ref>^{commit}'` succeeds.
2. `docs/site` exists at the ref: `git ls-tree -d <sha> docs/site`, or the directory in the working tree for `source = main`.
3. The ref contains the floor: `git -C <root> merge-base --is-ancestor <floor> <sha>`.

The resolver reports every failure it finds, one line each (`<version>: <repo> <ref>: <reason>`), and then exits 1. The author then sees all of a manifest's problems in one run.

**Modes.**
- `resolve-versions.sh` writes `site/.versions/versions.tsv` (Decision 5).
- `--check` resolves, runs every check and prints the table. It writes nothing.
- `--pins <cli-ref>` prints the derived library, core and opm-operator refs for that cli ref. It runs no docs or floor check and builds nothing.

**Source roots.** The resolver reads each source root from the same rule A's Taskfile uses to mount `/src/<repo>`:
- `OPM_SRC_<REPO>` if set;
- else `$OPM_WS/<repo>/.claude/worktrees/$OPM_SRC_WORKTREE` if `OPM_SRC_WORKTREE` is set;
- else `$OPM_WS/<repo>`.

The resolver MUST reuse A's host-side resolution (A plans it in `site/scripts/run-in-image.sh`), for example by sourcing it or by `versions:prepare` passing the resolved roots in, rather than keep a second copy that could drift. If reuse needs an edit to A's script, that is a deviation to report.

**Root checks, before any ref is read.** For each of the six roots, in every mode except `--pins` (which reads only the cli and library roots, and checks those two):
1. The root exists.
2. It is its own git top level: `git -C <root> rev-parse --show-toplevel` equals `(cd <root> && pwd -P)`.

A failure prints `<repo>: root <path>: <reason>; set OPM_SRC_<REPO>` and exits 1 before any other check. Without check 2, a root inside another repository silently resolves that repository: A's fixture roots (`OPM_WS=<wt>/site/tests/fixtures/ws`) sit inside opmodel.dev, so `rev-parse HEAD` would return opmodel.dev's `HEAD` and the floor check would fail on an unknown object, naming the wrong cause. When the root is not a git top level, the message also says that a fixture build runs in explicit mode, with `OPM_VERSIONS=v1.0=/src` (Decision 5), which skips resolution. So from section 1 on, a fixture `task build` or `task serve` sets `OPM_VERSIONS`. Task 1.1 finds every place A's merged `main` runs or documents one without it.

### 4. Dialect floors

Each repository's floor is the SHA of its `adopt-hugo-page-dialect` merge commit on `main`. The supervisor hands them over at launch, and task 1.1 records them here and in `site/versions.conf`.

| Repository | S change | Floor (S merge SHA) |
|---|---|---|
| opm | S1 | recorded by task 1.1 |
| core | S2 | recorded by task 1.1 |
| catalog_opm | S3 | recorded by task 1.1 |
| cli | S4 | recorded by task 1.1 |
| library | S5 | recorded by task 1.1 |
| opm-operator | S6 | recorded by task 1.1 |

The floor check also applies to `source = main`. It makes a build against a stale checkout, such as the owner's never-pulled main checkouts (trap 25), fail with the repository named, instead of failing later in the lint.

### 5. The host and container split: `site/.versions/versions.tsv`

`versions:prepare` runs on the host: `resolve-versions.sh`, then `materialise.sh`. The container never parses the manifest. It reads one resolved file: one tab-separated row per version and repository, with a header comment.

```text
# version  label        weight  default  kind      repo          ref         sha        how
v1.0       v1.0 (beta)  1       true     main      cli           main        <40 hex>   head
v1.0       v1.0 (beta)  1       true     main      core          main        <40 hex>   head
v0.9       v0.9 (test)  2       false    anchored  cli           <cli SHA>   <cli SHA>   anchor
v0.9       v0.9 (test)  2       false    anchored  catalog_opm   <cat SHA>   <cat SHA>   explicit
v0.9       v0.9 (test)  2       false    anchored  core          <core SHA>  <core SHA>  override:test pins post-S SHAs, no post-S tag yet
```

The rows come from the two-version test manifest, with its test SHAs (Decision 11); the other rows are left out.
- `how` is one of: `head`, `anchor`, `explicit`, `override:<reason>`, or `pin:<repo> <file>` (for example `pin:library opm/schema/loader.go` for a core ref read from the library's pin).
- The container derives each version's root from `kind`: `main` is `/src`, and `anchored` is `$SITE_DIR/.versions/<v>` (`/work/repo/site/.versions/<v>` by default). No script names the literal `/work/repo/site/` path.
- `build-all.sh` and `serve.sh` turn the file into the version list, the default version and `OPM_VERSIONS`. They pass the list on to `gen-mounts.sh`, `gen-lastmod.sh`, `check-pages.sh`, the lint and the Pagefind and root-file steps. No script reads the default version from `hugo.toml` any more (the prototype's `build-all.sh` did, with `sed`), because the key leaves that file (Decision 7).

**Explicit mode (fixtures).** When a caller sets `OPM_VERSIONS`, it owns the version set:
- `versions:prepare` skips resolution and materialisation, and removes any stale `versions.tsv`.
- `build-all.sh` and `serve.sh` build the version list from `OPM_VERSIONS` alone, by this change's rule: label = name, weight = position, first = default. A read the label and the default from its hand-written `hugo.toml`, which this change removes, so the rule is new here. With no `versions.tsv` and no `OPM_VERSIONS`, both fall back to A's default, `v1.0=/src`.
- `gen-lastmod.sh` keeps A's container-side `git log` (Decision 6).

Task 1.1 confirms that A's `build`, `serve` and `test:site` leave `OPM_VERSIONS` unset unless a caller sets it. If they do not, that is a deviation to report before section 2.

**`OPM_VERSIONS_MANIFEST`** (new, host) selects another manifest; the default is `site/versions.conf`. Tests and the two-version QA build use it. It is never set in CI.

### 6. Materialisation and dates

For each anchored version, `materialise.sh`:
- runs `git -C <root> archive <sha> docs/site | tar -x -C site/.versions/<v>/<repo>/` for each repository. A marker (`site/.versions/<v>/<repo>/.sha`) skips an unchanged archive;
- removes `site/.versions/<name>/` directories whose name matches the version pattern but that are not in the manifest. It never touches anything outside `site/.versions/`.

For every version, `source = main` included, it writes `site/.versions/<v>/lastmod.tsv`, one row per page: the key, the version and the date. It holds two kinds of row:
- **Source pages**, for each of the six repositories: key `<repo>/docs/site/<path>`, date from `git -C <root> log -1 --format=%cI <sha> -- docs/site/<path>`, where `<sha>` is the version's resolved SHA for that repository.
- **Site-owned pages**, the same rows in every version, because `site/content` is mounted once for all of them: key `opmodel.dev/site/content/<path>` for every `*.md` under `site/content/`, date from `git -C <top> log -1 --format=%cI HEAD -- site/content/<path>`, where `<top>` is the opmodel.dev checkout that holds the script (`git rev-parse --show-toplevel`). git works there on the host, in a worktree too.

A single `git log --name-only` pass per repository SHOULD replace per-file calls if a build gets slow.

`gen-lastmod.sh`, in manifest mode (a `versions.tsv` exists and `OPM_VERSIONS` is unset):
- runs no `git`. It reads every `site/.versions/<v>/lastmod.tsv` of the resolved list and writes `data/opm/lastmod.json` in A's key format (key to `{version: date}`);
- still walks every page it would have dated itself, source and site-owned alike, and counts a page with no row as a miss. `OPM_REQUIRE_DATES=1` makes a miss fatal, naming the page (check 13), exactly as in A.

In explicit mode it keeps A's container-side `git log` for both kinds of page, because `versions:prepare` wrote no rows.

The host rows are the only date source in manifest mode, so worktree builds now date every page, where A's container-side `git log` dated none. That makes check 13 provable locally: `OPM_REQUIRE_DATES=1 OPM_SRC_WORKTREE=site-src task build` passes in a worktree. In CI it keeps E's meaning. A page added in the working tree but not yet committed has no date, as in A.

The archives sit inside the worktree, which is already mounted at `/work/repo`. So no new bind mount is added, and trap 22 (a missing mount source becomes a root-owned directory) cannot fire. None of the six repositories carries `export-ignore` or `export-subst` in `.gitattributes`, so an archive equals the tree.

### 7. Generated Hugo versions config

`gen-mounts.sh` already writes `config/<env>/module.toml` for both `build` (production) and `serve` (development). It now also writes the versions config next to it, from the same version list:

```toml
# Generated by scripts/gen-mounts.sh from site/versions.conf. Do not edit.
defaultContentVersion = 'v1.0'   # a string, never a number (trap 8)
[versions]
  [versions.'v1.0']
    weight = 1
[[params.opm.versions]]          # A's param shape: name and label, in weight order
  name = 'v1.0'
  label = 'v1.0 (beta)'
```

`site/config/_default/hugo.toml` keeps `defaultContentVersionInSubdir = true`. It loses the hand-written `[versions]` block, `defaultContentVersion` and A's `[[params.opm.versions]]` entry. Keeping A's param shape means the switch and the stamp look up a label exactly as A's partials do.

Where the generated keys live is the spike's question (task 1.2). The candidates:
- (a) `config/<env>/hugo.toml` holding all of it;
- (b) `config/<env>/versions.toml` and `config/<env>/params.toml` split by root key, plus `defaultContentVersion` as the environment variable `HUGO_DEFAULTCONTENTVERSION`;
- (c) a generated file under `site/.versions/` passed with `--config`.

The spike takes the first form that Hugo 0.167.0 honours in both environments, with the `[[params.opm.versions]]` array coming only from the generated file. A plans to ignore and clean `config/production/` and `config/development/` whole, so (a) and (b) need no new ignore line. The spike records the answer under Research & Decisions.

### 8. Build data, the stamp and source links

- `data/opm/build.json` and `public/build-stamp.json` keep every key A writes; E's job summary reads them. They gain one key:

  ```json
  "versions": {
    "v1.0": {"label": "v1.0 (beta)", "default": true, "kind": "main",
             "refs": {"cli": {"ref": "main", "sha": "<40 hex>", "how": "head"}, "...": {}}}
  }
  ```

- `opm/build-stamp.html` changes content, not location. It is still called from Hextra's `custom/footer.html` hook.
  - An anchored version shows "Documents cli X, library L, core Y, catalog Z, operator W, opm <short SHA>". A ref that is a SHA shows as seven hex characters.
  - A `main` version shows the short SHAs as A does.
  - The stamp is published text, so it carries no enhancement reference.
- `opm/source.html` takes the repository from the `<repo>/docs/site/` path segment (A), so an archived page under `.versions/<v>/<repo>/docs/site/<path>` maps to the same `{repo, path}` as its `/src/<repo>/docs/site/<path>` twin, and edit links, view links and dates work for it. Task 3.2 checks this on the two-version build; it needs an edit only if A's rule does not reach archived pages.
  - `viewURL` becomes `https://github.com/open-platform-model/<repo>/blob/<ref>/docs/site/<path>`, where `<ref>` is the version's resolved ref for that repository: the tag, or the SHA. It is never the version name: `v1.0` is a site version, not a git ref, and no repository has a branch or tag by that name.
  - `components/last-updated.html` shows the links by these rules:

    | Version | "Edit this page" (`edit/main`) | "View source at <ref>" |
    |---|---|---|
    | `source = main` | yes | no |
    | anchored, the default | yes | yes, beside the edit link |
    | anchored, not the default | no | yes |

    The default version keeps its edit link when it moves onto tags, as A and O3 set it: a reader's fix goes to `main`, which the next beta tag carries. An older version shows only the source it was built from. If a page was moved or renamed on `main` after the tag, its edit link on an anchored default opens GitHub's "not found" page. That is accepted, and the "View source" link beside it still works.

### 9. Version switch and outdated bar

- **The switch** (`opm/version-switch.html`, `opm/version-links.html`, `navbar-title.html`).
  - With two or more versions, it lists every version by label in weight order and marks the default. It keeps the prototype's nearest-parent fallback for a page missing in a version.
  - With one version, it behaves as A shipped it.
  - Styles go in `versions.css`.
- **The outdated bar** (`banner.html`) shows on every version that is not the default: "You are reading <label>. The current version is <default label>." It links the same page, or its nearest parent, in the default version.
  - The wording is neutral because a non-default version may be newer than the default, for example a beta beside a stable default.
  - The bar keeps `data-pagefind-ignore="all"`.

### 10. Every version-aware output follows the manifest

`build-all.sh` iterates the resolved version list, never `v*/` and never "every top-level directory", for:
- the per-version Pagefind index (`public/<v>/pagefind/`);
- `_redirects` (`/ /latest/ 302` and `/latest/* /<default>/:splat 302`);
- the root `index.html` refresh and the root `404.html` (copied from the default version, which it takes from the resolved list);
- the build summary's per-version page counts.

The `/latest/<path>/` stubs are not a `build-all.sh` step. A's `custom/head-end.html` publishes them for every page of the version whose `.Site.Version.IsDefault` is true. That follows the generated `defaultContentVersion` (Decision 7), so the file needs no edit and is not in Touches. Task 1.1 checks that A's merged copy hard-codes no version name. If it does, that is a deviation to report. Task 1.1 also finds which file writes `_redirects`: A's plan puts it in `build-all.sh`, while the prototype published it from `head-end.html` on the default home page.

`robots.txt` ranges `hugo.Sites` and each version publishes its own `sitemap.xml`. Section 4 proves both with two versions and edits the layouts only if they do not.

`/reference-archive/` stays reserved, because no version name can take it.

### 11. Tests

The tests use three separate directories under `site/.check/versions-test/`, gitignored through `.check/`. None can collide with a real version's `site/.check/<v>/`, because a version name matches `^v[0-9]+\.[0-9]+$`, or with A's `site/.check/tests/`:

```text
site/.check/versions-test/
  repos/    fixture git repositories of the resolver tests (test-resolve.sh recreates only this directory)
  public/   the two-version build's destination (Hugo's --cleanDestinationDir wipes only this directory)
  check/    the two-version build's <v>/nav-order.txt
```

- **Resolver tests** (`site/tests/versions/test-resolve.sh`, host `sh` and `git`).
  - The test creates small git repositories under `site/.check/versions-test/repos/`, and never uses `/tmp`.
  - The repositories carry `go.mod`, `opm/schema/loader.go`, `internal/operator/manifest.go` and `docs/site/`, with tags.
  - The cases:
    - the three pin reads;
    - an override with a reason, and one without;
    - a missing `catalog` or `opm`;
    - an anchor that is `main`, a branch, a pattern or a short SHA;
    - a pseudo-version pin;
    - a ref without `docs/site`;
    - a ref older than its floor;
    - an unknown key;
    - two defaults;
    - two `source = main` versions;
    - a bad version name;
    - a duplicate weight;
    - a `label` or override reason holding a tab, `'`, `"` or `\`;
    - a missing root;
    - a fixture root: a `docs/site` tree inside another repository, not its own git top level, as in A's fixture workspace.
  - Each failing case asserts that the message names the repository, and the ref where there is one. The two root cases assert that it names the `OPM_SRC_<REPO>` variable, and the fixture-root case that it names `OPM_VERSIONS`.
- **Resolver-only test on the real repositories**, which builds nothing.
  - `resolve-versions.sh --pins v1.0.0-alpha.25` prints library `v1.0.0-alpha.35`, core `v2.0.0-alpha.12` and opm-operator `v1.0.0-alpha.19`.
  - A `--check` of a manifest anchored at cli `v1.0.0-alpha.25`, with `catalog = opm-v4.4.2` and `opm` at its S1 floor, exits 1. Among its lines are `cli v1.0.0-alpha.25`, older than the floor, and `opm-operator v1.0.0-alpha.19`, which has no `docs/site`. Every pin at that tag is pre-S.
- **Two-version build** (`site/tests/versions/two-versions.conf` and `check-two-versions.sh`).
  - The manifest has two versions:
    - `v1.0`: `source = main`, default;
    - `v0.9`: labelled "v0.9 (test)", anchored at the cli test SHA, with `catalog` and `opm` at the catalog_opm and opm test SHAs, and overrides for library, core and opm-operator at their test SHAs. Each override's reason is "test pins post-S SHAs, no post-S tag yet".
    The version names are test-only.
  - **The test SHAs** are the six S merge SHAs (cli S4, catalog_opm S3, opm S1, library S5, core S2, opm-operator S6). The S workers only ran the dialect lint; A's real build was the first to exercise link targets, Q2 and the front-matter `errorf`. If A's merge needed source fixes after an S merge, that S snapshot does not build. Then the test SHAs are the buildable post-S SHAs the supervisor names, for example the `site-src` `HEAD`s that A merged against. Task 1.1 records the six test SHAs here. The floors stay at the S merges either way.
  - The build MUST NOT write `site/public/`, which E uploads and F deploys, or the real build's `site/.check/<v>/`. Its output goes to `site/.check/versions-test/public/` and `site/.check/versions-test/check/`. Section 4 adds a destination argument and a check-output argument to `build-all.sh` if A's has none; the defaults stay `public` and `.check`.
  - The build does overwrite the generated inputs every build shares: `site/.versions/`, `site/config/{production,development}/` and `site/data/opm/`. The test's final `versions:prepare` with the real manifest restores `site/.versions/`. The next `task build` or `task serve` regenerates the config and the data.
  - It asserts:
    - both version directories exist;
    - the switch lists both labels;
    - the outdated bar appears on `v0.9` pages only;
    - there is a Pagefind index per version;
    - there is a `nav-order.txt` per version;
    - `robots.txt` names both sitemaps;
    - `_redirects` and the `/latest/` stubs point at `v1.0`;
    - the `v0.9` stamp names the test SHAs and its "View source" links carry them;
    - `v0.9` pages have no "Edit this page" link, and `v1.0` pages have one;
    - `v0.9` pages have dates, and `data/opm/lastmod.json` holds site-owned keys for both versions.
  - The test re-runs `versions:prepare` with the real manifest when it finishes.
- **The search smoke test** (`site/tests/browser/`) queries every version listed in `build-stamp.json` `versions`. That is one version in normal runs and both in the two-version QA build.
- **Shots.** A shots extra covers the open switch and the outdated bar, and runs only when the build has two or more versions.

### 12. Taskfile

```yaml
  versions:prepare:   # host side; build and serve run it first (A). Body filled by this change.
    cmds:
      - sh site/scripts/resolve-versions.sh     # writes site/.versions/versions.tsv; with OPM_VERSIONS set it only removes a stale one
      - sh site/scripts/materialise.sh          # archives and host-side dates; with OPM_VERSIONS set it does nothing
  versions:check:
    desc: Resolve every site version and print its refs; writes nothing
    cmds:
      - sh site/scripts/resolve-versions.sh --check
  versions:test:
    desc: Resolver regression tests and the two-version build (host git, then the build image)
    cmds:
      - sh site/tests/versions/test-resolve.sh
```

Each task gets A's host source roots and `OPM_WS` from A's own resolution (Decision 3, "Source roots"). The exact mechanism comes from A's merged Taskfile and `run-in-image.sh`.

A's plan found that a Taskfile global variable declared with `sh:` shadows an environment variable of the same name (Task 3.52.0). So `OPM_VERSIONS` and `OPM_VERSIONS_MANIFEST` MUST NOT be declared as Taskfile variables. The scripts read them from the environment, which is what lets `OPM_VERSIONS_MANIFEST=... task build` work.

### Interface: what this change adds and relies on

- **Adds:**
  - `site/versions.conf`;
  - `OPM_VERSIONS_MANIFEST`;
  - `site/.versions/versions.tsv`, `site/.versions/<v>/<repo>/docs/site/` and `site/.versions/<v>/lastmod.tsv`;
  - `task versions:check` and `task versions:test`;
  - the `versions` key in `data/opm/build.json` and `public/build-stamp.json`;
  - the generated versions config (its location is set by the spike).
- **Changes:**
  - the body of `task versions:prepare`;
  - what feeds `OPM_VERSIONS`: the resolved file, with an explicit `OPM_VERSIONS` kept for fixtures;
  - the source of `[versions]`, `defaultContentVersion` and `[[params.opm.versions]]`: generated, no longer hand-written.

  No name in `orchestration.md` section 6 is renamed.
- **Relies on:**
  - `OPM_WS`, `OPM_SRC_<REPO>`, `OPM_SRC_WORKTREE`, `OPM_BUILD_REFS` and `OPM_REQUIRE_DATES`;
  - `/work/repo` and `/src/<repo>`;
  - `site/.check/<v>/nav-order.txt` and `site/public/`;
  - the partials listed under Context;
  - A's `custom/head-end.html`, unedited: its `/latest/` stubs follow `.Site.Version.IsDefault`;
  - A's `data/opm/lastmod.json` key format: `<repo>/docs/site/<path>` and `opmodel.dev/site/content/<path>`, each to `{version: date}`;
  - `versions.css`;
  - `task build`, `serve`, `test:site`, `qa` and `ci`;
  - checks 2 (lint on every root, `.versions/<v>/` included), 5 (A1), 6 (Q2), 12 (redirect files) and 13 (dates).

## Research & Decisions

### Pins and tags

**Context**: The resolver reads the pins from source files at a tag, and the tests assert real values.

**Explored**: `git show` on the local tags and `origin/main` refs on 2026-09-30:
- cli `go.mod:13`, on `origin/main` and at tag `v1.0.0-alpha.25`, holds library `v1.0.0-alpha.35`;
- library `opm/schema/loader.go:35`, at tag `v1.0.0-alpha.35`, holds `const DefaultSchemaModule = "opmodel.dev/core@v2.0.0-alpha.12"`. Library `origin/main` has since moved the constant to line 42 and pins core `v2.0.0-alpha.13`, so the resolver matches the line by its text, never by its number. The tests read tags, so they are unaffected;
- cli `internal/operator/manifest.go:19`, on `origin/main` and at tag `v1.0.0-alpha.25`, holds `const PinnedOperatorVersion = "v1.0.0-alpha.19"`.

`docs/site` exists at cli `v1.0.0-alpha.25`, library `v1.0.0-alpha.35`, core `v2.0.0-alpha.12`, catalog_opm `opm-v4.4.2` and opm-operator `v1.0.0-alpha.21`. It does not exist at opm-operator `v1.0.0-alpha.19`. Catalog tags carry prefixes (`opm-v4.4.2`, `k8s-v1.0.0-alpha.5`), and opm has only per-directory tags (`core/v1.0.4` ...), no repository-level tag. `cli/hack/platform/` holds a CUE module (`cue.mod/module.cue`, `platform.cue`) with dependency versions of its own, but it is a test fixture for the CLI's own tests, not what a released CLI uses.

**Decision**: Read the three pins as Decision 3 says. Keep catalog and opm explicit. Fail on a pin without `docs/site` or below its floor.

**Rationale**: These are the pins the shipped CLI actually uses (O3). The CLI pins no catalog, so the catalog ref must be explicit. Every tag above is pre-S, so the real-repository test can only be resolver-only.

### Manifest syntax

**Context**: The resolver runs on the host, where only `git`, `sh` and `awk` are available. The container must not gain a tool.

**Explored**: `git config --file` on a sample `versions.conf` outside any repository (git 2.55.0):
- `version.v1.0.label` resolves: git splits on the first and last dot, so a subsection may hold dots;
- `--get-all version.<v>.override` returns every override in file order;
- `--type=bool` reads `default`;
- `--name-only --get-regexp '^version\.'` lists the keys in file order;
- `[repo "catalog_opm"]` is valid, because a subsection may hold `_`, while a key may not.

**Decision**: git-config syntax, with repository names only in subsections and values. The anchor keys are `cli`, `catalog` and `opm`.

**Rationale**: No parser to write or pin, and exact error lines. A YAML manifest would need `yq` in the image, and the host could not read it.

### Build strategy

**Context**: How each anchored version's trees reach Hugo.

**Explored**: three ways, on 2026-09-30:
- `git archive` per repository and ref;
- Hugo modules: only 3 of 6 repositories have `go.mod`, and the prefixed catalog tags defeat Go's resolver;
- a `git worktree add` per ref: it writes into each source repository's `.git`, and its own `.git` file would point at a host path the container does not mount.

`.gitattributes` on `origin/main` of all six repositories has no `export-ignore` or `export-subst`. `git -C cli archive v1.0.0-alpha.25 docs/site | tar -x` extracted the 5 files of that tree.

**Decision**: `git archive` into `site/.versions/<v>/`, on the host.

**Rationale**: It is read-only against the source repositories (Principle IV). It leaves no `.git` inside the build, works for all six, and needs no Go proxy.

### Hugo's versions config

**Context**: The `[versions]` table and `defaultContentVersion` must come from the manifest.

**Explored**: hugodocs (context7):
- versions sort by weight ascending, then by semver descending;
- `defaultContentVersion` must match a defined version;
- config directory files are split by root key, with environment directories merging over `_default`;
- `--config a,b` merges left to right.

Not verified: that Hugo 0.167.0 accepts both keys from a generated file in `build` and `serve` alike.

**Decision**: Spike in task 1.2, three candidate forms (Decision 7). Record the chosen form here.

**Rationale**: It is the one unverified assumption that changes where generated files live.

### Dates for site-owned pages

**Context**: Once `versions:prepare` computes dates on the host, gen-lastmod must still date the site-owned pages (the landing and the section overviews). E's CI runs with `OPM_REQUIRE_DATES=1`, so a missing date fails every CI build.

**Explored**: the prototype's `scripts/gen-lastmod.sh` loops over the six repositories and `opmodel.dev`, and keys site-owned pages as `opmodel.dev/site/content/<path>`. A's plan (spike item 2) records that in a worktree build the container-side `git log` dates no site-owned page, because the worktree's `.git` file points at a host path.

**Decision**: `materialise.sh` also writes the site-owned rows, from the opmodel.dev checkout on the host, into every version's `lastmod.tsv`. In manifest mode gen-lastmod runs no `git` and still counts misses over every page (Decision 6).

**Rationale**: One date source per mode. Worktree builds date every page, so `OPM_REQUIRE_DATES=1` becomes a local gate instead of a first failure on the PR's workflow run. The alternative, a container-side pass for site-owned pages beside the host rows, keeps two date sources and leaves worktree builds without site-owned dates.

### Release visibility of `docs` commits

**Context**: Whether the S merges produce tags.

**Explored**: `release-please-config.json` on `origin/main`: `docs` is `hidden: false` in cli, library and opm-operator, and hidden in core and catalog_opm.

**Decision**: None for this change. The proposal lists what moving onto tags takes, and the owner decides.

**Rationale**: Tags and releases are owner actions (`orchestration.md` section 9).

## Risks / Trade-offs

- **A worktree's `.git` points at a host path (trap 21).** A container-side `git` fails silently. → Every `git` call against a source repository runs on the host, in `versions:prepare`, and the container reads only the resolved file.
- **A stale local `main` branch.** `git rev-parse main` in an owner checkout or a detached `site-src` worktree names an old commit. → `source = main` means the root's `HEAD`, and the resolver never names the branch.
- **Building against the owner's stale main checkouts (trap 25).** → The floor check on `HEAD` fails, naming the repository. Builds use `OPM_SRC_WORKTREE=site-src`.
- **No existing tag can be built (trap 36).** → Floors refuse pre-S refs. The two-version test pins post-S SHAs. The resolver-only test reads alpha.25 pins without building.
- **A pin predates `docs/site`, or is a pseudo-version.** For example, opm-operator `v1.0.0-alpha.19` has no `docs/site`. → The error names the repository, the file and the anchor. The fix is an override with a reason, shown in the stamp.
- **A moving line creeps back.** → An anchor is a tag or a full SHA, and `source = main` is allowed once and marked (O3). Nightly builds change an anchored version only through a commit.
- **Version names are compared as numbers (trap 8), or matched by globs (trap 5).** → Names are exact `vN.N` strings, quoted in the generated TOML, and never globbed.
- **The two-version test overwrites the deploy artifact.** → Its output goes to `site/.check/versions-test/{public,check}/`, never `site/public/`, and `check-two-versions.sh` fails if `site/public/v0.9/` exists. It restores the real `versions.tsv` and `site/.versions/` when it finishes; the next build regenerates the config and data it overwrote.
- **Site-owned pages lose their dates in manifest mode.** gen-lastmod no longer runs `git`, and E's CI sets `OPM_REQUIRE_DATES=1`. → `materialise.sh` writes site-owned rows too (Decision 6), and sections 2-4 gate on `OPM_REQUIRE_DATES=1 OPM_SRC_WORKTREE=site-src task build`.
- **A fixture root resolves the wrong repository.** A root inside opmodel.dev makes `git -C <root>` read opmodel.dev. → The root checks in Decision 3 run first and name `OPM_SRC_<REPO>` and explicit mode.
- **An S snapshot does not build.** If A's merge needed source fixes after the S merges, the S merge SHAs fail A's checks, and no section of this change could end green (trap 32). → The test SHAs fall back to the buildable post-S SHAs the supervisor names (Decision 11). The floors stay at the S merges.
- **E reads `build-stamp.json`.** → A's keys stay, and this change only adds `versions`.
- **Hugo drops pages mounted from under a dot-directory (`site/.versions/`).** → The spike builds one anchored version from there. The Q2 page-set check fails on any silently dropped page.
- **Explicit-mode ambiguity.** A's `site/scripts/test-site.sh` runs in the image and feeds fixture roots through `OPM_VERSIONS`, without `versions:prepare`, while a stale `versions.tsv` from a real build may be present. → An explicit `OPM_VERSIONS` wins in `build-all.sh`, and prepare removes the file in explicit mode. Task 1.1 reads A's harness, and section 2 adapts its fixture call sites if needed.
- **A Taskfile variable shadows the environment** (Task 3.52.0, found by A). → No `versions:*` task declares `OPM_VERSIONS` or `OPM_VERSIONS_MANIFEST` as a variable (Decision 12).
- **Static files publish once, at the root (trap 9).** → Pagefind, sitemaps, `llms.txt` and 404 stay per version. Only the root `404.html`, `robots.txt`, `_redirects` and `index.html` are shared, and they are built from the default version.
- **Full history is needed (trap 29).** → E checks out with `fetch-depth: 0`, which includes tags. Local worktrees share their repository's history.
- **Build time grows per version.** An archive of about 50 files per repository, one more Hugo site and one Pagefind run is about a second per version. → Acceptable. The archive marker skips unchanged trees.
- **A tag is moved upstream.** → The stamp and `build-stamp.json` record the SHA a build used. The resolver does not detect a retag.

## Durable decisions

- `site/versions.conf` is the only list of site versions. Nothing else lists versions or globs `v*/`, and an anchored version is changed only by a commit to it. → A new `## Site versions` heading in `AGENTS.md` and one in `README.md`. This change does not edit A's `## Durable decisions` section or its layout tree.
- `source = main` is allowed only until `v1.0.0-beta.N` tags exist (O3). Moving `v1.0` onto tags is the manifest edit shown in the proposal. → `README.md` "Site versions", and the manifest's header comment.
- Where pins come from: library from `cli/go.mod`, core from library `DefaultSchemaModule`, the operator from cli `PinnedOperatorVersion`, and catalog and opm explicit. Never `cli/hack/platform/`. An override needs a reason. → `AGENTS.md` "Site versions".
- Each repository's dialect floor is its S merge, and no older ref builds. → `AGENTS.md` "Site versions", and the manifest's header comment.
- A fixture-workspace build runs in explicit mode, with `OPM_VERSIONS=v1.0=/src`, because its roots are not git top levels. → `README.md` "Site versions".
- In manifest mode every git date is computed on the host by `materialise.sh`, site-owned pages included; gen-lastmod runs `git` only in explicit mode. → `AGENTS.md` "Site versions".
- Which core the site presents is 0021:OQ15 and stays open. → Already in `openspec/config.yaml` ("Site Versions"). It stays with the change.
- The two-version test never writes `site/public/`. → A comment in `site/tests/versions/check-two-versions.sh`. It stays with the change.

## Open Questions

- **For the supervisor:** may this change add one line to A's `test:site`, running `versions:test`, so that `task ci` and E's workflow run the resolver tests and the two-version build?
  - That is outside the change-set plan's allowance, which limits this change to the `versions:*` tasks.
  - If the answer is no, `versions:test` still runs as every section's gate, and a follow-up adds a `task versions:test` step to E's `site.yml`.
  - Either answer leaves the design and the sections unchanged.
