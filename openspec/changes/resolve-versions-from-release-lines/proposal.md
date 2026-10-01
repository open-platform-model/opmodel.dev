## Why

Every repository the site reads now releases beta tags, and every tag is immutable (workspace `AGENTS.md`, "Release Tags Are Immutable"). That rule also plans release branches, `release/<tag-prefix>vX.Y`, for fixing the docs or code of a released minor. None exists during beta. The site still builds `v1.0` from every repository's `main` (`source = main`), a mode the manifest allows "only until `v1.0.0-beta.N` tags exist". That point has passed.

The owner asked on 2026-10-01 for the site's CD job to collect the newest release of each line by itself. The owner also set the rules for how a site version resolves. This **reverses** the owner's earlier rule, O3 in the archived `version-site-from-tags`: "a fixed anchor ref bumped by commit, never a moving line resolved at build time". A line version now moves on every build, the nightly run included. So every build must record the SHA it resolved for every repository, or a published build could not be reproduced.

## What Changes

- **A third kind of site version, `line`,** in `site/versions.conf`. Its keys are `cli-line = vX.Y` (a cli minor) and `catalog-line = opm-vN` (an opm catalog major). Git-config key names cannot hold `_`, so the names use `-`. They exclude `source`, `cli`, `catalog` and `opm`, and an anchored version refuses `catalog-line`. A line version resolves each repository by these rules (design.md decision 2):
  - **cli**: the newest tag in the line by semver precedence, prereleases included (for `v1.0`, the newest `v1.0.<patch>[-<pre>]` tag).
  - **library, opm-operator and core**: exactly what that cli tag pins, read as today: library from `cli/go.mod`, the operator from `PinnedOperatorVersion`, and core from library's `DefaultSchemaModule` at the pinned library tag.
  - **catalog_opm**: the newest tag of the major (for `opm-v4`, the newest `opm-v4.<minor>.<patch>[-<pre>]`). The cli consumes the catalog by major, so a new catalog minor needs no manifest commit. This reads the owner's `opm-v4.4` as today's minor of the `v4` line; the owner confirms it before launch (design.md, Open Questions).
  - **core and catalog_opm docs**, where `X.Y` is the minor of the release the stamp names: the head of `release/<prefix>vX.Y` when that branch exists. Without the branch, the head of `main` while `main` still releases `X.Y`. After `main` has moved past `X.Y` and no branch was cut, the named release's own tag, so the footer's ref is always the tree. Their versions in the stamp still come from the cli pin (core) and the catalog line (catalog_opm).
  - **opm**: the head of `main` at build time.
  - **Overrides.** `override = <repo> <ref> <reason>` works for every repository except cli. In a line version it only replaces a row that fails. The run fails with a named error once the replaced row passes again, so an override cannot outlive the cli release it was written for.
- **Refs are read on the host, never written.** The resolver reads tags and the remote-tracking refs `refs/remotes/origin/{main,release/*}` from the source roots, never a local branch or `HEAD`. It refuses a shallow root or a root without `origin/main`, with a named error, and assumes `origin` is the upstream repository. It never fetches by itself. The new `task versions:fetch` runs `git fetch` with explicit refspecs (`+refs/heads/*:refs/remotes/origin/*` and `refs/tags/*:refs/tags/*`, the tag one without `+`), `--no-prune --no-prune-tags --no-tags` and `--no-write-fetch-head`. No user git config can then make it move or delete a local tag, and it writes nothing in a worktree. In CI the `fetch-depth: 0` checkouts already carry every tag and branch.
- **Every SHA is recorded.**
  - `versions.tsv` gains a `docs` column, the ref the archived tree came from (`tag`, `main`, `release/...`, `sha`, `worktree`), the kind `line`, and a `# site <sha>` comment line: the opmodel.dev commit, the seventh input.
  - `build-stamp.json` gains `refs.<repo>.docs` and `site`.
  - The footer names every ref and its commit.
  - The resolver also writes `site/.versions/frozen.conf`: the same build as an anchored manifest, with tag-sourced rows by their immutable tag names and every other row by SHA, headed by the opmodel.dev commit. CI uploads it as its own `build-manifest` artifact. Checking out opmodel.dev at that commit and running `OPM_VERSIONS_MANIFEST=<a copy> task build` rebuilds the same trees. The resolver refuses `site/.versions/frozen.conf` itself as the manifest.
- **Floors still hold**, and fail loudly with the version, the repository, the ref and the rule that chose it. For core and catalog_opm the floor also holds at the release the stamp names, and a new check makes their docs SHA contain that release.
- **The day-one manifest moves `v1.0` (beta) onto line mode** (`cli-line = v1.0`, `catalog-line = opm-v4`). The `source = main` and explicit (`OPM_VERSIONS`) modes stay, for tests and for local live editing.
- **Layouts.**
  - The footer stamp, "View source" and "Edit this page" understand `line`.
  - "View source" goes to the archived SHA.
  - "Edit" goes to the branch the docs came from (`main` or `release/...`), else `main`.
