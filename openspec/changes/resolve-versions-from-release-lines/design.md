## Context

`version-site-from-tags` (archived 2026-09-30) built the versions machinery this change extends. Paths below are relative to `site/` unless noted.

- **Manifest.** `versions.conf` is read with `git config --file`. A version is either `source = main` (every root at its checked-out `HEAD`, read in place) or anchored: `cli` is a tag or a full SHA. Library, core and opm-operator come from the cli pins, `catalog` and `opm` are explicit, and `override = <repo> <ref> <reason>` replaces one row. Explicit mode (`OPM_VERSIONS=name=root ...`) skips resolution, for fixture builds.
- **Resolver.** `scripts/resolve-versions.sh` runs on the host (`task versions:prepare`) and writes `.versions/versions.tsv`, one row per version and repository: `version label weight default kind repo ref sha how`. Its `anchor()` refuses branches, `HEAD`, patterns and short SHAs on purpose. `resolve_pins()` reads the three pins. `check_ref()` checks `docs/site` and the floor with `git merge-base --is-ancestor <floor> <sha>`. It never fetches: it reads whatever refs the local roots hold.
- **Readers of `kind`.**
  - `scripts/materialise.sh` archives only `kind = anchored` (`[ "$kind" = anchored ]`); anything else reads the working tree.
  - `scripts/build-all.sh` and `scripts/serve.sh` map `kind = main` to `/src` and every other kind to `.versions/<v>`.
  - `layouts/_partials/opm/build-stamp.html` (footer), `opm/source.html` (view link) and `components/last-updated.html` (edit link) test `eq kind "anchored"`.

  A new kind name would mis-route silently in materialise.sh and in all three layouts.
- **Stamp.** `scripts/gen-stamp.sh` writes `data/opm/build.json`, which `build-all.sh` publishes as `public/build-stamp.json`: `sources` (each root's checked-out `HEAD`, from `OPM_BUILD_REFS`) and `versions.<v>.refs.<repo>.{ref,sha,how}`.
- **CI** (`.github/workflows/site.yml`).
  - Both the `build` and `browser` jobs check out the six source repositories at `ref: main` with `fetch-depth: 0`.
  - A nightly cron (`23 3 * * *`) runs both jobs, and `pages-deploy` publishes on push, schedule and dispatch of `main`.
  - The Summary step prints `.sources`.
  - The `build-stamp` artifact keeps `build-stamp.json` for 90 days.
- **The owner's rules (2026-10-01).** These reverse O3 of the archived change ("a fixed anchor ref bumped by commit, never a moving line"):
  1. Follow the CLI: take the newest cli tag in the version's line (prereleases included, semver order); library, opm-operator and core are exactly what that tag pins.
  2. core and catalog_opm docs come from the release-branch head once the branch exists, and from `main`'s head during beta. Their versions in the stamp still come from the cli pin and the catalog line.
  3. catalog_opm follows the opm line `opm-v4.4`. This design reads that as the opm catalog's `v4` line, of which `opm-v4.4` is today's minor (decision 1). The cli consumes the catalog by major, and a minor line would freeze silently at the next opm minor. The owner confirms this reading before launch (Open Questions).
  4. opm (no release line) builds from `main`'s head.

  Every build records every SHA, and the dialect floors still fail loudly.
- **Release branches** (workspace `AGENTS.md`). `release/<tag-prefix>vX.Y`: core `release/v2.0`; library, cli and opm-operator `release/v1.0`; catalog_opm `release/opm-v4.4` and `release/k8s-v1.0`. A branch is cut lazily, from the newest final tag of its minor, only when `main`'s next release is `X.(Y+1).0` or higher and the minor needs a fix. None exists during beta. Branches are never deleted or force-pushed (the active `release-branches` ruleset).
- **Live facts (2026-10-01, all six repositories fetched).**
  - `git ls-remote --heads origin 'release/*'` is empty in every repository.
  - Tags: cli `v1.0.0-beta.1..4`; library `v1.0.0-beta.1`; opm-operator `v1.0.0-beta.1..3`; core `v2.0.0-beta.1`; catalog_opm `opm-v4.4.0..4`, `k8s-v1.0.0-beta.1` and legacy unprefixed `v0.4.0..v2.0.0-alpha.4`; opm only sub-package tags (`core/v1.0.4`).
  - Pins: cli `v1.0.0-beta.4` pins library `v1.0.0-beta.1` and operator `v1.0.0-beta.2`, which is not the newest operator tag, `beta.3` (the operator's `main`, c3e4232). Library `v1.0.0-beta.1` pins `opmodel.dev/core@v2.0.0-beta.1`.
  - Heads (snapshot 2026-10-01 18:30 CEST, after a fetch; heads move, tags do not): core `main` f5c4463 is three commits past `v2.0.0-beta.1` (`docs(policy)` #86, `ci(release)` #87, `docs(spec)` #88); catalog_opm `main` 64a65a5 is two commits past `opm-v4.4.4`; opm `main` 4e582b8. `docs/site` is the same tree at every pinned tag and at `main` in all five tagged repositories.
  - The catalog's opm package releases finals and moves minors fast: `opm-v4.0.0` (2026-08-31), `4.1.0` and `4.2.0` (09-14), `4.3.0` and `4.4.0` (09-15), `4.4.4` (09-30). Any `feat` there releases `opm-v4.5.0`.
  - The cli consumes the catalog by major. At `v1.0.0-beta.4`, `DefaultCatalogPaths` in `internal/config/templates.go` is `{"opmodel.dev/catalogs/opm@v4", "opmodel.dev/catalogs/k8s@v1"}`, and `opm operator install` resolves a published version of the first. Its three `templates/*/cue.mod/module.cue` start a new module at `v4.4.4`, a minimum that dependency resolution may raise.
  - catalog_opm's one `docs/site` tree holds the opm and the k8s catalog pages (`reference/kubernetes-resources.md`, `authoring/use-a-raw-kubernetes-resource.md`).
  - Every workspace clone's `origin` is `git@github.com:open-platform-model/<repo>.git`, and no clone sets `fetch.prune`, `fetch.pruneTags` or a tag fetch refspec. CI's checkouts use `https://github.com/open-platform-model/<repo>`.
  - The local catalog_opm clone still holds `refs/remotes/origin/release/opm-stable`, a branch deleted upstream (no prune).

Files touched under `site/`:
- `versions.conf`;
- `scripts/resolve-versions.sh`, `scripts/materialise.sh`, `scripts/gen-stamp.sh`, plus comments only in `scripts/build-all.sh`, `scripts/serve.sh` and `scripts/gen-mounts.sh`;
- `layouts/_partials/opm/build-stamp.html`, `layouts/_partials/opm/source.html` and `layouts/_partials/components/last-updated.html`. The last is an override copy we own; editing it adds no `overrides.sha256` line;
- `tests/versions/test-resolve.sh`, `tests/versions/two-versions.conf` and `tests/versions/check-two-versions.sh`.

Outside `site/`: `Taskfile.yml`, `.github/workflows/site.yml`, `README.md` and `AGENTS.md`.

The build gains six `git archive` trees for `v1.0` (`.versions/v1.0/<repo>/`) in place of the working-tree mounts it reads today. The resolver gains the roots' tags and `refs/remotes/origin/*` as inputs. There is no new mount, source repository, vendored file or pinned tool, and the published URLs and the version set do not change.

## Goals / Non-Goals

**Goals:**
- A site version can name release lines instead of fixed refs. Each build resolves the newest release of each line by the owner's rules, with no manifest commit.
- Every build records, per version and repository, the ref, the SHA of the tree it built, where that tree came from and the rule that chose it: in `versions.tsv`, `build-stamp.json`, the footer and the CI summary. It also records the opmodel.dev commit. That commit plus `frozen.conf` rebuild the same trees.
- Floors, `docs/site` presence and a new tag-containment check fail loudly. Each failure names the version, the repository, the ref and the rule that chose it.
- An override in a line version cannot outlive the failure it was added for.
- `v1.0` (beta) moves onto line mode. The `source = main` and explicit modes stay for tests and local live editing.

**Non-Goals:**
- Settling 0021:OQ15. The site shows the core the cli pins, as before.
- Cutting, creating or protecting release branches, or any release automation (Phase 2 in the workspace `AGENTS.md`).
- A cross-repository dispatch (decision 9).
- Changing where "Edit this page" points for cli, library and opm-operator after GA. A fix to a released line there goes to `release/v1.0`, which needs per-line edit targets. That is a follow-up (Open Questions).
- A second site version, or a new URL.
- Versioning the k8s catalog pages on their own. They share catalog_opm's `docs/site` with the opm catalog pages and follow the opm line's tree; `release/k8s-v*` is never read (Open Questions).
- Checking that `origin` is the open-platform-model repository (decision 4).

## Decisions

### 1. The manifest grammar: a third kind, `line`

```ini
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	cli-line = v1.0            ; ^v[0-9]+\.[0-9]+$ : the cli tag line vX.Y
	catalog-line = opm-v4      ; ^opm-v[0-9]+$ : the opm catalog major
	; override = <repo> <ref> <reason>   never for cli; only while the row it replaces fails
```

- **Key names.** Git-config variable names allow only letters, digits and `-`, so the keys are `cli-line` and `catalog-line`. With `catalog_line`, `git config` fails ("bad config line"); see Research.
- **Kind by keys.**
  - `source` makes a version `main`.
  - `cli-line` makes it `line`.
  - Otherwise it is `anchored`, as today.
- **Exclusions.**
  - A line version requires `cli-line` and `catalog-line`, and excludes `source`, `cli`, `catalog` and `opm`.
  - `source = main` also excludes `cli-line` and `catalog-line`.
  - An anchored version (no `source`, no `cli-line`) excludes `catalog-line`, with a named error, so a stray key is never silently ignored.
  - Each key appears at most once, and an unknown key still fails.
- **The catalog line is a major.** `catalog-line = opm-v4` follows the newest `opm-v4.*` release by itself.
  - The cli consumes the catalog by major (Context), so the newest `v4` release is what a cli `v1.0` user gets.
  - The opm package releases finals and moves minors often (Context). A minor line (`opm-v4.4`) would stop at its last tag on the first `opm-v4.5.0`. Rule 3 (decision 2) would then document `opm-v4.4.4` with a green build and no alarm, against owner rule 2 (catalog docs from `main` during beta).
  - The minor the docs rules need (`release/opm-v4.Y`) is the minor of the resolved tag (decision 2), so nothing is lost.
  - Only `opm-v` is accepted. A `k8s-v` line would source the opm catalog pages from the k8s line, and a minor (`opm-v4.4`) fails with a named error.
  - A new catalog major (`opm-v5`) is a manifest commit, made when the cli moves to it.
  - Rejected: deriving the catalog from the cli tag, as library is. The cli has no single catalog pin. `DefaultCatalogPaths` names only the major, and the three templates each name a minimum version. Owner rule 3 also keeps the catalog off the cli pins.
- **Overrides.** `override = <repo> <ref> <reason>` replaces one row, never cli, and the reason is required, as in anchored mode. In a line version it is an escape hatch for a row that fails, and it cannot outlive that failure:
  - The row is read at that tag or full SHA (`anchor`). Its `docs` is `tag` or `sha`, after the ref. `docs_source` and the containment check do not run, because the override names the tree. The floor and `docs/site` checks do run.
  - core is still read at the effective library: overriding library moves the core pin, as today.
  - The row the override replaces is still resolved and checked, without reporting its errors, and `how` records it: `override:<reason>; replaces <its ref> (<its how>)`, or `override:<reason>; replaces no pin`.
  - Once that replaced row passes every check, the run fails with a named error: `<version>: <repo> override <ref> (<reason>): no longer needed: the line resolves <ref> (<how>), which passes every check; remove the override`. An override added for one cli release (a pseudo-version, a `replace`, a pre-floor pin) therefore fails at the first cli release that no longer needs it. It never silently replaces the pins of every later tag.
  - An `opm` override is refused at once unless `main`'s head itself fails (no `docs/site`, or older than the floor): opm has no release to fall back to.
  - Anchored versions keep today's override rules, with no replaced-row check: they change only by commit.
- **Several versions.** Any number of line versions is allowed. At most one version may have `source = main`, as today.
- **The cli line is explicit.** `cli-line` is not derived from the version name: a later `v1.1` site version could still follow `cli-line = v1.0` while it is being prepared.

### 2. How a line version resolves, per repository

| Repo | `ref` (the stamp names it) | Tree built (`sha`) and `docs` value | `how` |
|---|---|---|---|
| cli | the newest tag in `cli-line`, by semver precedence, prereleases included | the tag's commit, `tag` | `line:newest v1.0.* tag` |
| library | the version in `cli/go.mod` at that tag | the tag's commit, `tag` | `pin:cli go.mod` (unchanged) |
| opm-operator | `PinnedOperatorVersion` at that tag | the tag's commit, `tag` | `pin:cli internal/operator/manifest.go` (unchanged) |
| core | `DefaultSchemaModule` at the pinned library tag, for example `v2.0.0-beta.1` | `docs_source core "" 2.0` (below; `2.0` is the pin's minor) | `pin:library opm/schema/loader.go; docs: <rule>` |
| catalog_opm | the newest tag of the `catalog-line` major, for example `opm-v4.4.4` | `docs_source catalog_opm opm- 4.4` (`4.4` is that tag's minor) | `line:newest opm-v4.* tag; docs: <rule>` |
| opm | `main` | `refs/remotes/origin/main`, `main` | `line:main head` |
| any overridden row (decision 1) | the override's tag or full SHA | that commit, `tag` or `sha` | `override:<reason>; replaces <ref> (<how>)` |

`resolve_pins()` is reused for library, opm-operator and core (versions and tag commits). The line mode replaces where the cli ref comes from, swaps the core row's tree for its docs source, and records what an override replaces.

**`docs_source REPO PREFIX X.Y`**, for core and catalog_opm. `X.Y` is the minor of the release the stamp names: for core the pinned tag, for catalog_opm the newest tag of the major. The first rule that applies wins:

```text
1. refs/remotes/origin/release/<PREFIX>vX.Y exists
       -> docs = release/<PREFIX>vX.Y, sha = that branch head
          rule "release/<PREFIX>vX.Y head"
2. else the newest <PREFIX>v<semver> tag merged into refs/remotes/origin/main is in X.Y
       -> docs = main, sha = origin/main
          rule "main head (no release/<PREFIX>vX.Y; main still releases <PREFIX>vX.Y)"
3. else (main is past the line, and no branch was ever cut because the line needed no fix)
       -> docs = tag, sha = the commit of the release the stamp names
          rule "<ref> (main is past <PREFIX>vX.Y, no release/<PREFIX>vX.Y)"
then, under rules 1 and 2: the release the stamp names must be an ancestor of sha.
      Otherwise the run fails, naming both.
```

- Rules 1 and 2 are the owner's (decision 2: the release branch once it exists, else `main` during beta).
- Rule 3 closes a hole the owner's two cases leave, because branches are cut lazily. When `main` has moved past the line and the line never needed a fix, `main`'s head documents the next minor, not this line.
  - Rule 3 archives the release the stamp names itself, so `docs = tag` always means that the tree is the ref. The footer and "View source at <ref>" (decision 8) can never name one release while showing another.
  - A newer patch of the same minor is not used. Example: library pins core `v2.0.0`, core has tagged `v2.0.1`, and `main` has released `v2.1.0`. Then the docs are `v2.0.0`'s, because that is the core the cli uses.
  - For the catalog, the release is the newest tag of the major, which is also the newest of its own minor.
  - Open Questions asks the owner to confirm rule 3 against failing instead.
- Only the exact derived branch name is read. A stale or unrelated tracking ref is never consulted, such as catalog_opm's local `refs/remotes/origin/release/opm-stable`.
- `release/k8s-v*` is never derived, so a k8s docs fix on a release branch does not reach the site (Non-Goals).

### 3. Semver precedence, not `sort -V`

- **The filter is a regex built from the line,** never a glob:
  - a minor line: `^<PREFIX>v<X>\.<Y>\.[0-9]+(-[0-9A-Za-z.-]+)?$` (cli `^v1\.0\.[0-9]+...`);
  - the catalog major: `^<PREFIX>v<X>\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$` (`^opm-v4\.[0-9]+\.[0-9]+...`).

  It drops other lines (`v1.50.0` is not in `v1.5`, `opm-v40.0.0` is not in `opm-v4`), `k8s-v*` for the opm line, and catalog_opm's unprefixed legacy tags (`v2.0.0-alpha.4`), which would win a naive sort.
- **`semver_max PREFIX` is an awk function.** It reads tag names and prints the highest by SemVer 2.0.0 §11:
  - major, minor and patch compare numerically;
  - a release outranks its own prereleases;
  - prerelease identifiers compare left to right: numeric identifiers numerically, below alphanumeric ones, which compare in ASCII order; a shorter set ranks lower when it is a prefix of a longer one.

  So `v1.0.0` > `v1.0.0-rc.1` > `v1.0.0-beta.10` > `v1.0.0-beta.2`, and `v1.0.1-beta.1` > `v1.0.0`.
- **Rejected sorts.** `sort -V` and `git tag --sort=-v:refname` both rank `v1.0.0` below `v1.0.0-beta.4`. `git -c versionsort.suffix=- ...` ranks correctly only while every prerelease uses `-`. It is not POSIX either, so it is the oracle in the real-repository test (decision 11), not the implementation.

### 4. Which refs are read, and fetching

- **Refs read.** Tags are `refs/tags/*` (peeled with `^{commit}`, as `commit_of` does today). Branch heads are `refs/remotes/origin/main` and `refs/remotes/origin/release/<name>`.
  - Never `refs/heads/*`: a CI checkout has no local release branch, and a local one can be stale or diverged.
  - Never `HEAD` in line mode: `site-src` worktrees sit detached at an older `origin/main`. A worktree shares its repository's tags and remote-tracking refs, so a fetch in the main checkout is enough.
- **Root checks, before a line version resolves**, each a named error:
  - `git rev-parse --is-shallow-repository` must print `false`; a shallow root cannot run the floor or containment check;
  - `refs/remotes/origin/main` must exist in all six roots;
  - a fixture root that is not its own git top level already fails today.
- **`origin` is assumed, not checked.** The resolver trusts that `origin` is the open-platform-model repository. Every workspace clone and every CI checkout has that origin (Context). In a fork-based clone (origin = a personal fork), line mode would resolve the fork's tags, `main` and `release/*`. The resolver does not check the URL: the fixture line roots are clones of local paths, and a test-only bypass is worse than this local-only risk. The header comment states the assumption next to the `origin/main` check, and README "Site versions" says a local build needs `origin` to be the upstream repository.
- **The resolver never fetches.** It stays offline and deterministic over the local refs, as it is today; the build containers have no network anyway.
- **`resolve-versions.sh --fetch`** (`task versions:fetch`) runs this in each of the six roots, resolved as for a build (`OPM_SRC_*`, `OPM_SRC_WORKTREE`):

  ```sh
  git -C <root> fetch --no-write-fetch-head --no-prune --no-prune-tags --no-tags origin \
    '+refs/heads/*:refs/remotes/origin/*' 'refs/tags/*:refs/tags/*'
  ```

  - **No user config can move or delete a tag** (verified with git 2.55.0, Research):
    - The explicit refspecs replace any configured one, so a configured `+refs/tags/*:refs/tags/*` cannot force a tag. A plain `git fetch --tags origin` would let it.
    - The tag refspec has no `+`. Git refuses to move a local tag that differs upstream ("would clobber existing tag") and exits 1, while every other ref still updates. That doubles as a tamper alarm for the immutability rule.
    - `--no-prune --no-prune-tags` beat `fetch.prune`, `fetch.pruneTags` and `remote.origin.prune*`. With those set, `git fetch --tags origin` deletes local-only tags.
  - **It writes nothing in a worktree.** From a `site-src` worktree, a plain fetch writes `FETCH_HEAD` into `.git/worktrees/site-src/`. `--no-write-fetch-head` leaves only the shared refs and objects changed.
  - Remote-tracking refs update forcibly, as in any fetch. A branch deleted upstream stays local (no prune), which is harmless: only the exact derived `release/` name is read.
  - It creates no local branch and never moves or deletes a tag. It fetches every root, then exits 1 naming each root whose fetch failed.
  - A local build after a release is `task versions:fetch build`. CI needs no fetch (decision 9).

### 5. Rows: the `docs` column and the kind `line`

`versions.tsv` gains a tenth column, `docs`: where the archived tree came from. A second comment line records the opmodel.dev commit the run resolved from (decision 10); every reader already skips `#` lines. The rows below are the 2026-10-01 18:30 CEST snapshot (Context):

```text
# version label        weight default kind repo         ref           sha       how                                                                docs
# site 0f3a19c…
v1.0      v1.0 (beta)  1      true    line cli          v1.0.0-beta.4 0e66ec08… line:newest v1.0.* tag                                             tag
v1.0      v1.0 (beta)  1      true    line library      v1.0.0-beta.1 02344e59… pin:cli go.mod                                                     tag
v1.0      v1.0 (beta)  1      true    line opm-operator v1.0.0-beta.2 27d9dfc3… pin:cli internal/operator/manifest.go                              tag
v1.0      v1.0 (beta)  1      true    line core         v2.0.0-beta.1 f5c44632… pin:library opm/schema/loader.go; docs: main head (no release/v2.0; main still releases v2.0)  main
v1.0      v1.0 (beta)  1      true    line catalog_opm  opm-v4.4.4    64a65a5a… line:newest opm-v4.* tag; docs: main head (no release/opm-v4.4; main still releases opm-v4.4)  main
v1.0      v1.0 (beta)  1      true    line opm          main          4e582b8e… line:main head                                                     main
```

- **`docs` values by kind.**
  - `line`: `tag`, `main` or `release/<prefix>vX.Y`; an overridden row `tag` or `sha`.
  - `anchored`: `tag` or `sha`, after the ref.
  - `main`: `worktree`, the root's checked-out tree, uncommitted edits included.
- **Why a column.** A core row now holds two facts: the version the stamp names, and the commit whose docs are built. `how` alone would make the layouts parse free text, and two rows per repository would break every reader keyed on `(version, repo)`. The tenth column is appended, so readers that index columns 1-9 are unaffected. Every `expect` pattern in today's test-resolve.sh matches a substring and keeps passing.
- **The kind `line`** is new rather than reused `anchored`: the stamp then says the version moves on every build, and the footer and links need line-specific text anyway (decision 8). Every reader of `kind` changes (decision 7). No published text carries an `@`: a branch ref prints as `main f5c4463`, never `main@f5c4463`.

### 6. Checks and named errors

- **Every row is checked** as today (`check_ref`, kind not `main`): `docs/site` must exist at `sha` (`git ls-tree`) and the floor must be an ancestor of `sha`. The tree that is built is checked.
- **New: floors at the stamped release.** For core and catalog_opm the floor is also checked on the commit of the release the stamp names. A pre-floor pin then fails in line mode as it does in anchored mode, even when its docs come from a post-floor branch head. Under rule 3 the two commits are the same.
- **New: containment.** Under rules 1 and 2, for core and catalog_opm, the release the stamp names must be an ancestor of the docs SHA. This catches a rewritten branch and a line derived from the wrong pin.
- **New: stale overrides.** An override in a line version whose replaced row passes every check fails (decision 1).
- **New: the frozen manifest is never its own input.** When `OPM_VERSIONS_MANIFEST` resolves to `site/.versions/frozen.conf`, the run fails by path, before reading the file: write mode would rewrite it on success and delete it on failure.
- **The ref text in a line version's error names the rule**: `<version>: <repo> <ref> (<rule>): <reason>`. For example:

```text
v1.0: cli v1.0.0-old (newest tag of line v1.0): older than its floor 7d8f44b6… (the page-dialect merge); no ref before it builds
v1.0: cli line v1.0: no tag v1.0.<patch>[-<pre>] in /…/cli; fetch its tags (task versions:fetch)
v1.0: core release/v2.0 3c1a2b4 (docs for v2.0.0-beta.1): does not contain v2.0.0-beta.1, the release the stamp names
v1.0: core v2.0.0-old (the release the stamp names; docs main head): older than its floor 647dfdcf… (the page-dialect merge)
v1.0: library override v1.0.0-beta.3 (pseudo pin in cli beta.5): no longer needed: the line resolves v1.0.0-beta.3 (pin:cli go.mod), which passes every check; remove the override
v1.0: opm: root /…/opm: a shallow clone; a line version needs full history and tags (fetch-depth: 0)
v1.0: core: root /…/core: no refs/remotes/origin/main; a line version reads remote-tracking refs (task versions:fetch)
resolve-versions: /…/site/.versions/frozen.conf is the generated frozen manifest, which this run rewrites; copy it outside site/.versions/ first
```

As today, every failure is collected, the run exits 1, and write mode leaves no `versions.tsv` (and now no `frozen.conf`) behind. A failure in one version fails the whole manifest, never only that version (Risks). A pre-floor newest tag fails; the resolver never skips back to an older tag.

### 7. Readers of `kind`

- `materialise.sh`: `[ "$kind" = anchored ]` becomes `[ "$kind" != main ]`. Every non-`main` version is archived by SHA. The `.sha` cache is keyed on the SHA, so a head that moved re-archives and an unchanged one is kept.
- `build-all.sh` and `serve.sh`: no logic change (`$5 == "main"` reads `/src`, anything else `.versions/<v>`); only the comments name the third kind.
- `gen-mounts.sh` reads columns 1-4 only; its comment changes.
- The three layouts: decision 8.

### 8. Stamp, footer and links

`build.json` (and so `public/build-stamp.json`) gains `docs` per ref, and `site`, the opmodel.dev commit from the `# site` line of `versions.tsv` (absent in explicit and fixture builds, which have no `versions.tsv`):

```json
"site": "0f3a19c…",
"versions": {
  "v1.0": {"label": "v1.0 (beta)", "default": true, "kind": "line",
           "refs": {"core": {"ref": "v2.0.0-beta.1", "sha": "f5c44632…", "how": "pin:library opm/schema/loader.go; docs: main head (…)", "docs": "main"}, "…": {}}}
}
```

`sources` stays as it is: each root's checked-out `HEAD`. Only `main`, explicit and fixture builds show it. Its comment says that for `anchored` and `line` versions `versions.<v>.refs` and `site` are the record.

Footer (`opm/build-stamp.html`), for `anchored` and `line`: "documents" and one entry per repository, each linked to `commit/<sha>` with `how` as the link title:

| Row | Shown |
|---|---|
| `docs = tag` or `sha`, or anchored | `cli v1.0.0-beta.4` (a SHA ref as seven hex characters, as today). The tree is the ref (decision 2, rule 3), so the text is exact. |
| `docs` is a branch and `ref` is that branch (opm) | `opm main 4e582b8` |
| `docs` is a branch and `ref` is a release | `core v2.0.0-beta.1 (docs main f5c4463)` |

Links (`opm/source.html`, `components/last-updated.html`):

| Version | "Edit this page" | "View source at <text>" |
|---|---|---|
| `main` or explicit | yes, `edit/main` | no |
| anchored | the default version only, `edit/main` | `blob/<ref>`, text = the ref |
| line | the default version only: `edit/<docs>` when `docs` is `main` or `release/...`, else `edit/main` | `blob/<sha>` (always the SHA that was archived), text = the ref when `docs = tag` (then the SHA is the ref's commit), else the seven-hex SHA |

- The view link of a branch-sourced row uses the SHA, never `blob/main/...`, which moves.
- Edit goes where a fix to that tree lands: a core docs fix after GA goes to `release/v2.0`.

### 9. CI

- **Checkouts: no change.** `actions/checkout` v7.0.1 (`3d3c42e5`) with `fetch-depth: 0` fetches `+refs/heads/*:refs/remotes/origin/*` and `+refs/tags/*:refs/tags/*` (Research), so every tag and every future `release/*` branch is already in each root. A comment on the first source checkout says the resolver reads them. The resolver's own shallow and `origin/main` checks guard a later edit that shortens the fetch.
- **Summary step.** It lists every version's resolved refs from `build-stamp.json`, not `.sources`:

```yaml
      - name: Summary
        run: |
          {
            echo '### Site build'
            echo
            echo '| Version | Repository | Ref | Docs from | Commit | Rule |'
            echo '|---|---|---|---|---|---|'
            jq -r '.versions | to_entries[] | .key as $v | .value.refs | to_entries[]
              | "| \($v) | \(.key) | \(.value.ref) | \(.value.docs // "") | [\(.value.sha[0:12])](https://github.com/open-platform-model/\(.key)/commit/\(.value.sha)) | \(.value.how) |"' site/public/build-stamp.json
            echo
            echo "Files in site/public: $(find site/public -type f | wc -l)"
          } >> "$GITHUB_STEP_SUMMARY"
```

- **Artifacts.** `build-stamp` stays as it is: `site/public/build-stamp.json` alone, 90 days. A new `build-manifest` artifact uploads `site/.versions/frozen.conf` alone, also for 90 days.
  - It is a separate artifact because `actions/upload-artifact` roots a multi-path artifact at the paths' least common ancestor. Adding `frozen.conf` to `build-stamp` would move `build-stamp.json` from the artifact root to `public/build-stamp.json`.
  - It needs `include-hidden-files: true`, because `actions/upload-artifact` skips paths under a dot directory, and `.versions` is one.
- **Nightly.** The existing nightly run is now what publishes a newly tagged release or a release-branch docs fix: within about a day, or at once with `gh workflow run Site --ref main`. The cron comment and README "Source repositories" say so. `pages-deploy` is unchanged.
- **No cross-repository dispatch.** A `repository_dispatch` from each source repository's release workflow needs a credential that can write to opmodel.dev in five repositories. That is either a new PAT secret, which the brief rules out, or the `opm-release-please` App.
  - The App's credentials (`vars.RELEASE_APP_CLIENT_ID`, `secrets.RELEASE_APP_PRIVATE_KEY`) are already in all five release workflows, and the App has `contents: write`, which `repository_dispatch` needs.
  - It is installed on selected repositories. Whether opmodel.dev is one cannot be read without org admin (`GET user/installations` returns 403).
  - Adding it would extend the tag-creating identity's write access to opmodel.dev.
  - It would also edit five other repositories' release workflows, which Principle I makes follow-ups there.

  It is a follow-up, worth it only if the one-day lag is a problem.
- **The `browser` job resolves on its own.** A release landing between the `build` and `browser` checkouts can make them resolve different SHAs. What is deployed comes from `build` alone, so this is accepted; a shared resolve job is the fix if it is ever seen.

### 10. Reproducing a build: `frozen.conf`

Write mode also writes `.versions/frozen.conf`, and `--freeze` prints the same text without writing. It holds the floors, plus every version as an anchored version at its resolved refs, with every derived repository overridden, so nothing is re-derived:

```ini
; generated by resolve-versions.sh from site/versions.conf at opmodel.dev <40-hex HEAD>
; rebuild: check out opmodel.dev at that commit, copy this file outside site/.versions/,
; then run OPM_VERSIONS_MANIFEST=<the copy> task build
[repo "opm"]
	floor = 2a73f5282a2b487e209ed2d0717da46c8a17a5da
; ... the other five floors ...
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	cli = v1.0.0-beta.4
	catalog = 64a65a5a603fad338c1caeb4a5d66c411cae2607
	opm = 4e582b8e0d9ccbba320a639d34421cc744742ef0
	override = library v1.0.0-beta.1 frozen from line, docs tag
	override = core f5c446323caa3019fb0c8e449f8b28bf588a4de7 frozen from line v2.0.0-beta.1, docs main
	override = opm-operator v1.0.0-beta.2 frozen from line, docs tag
```

- **The seventh input.** The opmodel.dev commit supplies the layouts, the site-owned pages and their dates, the floors and the Hugo image (tagged by the Dockerfile hash). The header names it, and `build.json` records it as `site` (decision 8). The resolver reads it with `git -C <site> rev-parse HEAD`. CI builds from a clean checkout. A local build with uncommitted opmodel.dev edits is not reproducible from the record, and neither is a `source = main` version, which freezes at its roots' `HEAD` without their uncommitted edits.
- **Tags by name.** A row whose `docs` is `tag` freezes by its tag name, because tags are immutable. Every other row freezes by its SHA. The rebuild's footer and "View source" text then name the same tags. A core or catalog row read from a branch head shows its SHA instead of `v2.0.0-beta.1 (docs main f5c4463)`. The six trees are identical.
- **Never in place.** The resolver refuses `OPM_VERSIONS_MANIFEST` at `site/.versions/frozen.conf` itself (decision 6). The rebuild reads a copy.

### 11. Tests

All of them are in `tests/versions/test-resolve.sh`, under `.check/versions-test/repos/` only, with no network.

- **Fixture upstreams.** The six existing fixture repositories act as upstreams and gain, before any case runs:
  - cli: `v1.5.0-beta.2` and `v1.5.0-beta.10` (library `v2.3.0`, operator `v3.1.0`); a later `v1.5.0-beta.3` (library `v2.1.0`), lower by semver but newer by date; the decoy `v1.50.0`; and `v1.6.0` (library `v2.2.0-oldcore`, operator `v3.1.0`), after which the pins are restored;
  - library: `v2.2.0-oldcore` after the floor, pinning core `v4.2.0-rc.0`, after which the pin is restored;
  - core: `v4.2.0-rc.0` on the pre-floor commit; a docs commit after `v4.2.0`, so `main`'s head is not the tag;
  - catalog_opm: `opm-v0.9.0` on the pre-floor commit; a docs commit after `opm-v1.1.0`.
- **Line roots** are `git clone`s of the upstreams under `repos/line/<repo>`, so `refs/remotes/origin/*` and the tags exist exactly as in CI. Later states change an upstream, and `--fetch` moves the clones. Upstream branches are made with `git switch -c`, then `git switch main`. Every tag is created once and never moved: these are test data, but the immutability rule holds here too.
- **States**, in order, after every existing case:
  - A: as above.
  - B: core `release/v4.2` and catalog `release/opm-v1.1`, each with a docs commit.
  - C: cli `v1.5.0`, a final, pinning library `v2.1.0` (so core `v4.1.0`); core `v4.1.1` on a side branch `fix-v4.1` off `v4.1.0`, never merged into `main`; catalog `opm-v1.2.0` on `main` after a docs commit.
  - D: catalog `opm-v2.0.0` on `main`.
  - E: core `release/v4.1` from the floor commit, plus a docs commit.

Every line manifest uses `catalog-line = opm-v1` unless a case says otherwise.

| Case | Asserts |
|---|---|
| `line` (A) | cli `v1.5.0-beta.10` (beats beta.3 and beta.2, ignores `v1.50.0` and `v1.6.0`); library `v2.3.0`, operator `v3.1.0`, core `v4.2.0` from the pins; catalog `opm-v1.1.0` (ignores `opm-v0.9.0` and the unprefixed `v9.9.9`); core and catalog docs `main` at the upstream heads; opm `main`; kind `line`; every `how` |
| `line-override` (A) | 1. `cli-line = v1.2` (newest `v1.2.0-pseudo`, a pseudo-version library pin) with `override = library v2.3.0 …`: core follows it to `v4.2.0`, docs `main`; the library `how` is `override:…; replaces v2.1.1-0.20260930120000-0123456789ab (pin:cli go.mod)`. 2. The same line with `override = library v2.4.0-major …` (core pin: a major only) and `override = core <the v4.2.0 SHA> …`: core docs `sha`, no containment check. 3. `catalog-line = opm-v0` (newest `opm-v0.9.0`, older than its floor) with `override = catalog_opm opm-v1.1.0 …`: catalog docs `tag`. |
| `line-override-stale` (A) | the `line` manifest plus `override = opm-operator v3.1.0 …` and `override = opm <the opm floor SHA> …`: fails, naming both overrides as no longer needed |
| `line-core-pre-floor` (A) | `cli-line = v1.6`: core `v4.2.0-rc.0`, with docs `main` (post-floor), fails: the release the stamp names is older than its floor |
| `line-pre-floor` (A) | `cli-line = v1.0` (only `v1.0.0-old`) fails: older than its floor, naming the rule |
| `line-no-tag` (A) | `cli-line = v9.9` and `catalog-line = opm-v9` fail, naming the line and `task versions:fetch` |
| `line-grammar` (A) | each fails with its named error: `cli-line` with `cli`; `cli-line` with `source`; no `catalog-line`; `catalog-line` in an anchored version (no `cli-line`); `cli-line = 1.5`; `catalog-line = v1`; `catalog-line = opm-v4.4` (a minor); `catalog-line = k8s-v1` |
| `line-shallow` (A) | `OPM_SRC_OPM` is `git clone --depth 1 file://<upstream opm>` (a plain local-path clone ignores `--depth`): a named shallow-clone error |
| `line-no-origin` (A) | the upstream repositories (no remote) as roots: a named `refs/remotes/origin/main` error |
| `line-stale` (B, before `--fetch`) | the clones still resolve state A |
| `line-branch` (B, after `--fetch`) | core docs `release/v4.2` and catalog docs `release/opm-v1.1` at the branch heads; the versions are unchanged |
| `line-stamp` (B) | `gen-stamp.sh` run on the host with `SITE_DIR` at a scratch copy of the `--check` output writes every SHA, every `docs` value and `site` into `data/opm/build.json` |
| `line-freeze` (B) | `--freeze`, saved under `repos/manifests/`, then `--check` with that copy: the same six SHAs, kind `anchored`, cli, library and opm-operator by tag name, every override reason starting with `frozen`. And `OPM_VERSIONS_MANIFEST=<site>/.versions/frozen.conf` fails with the named "copy it first" error, by path, so the case writes nothing there. |
| `line-newer-tag` (C) | after `--fetch`: cli `v1.5.0`; core line `v4.1`, `main` past it (newest merged tag `v4.2.0`), no `release/v4.1`: core docs `tag` at `v4.1.0`, the pin, not the newer `v4.1.1`; catalog follows its major to `opm-v1.2.0` with docs `main` (no `release/opm-v1.2`; the older `release/opm-v1.1` is not read) |
| `line-catalog-major` (D) | after `--fetch`: catalog stays on `opm-v1.2.0`, the newest `opm-v1` tag (`opm-v2.0.0` is another major), with docs `tag` at it (rule 3: `main` is past `opm-v1.2`) |
| `line-contain` (E) | after `--fetch`, the run fails: core `release/v4.1` does not contain `v4.1.0` |
| `line-fetch-prune` (after E) | one clone holds a local-only tag, and one root is a linked worktree of its clone. `--fetch` runs with `fetch.prune` and `fetch.pruneTags` set to `true` through `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_n` and `GIT_CONFIG_VALUE_n`: exit 0, the tag survives, and no `FETCH_HEAD` appears in any clone's `.git/` or `.git/worktrees/*/` |
| `line-fetch-clobber` (after E) | the core clone holds a local tag `v4.9.0` at its head and has `+refs/tags/*:refs/tags/*` added to its fetch config; upstream core then creates `v4.9.0` on a new `main` commit. `--fetch` exits 1 naming the core root; the local `v4.9.0` is unchanged, and the clone's `refs/remotes/origin/main` still equals the upstream head |
| `real-line` | the caller's real roots, a manifest with `cli-line = v1.0` and `catalog-line = opm-v4`, `--check`: exit 0; the cli ref equals git's own order (`git -c versionsort.suffix=- tag -l --sort=-v:refname`, filtered by the line regex, first); library, core and opm-operator equal `--pins <that ref>`; the catalog ref equals git's order for `opm-v4.*`; every `docs` is `tag`, `main` or `release/...` |

- `two-versions.conf`: `v1.0` moves to `cli-line = v1.0` and `catalog-line = opm-v4`; `v0.9` stays anchored at the floors. Its header stops saying that no repository has a tag cut after its merge.
- `check-two-versions.sh` adds these assertions, reading every expected SHA and ref from `.versions/versions.tsv`, never a literal:
  - the v1.0 stamp links every v1.0 SHA;
  - the v1.0 "View source" links carry `blob/<sha>/docs/site/`;
  - v1.0 edit links follow decision 8.

  The "pages added after the test SHAs publish in v1.0 only" assertion and the `write-a-blueprint` check compare against v1.0's resolved SHA per repository instead of the root's `HEAD`, because v1.0 no longer reads `HEAD`.

### 12. Taskfile

- `versions:fetch`: `sh site/scripts/resolve-versions.sh --fetch`, with the `versions-env` map, so the roots resolve as for a build.
- `versions:prepare` and `versions:check` descriptions name line versions.
- The `serve` description stops saying it reads the sources in place: a line version serves archives, and live editing is `OPM_VERSIONS=v1.0=/src task serve`.
- No other task changes: `build` and `serve` still run `versions:prepare`, which stays offline.

### Interface: what this change adds

- `site/versions.conf` keys `cli-line` (a cli minor) and `catalog-line` (an opm catalog major).
- `kind` value `line`.
- `versions.tsv` column 10 `docs`, and the comment line `# site <opmodel.dev SHA>`.
- `build.json` keys `refs.<repo>.docs` and `site`.
- `resolve-versions.sh --fetch` and `--freeze`.
- Generated `site/.versions/frozen.conf`.
- `task versions:fetch`.
- The `build-manifest` CI artifact (`frozen.conf`, 90 days).

## Research & Decisions

### The owner reverses the fixed-anchor rule
**Context**: O3 bound the archived `version-site-from-tags`: moving `v1.0` onto tags "must be a manifest edit that pins a fixed anchor ref bumped by commit, never a moving line resolved at build time". The README, `AGENTS.md` and the manifest header repeat it.
**Explored**: The owner's request and four resolution rules (2026-10-01), and the versions machinery as it stands on `origin/main` 0f3a19c: the resolver, materialise.sh, gen-stamp.sh, build-all.sh, serve.sh and the three layouts (Context).
**Decision**: Line versions move on every build, the nightly one included. Reproducibility moves from the manifest to the record: `versions.tsv`, `build-stamp.json`, the footer, the CI summary, `frozen.conf` and the opmodel.dev commit. Anchored versions, the bump-by-commit kind, stay for older versions and tests.
**Rationale**: It is the owner's decision. Tags are immutable now, so the only moving inputs are a new tag in a line and the heads of `main` and `release/*`, and both are recorded per build.

### Catalog line: a major, not a minor
**Context**: The owner named `opm-v4.4`. The opm package releases finals and cut four minors on 2026-09-14 and 15 (Context).
**Explored**: A minor line: on the first `opm-v4.5.0`, rule 2 stops applying and rule 3 documents `opm-v4.4.4` indefinitely with exit 0, contradicting owner rule 2 and the request that the CD job collect the newest release by itself. A minor line with a named "bump catalog-line" error instead: correct, but it turns every opmodel.dev run red on each catalog minor. Deriving the catalog from the cli: the cli names only the major (`DefaultCatalogPaths`), and three template files name a minimum each.
**Decision**: `catalog-line` names the major (`opm-v4`). The ref is its newest tag. The docs rules use that tag's minor.
**Rationale**: It matches what a cli `v1.0` user consumes, needs no manifest commit per catalog minor, and keeps rules 1-3 unchanged. The owner confirms the reading of rule 3 before launch (Open Questions).

### Overrides in a line version
**Context**: An override is a fixed ref inside a moving version. The escape hatch for a red resolution is an override (Risks).
**Explored**: Unchanged override semantics: an override written for cli `beta.5` keeps replacing the pins of every later tag until someone remembers it. Requiring the reason to name its cli tag: it fails at every new cli release, needed or not. Resolving and checking the replaced row: it fails exactly when the override stops being needed.
**Decision**: The third (decision 1). `how` records the replaced row, and the run fails with a named error once that row passes every check.
**Rationale**: It keeps owner rule 1 (exactly what the cli pins) as the steady state, and the error names the one-line fix.

### Git-config key names
**Context**: The first draft proposed `catalog_line`.
**Explored**: `git config --file` (git 2.55.0) on `catalog_line = opm-v4.4` fails with "fatal: bad config line 2". `cli-line` and `catalog-line` list as `version.v1.0.cli-line` and `version.v1.0.catalog-line`.
**Decision**: `cli-line`, `catalog-line`.
**Rationale**: Git allows only letters, digits and `-` in variable names, and the manifest is parsed by `git config`.

### Semver ordering
**Context**: The newest cli tag decides the whole version.
**Explored**: A scratch repository with the tags `v1.0.0-beta.2`, `-beta.10`, `-rc.1`, `v1.0.0`, `v1.0.1-beta.1`, `v1.0.9` and `v1.0.10`. `sort -V` ascending gives `v1.0.0` first, below its own prereleases, and `git tag --sort=-v:refname` has the same defect. `git -c versionsort.suffix=- tag --sort=-v:refname` gives `v1.0.10 v1.0.9 v1.0.1-beta.1 v1.0.0 v1.0.0-rc.1 v1.0.0-beta.10 v1.0.0-beta.2`: correct, while every prerelease uses `-`. On 2026-10-01 an awk comparator and git's suffix order agree on every real line: cli `v1.0.0-beta.4`, library `v1.0.0-beta.1`, opm-operator `v1.0.0-beta.3`, core `v2.0.0-beta.1`, catalog `opm-v4.4.4` (in both the `opm-v4.4` minor and the `opm-v4` major) and `k8s-v1.0.0-beta.1`.
**Decision**: An awk semver comparator over a regex-filtered tag list, with git's suffix order as the oracle in the real-repository test.
**Rationale**: It is POSIX and host-portable, it implements §11 exactly, and the fixtures can test it. The catalog's unprefixed legacy tags make the regex filter mandatory.

### CI already carries tags and branches
**Context**: The resolver reads `refs/remotes/origin/release/*` and tags.
**Explored**: `actions/checkout` at the pinned `3d3c42e5aac5ba805825da76410c181273ba90b1`: `getRefSpecForAllHistory` returns `+refs/heads/*:refs/remotes/origin/*` and the tags refspec whenever `fetchDepth <= 0` (`src/ref-helper.ts`, `src/git-source-provider.ts`).
**Decision**: No checkout change; a comment, plus the resolver's shallow and `origin/main` checks.
**Rationale**: Every `release/*` branch and tag reaches the job with no new step or permission.

### Detecting a release branch
**Context**: A typo, a stale ref or a lazily cut branch could silently send the docs to the wrong tree.
**Explored**: An earlier draft proposed "fail when any `release/*` exists but the derived one is missing". The local catalog_opm clone holds `refs/remotes/origin/release/opm-stable`, deleted upstream, so that rule would fail locally on a stale ref. Branches are cut lazily (workspace `AGENTS.md`), so a missing branch is normal even after GA.
**Decision**: Look up only the exact derived name. Add rule 3 (decision 2) for a line `main` has left. Require the named release to be an ancestor of the docs SHA.
**Rationale**: The branch name is derived, never typed: from the cli pin for core and from `catalog-line` for the catalog. Rule 3 and the containment check cover what failing on absence was meant to catch.

### What "main's head" means
**Context**: `source = main` reads each root's checked-out `HEAD`; in a `site-src` worktree that is a detached, possibly old `origin/main`.
**Explored**: In CI each source checkout is `ref: main` with full history, so `HEAD` and `origin/main` are equal. A linked worktree shares its repository's tags and remote-tracking refs (task 1.4 confirms it on the `site-src` worktrees).
**Decision**: Line mode reads `refs/remotes/origin/main` and archives it by SHA. `source = main` keeps `HEAD` and the working tree, for live editing.
**Rationale**: It gives the same answer in CI, in the main checkout and in every worktree, and it never picks up uncommitted edits.

### Fetch policy
**Context**: Local clones are not kept current; a new beta tag is invisible until fetched.
**Explored**: Fetching inside `versions:prepare` (network on every build, fails offline), `ls-remote` checks (network), and an opt-in fetch. Then the opt-in fetch's flags, in scratch repositories with git 2.55.0:
- `git fetch --tags origin` with `-c fetch.prune=true -c fetch.pruneTags=true` printed `- [deleted] (none) -> v0.0.0-localonly` and removed a local-only tag.
- With `+refs/tags/*:refs/tags/*` in `remote.origin.fetch`, `git fetch --tags origin` force-updated a local tag (`t [tag update]`).
- The decision 4 command, with both prune keys and that refspec configured: the local-only tag kept, a conflicting tag refused (`! [rejected] v2.0.0 -> v2.0.0 (would clobber existing tag)`, exit 1), the local tag unchanged, and `origin/main`, the new branch and the other new tag all updated.
- From a linked worktree, `git fetch --tags origin` created `.git/worktrees/<name>/FETCH_HEAD`; the decision 4 command created no file under `.git/worktrees/<name>/` and no `.git/FETCH_HEAD`.
- `git clone --depth 1 <path>` prints "--depth is ignored in local clones; use file:// instead" and is not shallow; `file://<path>` is.

**Decision**: The resolver reads local refs only. `--fetch` (`task versions:fetch`) runs the decision 4 command. CI fetches through its checkouts.
**Rationale**: Builds stay offline and repeatable. The fetch cannot move or delete a tag whatever the user's git config, writes nothing in a worktree, and a refused tag update surfaces any tag tampering.

### Row shape
**Context**: core and catalog_opm need a version and a docs commit per row.
**Explored**: Two rows per repository (breaks every `(version, repo)` reader), `how`-only (layouts parsing free text), and a new column.
**Decision**: Append a `docs` column; keep `ref` as the release the stamp names and `sha` as the tree built.
**Rationale**: It is the smallest change every reader tolerates, and it gives the layouts a field to switch on.

### Cross-repository dispatch
**Context**: A new release could reach the site at once instead of within about a day.
**Explored**: `gh api` GETs and the five source `release.yml` files. All five mint `opm-release-please` App tokens from `vars.RELEASE_APP_CLIENT_ID` and `secrets.RELEASE_APP_PRIVATE_KEY`. The App has `contents: write`, `issues: write` and `pull_requests: write`, with `repository_selection: selected`. Its repository list and the org secrets need org admin (403), and requesting `admin:org` is forbidden.
**Decision**: No dispatch in this change; the nightly run remains the mechanism.
**Rationale**: The decision 9 reasons. Dispatch is a follow-up to propose only if the lag matters.

### Draft releases
**Context**: cli and opm-operator release draft-first, and release-please creates the tag (`force-tag-creation`) before the workflow publishes the draft.
**Decision**: The resolver reads tags only. A nightly run may document a tag whose release is still a draft.
**Rationale**: The tag is immutable either way, and the docs do not depend on the assets. Checking release state would need the network and a token in the host step.

## Risks / Trade-offs

- [A published build changes with no commit in this repository] -> That is the owner's intent. Every build records every SHA (stamp, footer, summary) and the opmodel.dev commit, and `frozen.conf` in the 90-day `build-manifest` artifact rebuilds the same trees at that commit. `public/build-stamp.json` on the live site always names what is served.
- [Moving lines make opmodel.dev's own CI depend on upstream releases] -> A new upstream tag that fails resolution turns every run red: pushes, unrelated pull requests and `real-line`, not only the nightly. resolve-versions.sh fails the whole manifest, never one version, and the deployed site stays at the last good deploy. README "Site versions" gives the recovery for each failure kind:
  - library, core, opm-operator or catalog_opm (a bad pin, a pre-floor release, a failed containment check on a branch): an override in the manifest, which fails again, as no longer needed, once the line passes;
  - cli (its newest tag has no `docs/site` or is older than its floor; cli cannot be overridden): move the version back to `anchored` at the last good refs, the version block of the last `build-manifest` artifact's `frozen.conf`, and back to line mode after the fix.

  Letting `real-line` report instead of fail would not keep CI green: the build's own `versions:prepare` fails on the same input.
- [core docs at `main` can describe schema newer than the pinned `v2.0.0-beta.1`; `main` is three commits past it today: `docs(policy)` #86, `ci(release)` #87, `docs(spec)` #88] -> That is the owner's decision 2. The footer shows both facts (`core v2.0.0-beta.1 (docs main f5c4463)`). Rule 3 stops it once `main` tags the next minor, but not in the window after GA where `main` holds unreleased `X.(Y+1)` work and has no new tag yet. Cutting `release/vX.Y` at that point, as the version-line rule intends, moves the docs to rule 1.
- [A local build resolves stale tags or branches] -> `task versions:fetch` first. The stamp and `task versions:check` show what was resolved; CI clones fresh.
- [A new kind mis-routes in a reader nobody updated] -> materialise.sh switches to `!= main`. The two-version build asserts that v1.0's archive equals `git ls-tree` at the resolved SHAs, and that every footer and view link carries them.
- [`build` and `browser` resolve different SHAs when a release lands mid-run] -> What deploys comes from `build` alone; accepted (decision 9).
- [Rule 3 documents a line from the release the stamp names while an unreleased fix sits on `main`] -> Fixes for a released minor go to its release branch, which, once cut, wins through rule 1. Open Questions asks the owner to confirm.
- [A new cli tag pins a pseudo-version, a `replace`, or a pre-floor release] -> The run fails red with the named error, and the site keeps the previous deploy. An `override = <repo> <ref> <reason>` in the manifest is the escape hatch. It fails, as no longer needed, at the first cli release whose pin passes, so it cannot silently outlive the release it was written for.
- [The catalog major follows a new minor with no review] -> That is the point of a major line (decision 1). Every catalog release still goes through the floor, `docs/site` and containment checks, and the stamp names it.
- [`deploy-site` edits the same lines] -> The two changes conflict textually, not just in nearby hunks:
  - README "Summary and artifacts" is one line, rewritten here and trimmed there;
  - the `build-stamp.json` curl comment in "GitHub Pages (interim)" is edited here, and the whole subsection is deleted there;
  - in `site.yml`, the `build-stamp` upload step this change follows with `build-manifest` directly abuts the Pages steps deploy-site removes.

  Whichever merges second merges `origin/main`, resolves the conflicts (if deploy-site merged first, this change drops its Pages edits), and re-runs the section-3 gates (tasks 1.1 and 3.9).

## Durable decisions

- A version is `source = main` (live working trees: tests and local work), `anchored` (fixed refs, bumped by commit) or `line` (`cli-line`, `catalog-line`: resolved on every build). The published manifest uses line versions. The owner reversed the earlier "never a moving line" rule on 2026-10-01. -> `AGENTS.md` "Site versions", README "Site versions", and the `site/versions.conf` header.
- The resolution rules per repository: the newest cli tag in its line by semver precedence, prereleases included; library, operator and core from that tag's pins; the catalog from the newest tag of its major (`catalog-line = opm-v4`); core and catalog docs from `release/<prefix>vX.Y` (`X.Y` the minor of the release the stamp names), else `main` while `main` releases that minor, else the named release's own tag; opm from `main`. A new catalog major or a new cli line is a manifest commit; a new catalog minor is not. -> `AGENTS.md` "Site versions" and README "Site versions".
- In a line version an override only replaces a row that fails, and the run fails once that row passes. -> `AGENTS.md` "Site versions" and README "Site versions".
- The resolver reads tags and `refs/remotes/origin/*` only, never local branches or `HEAD`, and assumes `origin` is the upstream repository. It never fetches. `task versions:fetch` does, with explicit refspecs (the tag one without `+`), `--no-prune --no-prune-tags` and `--no-write-fetch-head`, so it never moves or deletes a tag and writes nothing in a worktree. -> `AGENTS.md` "Site versions" and README "Site versions".
- Every build records every repository's ref, SHA, docs source and rule in `versions.tsv`, `build-stamp.json`, the footer and the CI summary, plus the opmodel.dev commit (`site`). `frozen.conf` (the `build-manifest` artifact) rebuilds the same trees: check out opmodel.dev at that commit, copy the file outside `site/.versions/`, and run `OPM_VERSIONS_MANIFEST=<the copy> task build`. -> README "Site versions" and "CI".
- Floors (at the tree and, for core and catalog_opm, at the release the stamp names), `docs/site` at the SHA and the containment of the named release fail the resolve with the version, the repository, the ref and the rule. -> `AGENTS.md` "Site versions".
- A red resolution is recovered by an override (library, core, opm-operator, catalog_opm) or by moving the version back to `anchored` at the last `frozen.conf` (cli). -> README "Site versions".
- Local live editing of source pages is `OPM_VERSIONS=v1.0=/src task serve`, because a line version serves archives. -> README "Site versions" and `AGENTS.md` "Build And Dev Commands".
- The nightly run is how a new release reaches the site. There is no cross-repository dispatch, and `gh workflow run Site --ref main` publishes at once. -> README "CI" ("Source repositories").
- Never sort release tags with `sort -V` or plain `--sort=-v:refname`. -> A comment at `semver_max` in `resolve-versions.sh`; stays with the change.
- 0021:OQ15 stays open. -> Already in `openspec/config.yaml` "Site Versions"; stays with the change.

## Open Questions

- **Answered by the owner (2026-10-01), binding:**
  - The catalog line is a major: `catalog-line = opm-v4` ("Follow the major"). v1.0 follows `opm-v4.5.0` and later minors by itself.
  - Rule 3 stands: when `main` has moved past a released line and no release branch was cut, the docs come from the newest tag of the line ("Newest tag of the line"); the build does not fail.
  - Library and opm-operator docs stay strictly on the cli pin (the owner chose "Follow the CLI").
  - The k8s catalog pages follow the opm tree (the owner chose the opm line); `release/k8s-v*` is ignored.
  - The proposal's Impact stands in for this change's missing row in orchestration.md section 2, and that brief's section 11 items 28 and 36 are superseded by this design (supervisor ruling).
- (Resolved, kept for history) **Owner, before launch (blocking):** the catalog line is a major (`catalog-line = opm-v4`, decision 1). This reads owner rule 3's `opm-v4.4` as today's minor of the `v4` line, so `v1.0` follows `opm-v4.5.0` and later minors by itself. If the owner wants a minor line instead, the grammar takes `opm-vX.Y`. The resolver then fails with a named error ("main has released <tag>, past catalog-line opm-vX.Y; bump catalog-line") whenever `main`'s newest opm tag is past the line, instead of falling to rule 3. `line-newer-tag` would assert that error. Either way the grammar is settled before section 2 starts.
- **Owner:** rule 3 (decision 2). Once `main` is past a line and no release branch was cut, the docs come from the release the stamp names (its tag). The alternative is to fail and require cutting the branch. Either answer changes one branch of `docs_source` and one fixture case, not the plan.
- **Owner:** library and opm-operator docs. Today they come strictly from the pinned tag (owner rule 1). The alternative is the newest tag in the pinned version's minor, with the version still from the pin, as core's docs already are. The difference shows today: cli `v1.0.0-beta.4` pins operator `v1.0.0-beta.2`, while the operator's newest tag is `v1.0.0-beta.3` (its `main`). On the pin, a library or operator docs fix, which cuts a release there, reaches the site only when a later cli release bumps the pin, and nothing triggers that. README "Site versions" says so.
- **Owner:** the k8s catalog pages follow the opm line's tree, and `release/k8s-v*` is never read (Non-Goals). After GA, a k8s docs fix on `release/k8s-v1.0` would not reach the site, and while the opm docs come from `release/opm-v4.Y`, the k8s pages come from that branch too. A separate k8s docs line needs its own key and a split of catalog_opm's `docs/site`.
- **Owner or supervisor:** the workspace `AGENTS.md` says "opmodel.dev pins the commit SHA of the fix on the release branch". Under this change it builds from the branch head and records the SHA per build. The rewording is outside this repo.
- **Supervisor:** the copied `orchestration.md` has no section 2 row for this change, and its section 11 items 28 and 36 predate the beta tags. Confirm that the proposal's Impact stands in for the row, and that items 28 and 36 are superseded, before launch.
- **Follow-up (not this change):** after GA, "Edit this page" for cli, library and opm-operator pages of an older line should target `release/v1.0`. A cross-repository dispatch, if the one-day lag matters (decision 9).