- **materialise.sh** archives every version that is not `source = main`. Today it archives only `anchored`, so a new kind would silently build from working trees.
- **CI.**
  - The build summary lists every version's resolved refs and SHAs instead of the checkout heads.
  - A new `build-manifest` artifact carries `frozen.conf`; the `build-stamp` artifact keeps its layout.
  - Comments say that the nightly run is what publishes a newly tagged release.
  - There is no cross-repository dispatch (design.md decision 9).
- **Tests.** Fixture repositories gain:
  - beta tags in one line;
  - a final release beating its prereleases;
  - a newer tag arriving by `--fetch`;
  - release branches for core and catalog_opm;
  - `main` moving past a line (core), and a catalog major following a new minor and stopping at a new major;
  - a pre-floor newest tag, and a pre-floor core pin whose docs come from `main` (both refused);
  - a cli tag pinning library, operator and core;
  - overrides in line mode, valid and stale;
  - `--fetch` under prune config and against a conflicting upstream tag.

  The tests assert the resolution table, the stamp's SHAs and the `frozen.conf` round trip. A real-repository case checks the semver order against git's own (`versionsort.suffix=-`). The two-version build moves its `v1.0` onto line mode.
- **Docs.** README "Site versions" and "CI", and `AGENTS.md` "Site versions", state the line rules and the recovery from a red resolution, and say that the owner reversed the fixed-anchor rule on 2026-10-01. Every sentence that says the site reads the sources in place, or builds from each checkout, is corrected.

**Complexity (Principle V).**
- The `docs` column is needed because core and catalog_opm now have two facts per row: the version the stamp names, and the commit whose docs are built.
- `frozen.conf` is how "reproducible" gets a check (the round-trip test) instead of a sentence.
- The fallback "the named release's tag once `main` is past its minor" is needed because release branches are cut lazily: without it, a line that never needed a fix would document `main`'s next minor.
- The replaced-row check on overrides is needed because a fixed ref inside a moving version would otherwise outlive its reason.

## Before / After

**Before** (`site/versions.conf`, today)

```ini
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	source = main
```

**After**

```ini
; A line version follows its release lines on every build, the nightly one included (the owner
; reversed the fixed-anchor rule on 2026-10-01); every build records the SHA of every repository.
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	cli-line = v1.0
	catalog-line = opm-v4
```

```text
site/
  versions.conf                     v1.0 -> line mode (above); header comment rewritten
  scripts/resolve-versions.sh       + line mode, semver_max, docs_source, override check, --fetch, --freeze; 10th column "docs"; "# site" line
  scripts/materialise.sh            archives every kind but main (was: anchored only)
  scripts/gen-stamp.sh              refs.<repo>.docs, site
  layouts/_partials/opm/build-stamp.html, opm/source.html, components/last-updated.html   kind line
  tests/versions/test-resolve.sh    + line cases (fixture clones with origin), real-line case
  tests/versions/two-versions.conf  v1.0 -> line mode; v0.9 stays anchored
  tests/versions/check-two-versions.sh  + v1.0 line assertions
  .versions/versions.tsv   (generated) "# version label weight default kind repo ref sha how docs", "# site <sha>"
  .versions/frozen.conf    (generated) NEW: the build as an anchored manifest at the resolved refs
Taskfile.yml                        + versions:fetch; serve description
.github/workflows/site.yml          summary lists resolved refs; build-manifest artifact (frozen.conf); comments
```

What `v1.0` resolves to, snapshot of 2026-10-01 18:30 CEST after a fetch (no `release/*` branch exists in any repository). Tags do not move; the three `main` heads will, and a newer head or tag is not a deviation (task 1.2):

```text
repo          ref             docs   sha (docs tree)                            rule
cli           v1.0.0-beta.4   tag    0e66ec08a7d262695994761dd39f1c526c09c86a   newest v1.0 tag
library       v1.0.0-beta.1   tag    02344e5913458e4411a19668f0f4424b8141d2f4   cli go.mod
opm-operator  v1.0.0-beta.2   tag    27d9dfc3c03777f218d69b3bbac435cc06b52af5   cli PinnedOperatorVersion
core          v2.0.0-beta.1   main   f5c446323caa3019fb0c8e449f8b28bf588a4de7   library DefaultSchemaModule; docs at main (no release/v2.0)
catalog_opm   opm-v4.4.4      main   64a65a5a603fad338c1caeb4a5d66c411cae2607   newest opm-v4 tag; docs at main (no release/opm-v4.4)
opm           main            main   4e582b8e0d9ccbba320a639d34421cc744742ef0   main head
```

Every row passes its floor, holds `docs/site` and, for core and catalog_opm, contains the release the stamp names (`v2.0.0-beta.1` 4f9b245, `opm-v4.4.4` 793e3be), which also passes its floor.

## Impact

- **Build inputs.**
  - The build gains the git archives of all six repositories for `v1.0`, under `site/.versions/v1.0/`, instead of reading the working trees.
  - The host resolver gains the source roots' tags and `refs/remotes/origin/*` as inputs.
  - It needs full clones. CI already has them (`fetch-depth: 0`); locally, run `task versions:fetch` first.
  - No new mount, tool, image or vendored file.
- **opmodel.dev's own CI follows upstream releases.** A new upstream tag that fails resolution turns every run red (pushes, pull requests, the nightly) until it is recovered. Recovery is an override, or for cli a move back to `anchored` at the last `frozen.conf` (design.md, Risks). The deployed site stays at the last good deploy.
- **Source repositories.** None has to change its `docs/site`. Consequences the owner should know:
  - After GA, a docs fix in cli, library or opm-operator reaches the site only through a release, and for library and the operator only through a cli release that pins it. Their `docs` commits do cut releases. Whether library and operator docs should instead follow the newest tag of the pinned minor is an owner question (design.md, Open Questions).
  - A docs fix in core or catalog_opm reaches the site from its release branch head at the next build.
  - The k8s catalog pages follow the opm line's tree; `release/k8s-v*` is never read.
- **Follow-up outside this repo.** The workspace `AGENTS.md` sentence "opmodel.dev pins the commit SHA of the fix on the release branch" should read "opmodel.dev builds from the release branch head and records its SHA in every build". That is the owner's or the supervisor's edit, not one made here.
- **Published URLs and versions.** No URL changes and the version set stays `v1.0`.
  - Pages come from release tags and branch heads instead of `main`. On 2026-10-01 `docs/site` is the same tree at every pinned tag and at `main` in all five tagged repositories, so no page changes.
  - The footer names the refs, and every page gains "View source at <ref>".
  - After the merge, the next run of `main` (push or nightly) republishes the interim Pages site from the resolved refs.
  - Documentation versioning stays 0021:OQ15, an open question this change does not settle: it shows the core that the cli pins, as before.
- **Shared files with `deploy-site`.** Both changes edit `.github/workflows/site.yml` and the README "CI" section, and they conflict on the same lines: README "Summary and artifacts", the `build-stamp.json` curl comment in "GitHub Pages (interim)", and the adjacent `build-stamp` and Pages steps in `site.yml` (design.md, Risks). Whichever merges second merges `origin/main` into its branch (orchestration.md section 7, step 7), resolves the conflicts, and re-runs the section-3 gates.
- **orchestration.md** is copied verbatim and predates this change, so a worker meets three conflicts:
  - It has no row for this change in section 2. This Impact section stands in for that row.
  - Section 11 item 28 ("No repo has a `v1.0.0-beta*` tag yet") is out of date: design.md Context lists the beta tags of 2026-10-01.
  - Section 11 item 36 ("No tag that exists today can be built") is out of date too: every pinned beta tag passes its floor.

  The supervisor confirms both before launch (design.md, Open Questions).
- **Row.**
  - Branch: `feat/resolve-versions-from-release-lines`.
  - Kind: OpenSpec `docs-site-change`.
  - Gates: `task check`; `OPM_SRC_WORKTREE=site-src task ci`, which includes `versions:test`; `task qa` (the footer changes); `task ci:lint` (the workflow changes).
- **Depends on.**
  - Starts when: `origin/main` as of 2026-10-01 (`0f3a19c`), with the six `site-src` worktrees refreshed to `origin/main` and the six source repositories fetched.
  - Merges when: verify is green and the Site workflow is green on the PR.
  - Merge owner: the supervisor. The change only changes which refs the site reads; it touches no deploy infrastructure.
  - After the merge, the Pages site republishes from the resolved tags on the next push or nightly run, and the supervisor checks `/build-stamp.json` by curl.
- **Touches.**
  - `site/versions.conf`.
  - `site/scripts/{resolve-versions,materialise,gen-stamp}.sh`, plus comment-only edits in `site/scripts/{build-all,serve,gen-mounts}.sh`.
  - `site/layouts/_partials/opm/{build-stamp,source}.html` and `site/layouts/_partials/components/last-updated.html`. The last is our own override copy, so `overrides.sha256` is unchanged.
  - `site/tests/versions/*`.
  - `Taskfile.yml` (`versions:fetch`, task descriptions), `.github/workflows/site.yml`, `README.md`, `AGENTS.md`.
  - This change directory.

## Enhancement

None. No `enhancement.yaml` (orchestration.md section 1). 0021:OQ15 (how documentation is versioned against component releases) stays open; this change follows the owner's resolution rules for the site's own build and claims no decision.
