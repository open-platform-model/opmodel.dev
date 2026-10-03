# opmodel.dev

Documentation site for the Open Platform Model, built with [Hugo](https://gohugo.io/) and the [Hextra](https://github.com/imfing/hextra) theme (v0.13.0, neutral skin).

## Overview

This repository contains:

- **`site/`** - the Hugo site: configuration, the site-owned pages (the landing and the section overviews), layouts and theme overrides, styles, the vendored theme, build scripts, the build image and the tests.

Most pages do not live here. Each of six repositories (opm, core, catalog_opm, cli, library, opm-operator) keeps its pages in `docs/site/`, and the build assembles them. Reference pages generated from source (the CLI's commands, the operator's resources, core's definitions) are generated and committed in the repository that owns the source; the site builds them like any other page. The catalog's members are not committed: catalog_opm publishes them as signed docs bundles, one per release and one for `main`, which the site pulls and builds as the unversioned Catalogs tab at `/catalogs/` (see "The Catalogs section" under Site versions). The enhancements repository, OPM's design record, is built in the same run as one unversioned section at `/enhancements/` (see "The Enhancements section" under Site versions).

## Architecture

```text
<repo>/docs/site/**/*.md  (six source repos, archived at the resolved refs into site/.versions/<v>/)
site/content/             (landing and section overviews)
site/.bundles/            (signed docs bundles, task bundles:pull from ghcr.io/open-platform-model/docs)
        |
        v
  drift guard -> source lint -> git dates, mounts, page-set checks
        -> hugo build (Hextra, vendored) -> output checks -> Pagefind per version and catalog minor
        |
        v
  site/public/   /v1.0/...   /latest/ -> /v1.0/   / -> /latest/   /enhancements/...
                 /catalogs/opm/<MAJOR.MINOR>/...   /catalogs/opm/edge/...   /catalogs/opm/<MAJOR>/ -> newest minor
```

Everything runs in Docker. The build image (`site/Dockerfile`) holds Hugo 0.167.0, Pagefind 1.5.2, opm-docs 0.6.0 (docs-kit), git and jq, each pinned; a build runs with no network, and only `task bundles:pull` runs `opm-docs` with it. The QA image (`site/tests/browser/Dockerfile`) holds Chromium, Playwright and axe-core for the screenshots and the smoke tests. Image tags come from the Dockerfile hashes (`opmodel-dev-hugo:<12 hex>`, `opmodel-dev-qa:<12 hex>`).

There is one version, `v1.0` (beta), built from its release lines: the newest cli `v1.0` tag and exactly what it pins, the newest `opm-v4` catalog tag and opm's `main`, resolved again on every build (see Site versions). Every version lives under `/<version>/`; `/latest/` points at the default version and `/` at `/latest/`. How versions map to component releases is an open question (enhancement 0021:OQ15).

## Prerequisites

- Docker
- [Task](https://taskfile.dev/)
- git
- The OpenSpec CLI, for `task check`
- The six source repositories and enhancements checked out next to this one (the default), or pointed at with the variables below

## Quick Start

```bash
# Dev server with live reload on http://127.0.0.1:1313/, editing the source pages live
# (explicit mode: every docs/site/ read from its root; plain task serve serves the
# resolved versions' archives)
OPM_VERSIONS=v1.0=/src task serve

# Full build with every check into site/public/, then serve it; the first time, pull
# the Catalogs tab's docs bundles; after a new release, fetch the roots' tags and
# branches and pull the bundles again first (task versions:fetch build)
task bundles:pull
task build
task preview
```

The first run builds the image, which needs the network. The build finds the source repositories (the roots) in the workspace root, the parent directory of this checkout. To take them from elsewhere:

```bash
OPM_WS=/path/to/workspace task build                  # another workspace root
OPM_SRC_WORKTREE=site-src task build                  # <repo>/.claude/worktrees/site-src in each repo
OPM_SRC_CLI=/path/to/cli task build                   # one repo from elsewhere (OPM_SRC_<REPO>)
OPM_SRC_ENHANCEMENTS=/path/to/enhancements task build # the enhancements repository (OPM_SRC_WORKTREE does not apply)
SITE_PORT=1314 task serve                             # another port for serve and preview
```

For an anchored or a line version, and `v1.0` is a line version, these variables only choose the clone whose tags and `origin` refs are read: the tree that is built is the archive of the resolved ref, never the root's working tree, so an edited worktree or feature branch does not show. To build or preview a worktree's pages, combine them with explicit mode, which reads every root's `docs/site/` as it is:

```bash
OPM_VERSIONS=v1.0=/src OPM_SRC_WORKTREE=<name> task build
OPM_VERSIONS=v1.0=/src OPM_SRC_CLI=/path/to/cli-worktree task serve
```

## Directory Structure

```text
opmodel.dev/
├── site/
│   ├── Dockerfile              # Build image: Hugo, Pagefind, opm-docs, git, jq
│   ├── bundles.cue             # The Catalogs tab's docs bundles (task bundles:pull; see The Catalogs section)
│   ├── NOTICE                  # Third-party licences
│   ├── overrides.sha256        # Theme files behind every override copy (drift guard)
│   ├── vendored.sha256         # Vendored third-party files (Mermaid), with version and source
│   ├── config/_default/        # hugo.toml
│   ├── content/                # Site-owned pages: _index.md landing, docs/**/_index.md overviews
│   ├── enhancements/           # Content adapter of the unversioned Enhancements section
│   ├── catalogs/               # Content adapter of the unversioned Catalogs section (docs bundles)
│   ├── layouts/                # Theme overrides, OPM partials, figure shortcodes
│   ├── assets/css/opm/         # One CSS file per owner, concatenated in file-name order
│   ├── assets/js/              # Pagefind adapter for Hextra's search palette
│   ├── assets/lib/mermaid/     # Vendored Mermaid 11 and its licence, for the Enhancements diagrams
│   ├── static/                 # Fonts, favicon, images
│   ├── themes/hextra/          # Vendored Hextra v0.13.0 (runtime files only; hextra.COMMIT)
│   ├── versions.conf           # The site versions (see Site versions)
│   ├── scripts/                # Build, checks, lint, dev server, vendoring, host-side runner and version resolver
│   ├── tools/                  # Brand rasters: favicons.py, og-card.{py,html} (task brand:*)
│   └── tests/                  # Fixture workspace, lint and check cases, dialect tree, base-path build, browser QA, version tests
├── Taskfile.yml
└── README.md
```

## Tasks

```bash
task serve             # Dev server on http://127.0.0.1:${SITE_PORT:-1313}/ over the resolved versions; OPM_VERSIONS=v1.0=/src task serve edits sources live
task build             # Lint, build and check the site into site/public/ (no network)
task build OPM_BASE_URL=<url>  # The same, for another base URL (a path allowed); qa, shots and preview use the root
task preview           # Serve the built site/public/ on SITE_PORT
task lint:sources      # Lint the six source repos' docs/site pages
task test:site         # Prove every check fails when it should (fixtures), then task versions:test
task shots             # Build, then screenshot every figure page and the extras, and check every Enhancements diagram, into site/.shots/
task qa                # shots, the axe accessibility, search and theme switch smoke tests
task ci                # check, image, build, test:site
task check             # Go fmt, vet and test, and openspec validate
task image             # Build the site's image if its tag is missing
task qa:image          # Build the QA image if its tag is missing
task brand:favicons    # Regenerate the favicon PNGs and favicon.ico from the drawn SVGs
task brand:og          # Regenerate the Open Graph card, site/static/images/og-default.png
task versions:prepare  # Resolve site/versions.conf on the host, offline: refs, archives, git dates, frozen.conf (build and serve run it)
task versions:check    # Print every version's resolved refs, SHAs and rules; writes nothing
task versions:fetch    # Fetch every tag and branch of the six roots and enhancements from origin; never moves or deletes a tag; then bundles:pull
task bundles:pull      # Pull, verify and unpack the Catalogs tab's docs bundles into site/.bundles/ (network)
task versions:test     # Resolver tests and a two-version build into site/.check/versions-test/
task clean             # Remove generated files
```

## CI

The `Site` workflow (`.github/workflows/site.yml`) builds and tests the site on every pull request to `main`, on every push to `main`, nightly at 03:23 UTC, and on demand (`workflow_dispatch`). Its `build` job runs the Taskfile targets you run locally:

| CI step | Local equivalent |
|---|---|
| Lint the workflows | `task ci:lint`: actionlint, with its bundled shellcheck, from a digest-pinned image (`task ci:lint -- -verbose` names each file) |
| Pull the docs bundles | `task bundles:pull`: anonymous, no token; the `browser` and `sources-main` jobs wait for `build` and pull its lock frozen: `OPM_BUNDLES_FROZEN=<lock> task bundles:pull` |
| Check, build and test the site | `task ci`: `check`, `image`, `build`, `test:site` |
| The build leaves the tree clean | `task ci`, then `git status --porcelain` |
| Source pages on main (the `sources-main` job, not published) | `OPM_VERSIONS=v1.0=/src task build` with the six roots at `main` |
| Build for GitHub Pages (interim) | `OPM_BASE_URL=https://open-platform-model.github.io/opmodel.dev/ task build`, after the steps above (see GitHub Pages (interim) below) |

- **Clean tree.** CI fails when `task ci` leaves the tree dirty, `.task/` excluded (Task's checksum files; one of them is tracked). Two examples: `go fmt` rewrote unformatted Go (`task check` formats but never fails), or a build step wrote a file that is not gitignored.
- **Checkout layout.** Every repository is checked out with `path:` under `$GITHUB_WORKSPACE`, opmodel.dev included, so `OPM_WS` is `$GITHUB_WORKSPACE` and the six source repositories and enhancements sit beside opmodel.dev as they do in the workspace (the `sources-main` job checks enhancements out too, shallow, and builds its `main` in explicit mode). opmodel.dev is at the event's ref and the sources are at `main`, though a line version builds its trees from the tags and branches it resolves, not from the checkouts. Every checkout has full history, every tag and every branch as `refs/remotes/origin/*` (`fetch-depth: 0`, which the version resolver, the git dates and the resolver tests of `task versions:test` need; the resolver refuses a shallow checkout) and `persist-credentials: false`: no step pushes, so no clone keeps a token that the build containers could read.
- **Dates.** The workflow sets `OPM_REQUIRE_DATES=1`, so a page without a git date fails the build. `task versions:prepare` computes every date on the host, so a local build passes the same check, from worktrees too: `OPM_REQUIRE_DATES=1 task build`. `task test:site` sets it back to 0 for its fixtures; the two-version build of `task versions:test` keeps it.
- **Summary and artifacts.** The job summary lists every version's resolved refs from `site/public/build-stamp.json` (repository, ref, where its docs came from, the commit and the rule that chose it), a Catalogs table of every docs bundle built (project, segment, version, revision, digest, commit), and the number of files in `site/public/`. The `site-public` artifact holds the whole `site/public/` for 14 days; `build-stamp` holds the stamp for 90 days, and `build-manifest` holds `.versions/frozen.conf`, the build as an anchored manifest (Site versions), and `.bundles/lock.json`, the docs bundles it read (The Catalogs section), for 90 days. `build-manifest` is uploaded on every run but pull requests: a pull request run builds GitHub's temporary merge commit (`refs/pull/<n>/merge`), which would be the commit its header names and which goes away, so only runs of a real branch, `main` above all, can be rebuilt from their `frozen.conf`. After those uploads, the GitHub Pages build adds one summary line with its file count and uploads its tree as the `github-pages` artifact, kept for one day; a deploy adds a summary naming the deployed URL.
- **Browser job.** The `browser` job runs `task qa`, as you do locally, after `build`, on exactly the docs bundles `build` read (its `bundles-lock` artifact, pulled `--frozen`), so QA checks what deploys: it builds the site itself (with the same eight checkouts, since that build reads every source repository and enhancements), takes the screenshots in six variants, fails when figure text drops below 9 px at phone width, and runs the axe WCAG 2.1 A and AA smoke test and the search smoke test, all in the QA image with no network. The `site-shots` artifact holds `site/.shots/` for 7 days from every run that got as far as taking screenshots, a failed run's included: when an accessibility or search test fails in CI, the screenshots show why. Its upload sets `include-hidden-files: true`, because `actions/upload-artifact` skips every file under a directory whose name starts with a dot, and `.shots` is one.
- **Pins.** Every action is pinned by full commit SHA, with its version in a comment. Task is pinned to an exact version (3.52.0), the openspec CLI to 1.12.0, and the `ci:lint` task pins actionlint by image digest. Nothing floats: bump each on purpose.
- **Concurrency.** It is set per job, one group per job (`<workflow>-<ref>-<job>`), and a newer run cancels the older run's job. It is never set at workflow level, which would cancel a deploy job with the rest of a run; and two jobs never share one cancelling group, because they would cancel each other. A deploy job uses its own group, without `cancel-in-progress`. The `opmodel.dev` working directory is a per-job `defaults` entry for the same reason, never workflow-level: a deploy job runs a step before its checkout.
- **Source repositories.** A line version resolves its release lines on every build, so the nightly run of `main` publishes what moved upstream within about a day, and `gh workflow run Site --ref main` publishes it at once; no source repository dispatches a run. What reaches the published build: new releases (a cli release with the library, core and opm-operator releases it pins, and every `opm-v4.*` catalog tag), opm's `main`, and the `main` or release-branch head of cli, library, opm-operator, core and catalog_opm while their docs rule reads it. The `sources-main` job keeps the early warning for all six: it builds every repository's `main` in explicit mode (`OPM_VERSIONS=v1.0=/src task build`: the source lint, every build check and the link crawl), uploads nothing, and `pages-deploy` does not wait for it. A source page that breaks the lint or a link on a branch head the line reads (today `main` of all six) also fails `build`, turning every run red and holding the deploy until it is fixed upstream or the version is recovered (Site versions, "When the resolution fails"); `sources-main` alone catches a `main` the line does not read. A new release that fails resolution or the build turns every run red and holds the deploy until it is recovered (Site versions, "When the resolution fails"). GitHub disables a scheduled workflow after 60 days without repository activity (re-enable it on the Actions tab), and it mails a scheduled run's failure to whoever last edited the cron line.
- **Pull request titles.** The `PR Title` workflow (`.github/workflows/pr-title.yml`) fails a pull request whose title is not a Conventional Commit with this repository's types (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `build`, `ci`; the "Commit Standards" in `openspec/config.yaml`) and a lower-case subject. The squash merge keeps a single commit's subject, but a pull request with several commits, as every OpenSpec change has, lands on `main` under its title. The workflow runs on `pull_request_target`, which reads the workflow from `main`, so a change to it first applies to the pull request after it merges.

### GitHub Pages (interim)

Until the Cloudflare deploy replaces it, the site is published at https://open-platform-model.github.io/opmodel.dev/. It is public and linkable, but interim: the documentation is not finished, and the address goes away when the site moves to `opmodel.dev`.

**What and when.** The `build` job builds the site a second time for that URL (`PAGES_BASE_URL` in the workflow, passed to `task build` as `OPM_BASE_URL`), from the same checkouts, dates and checks, and uploads it as the `github-pages` artifact on every run, pull requests included. The `pages-deploy` job publishes that artifact on pushes to `main`, the nightly run and manual runs of `main`, and only after `build` and `browser` pass (`needs: [build, browser]`). It never runs on a pull request, and the `github-pages` environment allows only `main`. Every HTML page of this build carries `<meta name="robots" content="noindex, nofollow">`, because its host is not `opmodel.dev` (`params.opm.indexedHost`).

**How this host differs** from the Cloudflare plan:

- It ignores `_redirects`, so there are no 302s: `/` and `/latest/` are meta-refresh pages (the root `index.html` and the `/latest/` stubs), and `/latest/` works only for HTML pages.
- It serves only the root `404.html`, for a missing path at any depth.
- It sends no custom headers, so there is no `X-Robots-Tag`, and a `robots.txt` under a path is ignored.

So only the HTML pages carry `noindex`. The Markdown twins, `llms.txt`, `sitemap.xml` and `build-stamp.json` cannot; they stay out of search results only because nothing indexable links to them.

**The owner's setting.** Pages must be on with source GitHub Actions: Settings > Pages > Build and deployment > Source: GitHub Actions (repository admin), or:

```bash
gh api -X POST repos/open-platform-model/opmodel.dev/pages -f build_type=workflow
```

On a 422, add `-f 'source[branch]=main' -f 'source[path]=/'`. If the site exists with another source, use `gh api -X PUT repos/open-platform-model/opmodel.dev/pages -f build_type=workflow`. Check both settings:

```bash
gh api repos/open-platform-model/opmodel.dev/pages --jq .build_type
# workflow
gh api repos/open-platform-model/opmodel.dev/environments/github-pages/deployment-branch-policies --jq '[.branch_policies[].name]'
# ["main"]
```

A deploy while Pages is off fails at `configure-pages`, and nothing is published; once Pages is on, `gh workflow run Site --ref main` runs it again. The job also stops before publishing when Pages serves another URL than `PAGES_BASE_URL` (a custom domain on the Pages site, a renamed repository). A failed deploy leaves the previous one serving.

**Checking a deploy.** Each command prints what follows it:

```bash
curl -sS https://open-platform-model.github.io/opmodel.dev/ | grep -o 'url=[^"]*'
# url=/opmodel.dev/latest/
curl -sS https://open-platform-model.github.io/opmodel.dev/latest/ | grep -o 'url=[^"]*'
# url=/opmodel.dev/v1.0/
curl -sS -o /dev/null -w '%{http_code}\n' https://open-platform-model.github.io/opmodel.dev/v1.0/docs/
# 200
curl -sS https://open-platform-model.github.io/opmodel.dev/v1.0/docs/ | grep -c 'noindex, nofollow'
# 1
curl -sS -o /dev/null -w '%{http_code}\n' https://open-platform-model.github.io/opmodel.dev/v1.0/no-such-page/
# 404
curl -sS https://open-platform-model.github.io/opmodel.dev/v1.0/no-such-page/ | grep -o 'href=[^ >]*>Go to the docs'
# href=/opmodel.dev/v1.0/docs/>Go to the docs
curl -sS -o /dev/null -w '%{http_code}\n' https://open-platform-model.github.io/opmodel.dev/fonts/Geist-Variable.woff2
# 200
curl -sS https://open-platform-model.github.io/opmodel.dev/build-stamp.json
# every version's resolved refs, SHAs and docs sources and the opmodel.dev commit, as in the run's job summary
```

Search runs only in a browser, so check it once by hand: on https://open-platform-model.github.io/opmodel.dev/v1.0/docs/, search for `quickstart`; every result opens a page under `/opmodel.dev/v1.0/`.

**Retirement.** The Cloudflare change removes the `pages-deploy` job, the two GitHub Pages steps of `build`, `PAGES_BASE_URL`, this subsection and its row in the table above. `OPM_BASE_URL`, the base-path checks and the `noindex` rule stay. After the first Cloudflare deploy is verified, the owner turns Pages off and deletes its environment (repository settings, the owner's actions; Settings > Pages works too):

```bash
gh api -X DELETE repos/open-platform-model/opmodel.dev/pages
gh api -X DELETE repos/open-platform-model/opmodel.dev/environments/github-pages
curl -sS -o /dev/null -w '%{http_code}\n' https://open-platform-model.github.io/opmodel.dev/
# 404
```

## Site versions

`site/versions.conf` is the only list of the versions the site publishes. It is in git-config syntax (`git config --file` reads it, so nothing new enters the build image), and the list itself changes only by a reviewed commit. `task build` and `task serve` resolve it on the host first (`task versions:prepare`, which never touches the network); `task versions:check` resolves it and prints every version's refs, SHAs and rules without building.

A version is one of three kinds, chosen by its keys:

- **Line** (`cli-line`, `catalog-line`): the kind the site publishes. It follows release lines and is resolved again on every build, the nightly one included, so a new release reaches the site with no commit here. Until 2026-10-01 the rule was the opposite, a published version moved only by a commit that bumped a fixed anchor ref and never a moving line resolved at build time; the owner reversed this on 2026-10-01. Reproducibility moved from the manifest to the record every build keeps (below).
- **Anchored** (`cli`, `catalog`, `opm`): fixed refs, bumped by commit. `cli` is the anchor, a tag or a full SHA; library, core and opm-operator come from its pins as in a line version; `catalog` and `opm` are explicit, because the CLI pins no catalog and opm has no repository-level tag. It serves older versions, the tests and the recovery of a failing line.
- **`source = main`**: every source repository at its checked-out `HEAD`, read in place, uncommitted edits included. It is for tests and local work, at most one version, and the published manifest has none. Local live editing of source pages is explicit mode instead: `OPM_VERSIONS=v1.0=/src task serve` reads every `docs/site/` in place, while a line version serves its archives in `site/.versions/v1.0/`.

The manifest today:

```ini
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	cli-line = v1.0
	catalog-line = opm-v4
```

How a line version resolves each repository:

| Repository | Ref, as the stamp names it | Tree built |
|---|---|---|
| cli | the newest tag of `cli-line` (`v1.0.*`) by semver precedence, prereleases included: `v1.0.0` beats `v1.0.0-rc.1`, `beta.10` beats `beta.2`, and `v1.50.0` is not in `v1.5` | the docs rule below |
| library | the version `go.mod` requires at that cli tag | the docs rule below |
| opm-operator | `PinnedOperatorVersion` (`internal/operator/manifest.go`) at that cli tag | the docs rule below |
| core | `DefaultSchemaModule` (`opm/schema/loader.go`) at the pinned library tag | the docs rule below |
| catalog_opm | the newest tag of the catalog major `catalog-line` (`opm-v4.*`); the cli consumes the catalog by major, so a new catalog minor needs no commit | the docs rule below |
| opm | `main` | the head of `origin/main` |

The docs rule, for every released repository (cli, library, opm-operator, core and catalog_opm), with `X.Y` the minor of the release the stamp names: the head of `release/<prefix>vX.Y` (`release/v1.0`, `release/v2.0`, `release/opm-v4.4`) once that branch exists; else the head of `main` while `main` still releases `X.Y` (its newest merged release tag is in that minor); else, once `main` has moved past `X.Y` and no branch was cut, the named release's own tag. The release the stamp names must contain its floor, and a branch head it is read from must contain that release. The pins are always read at the release tags (the cli tag, the library release), never at a docs head. When `main` moves past a line that the site still publishes, cut `release/vX.Y` for it, or its docs fall back to the release tag and a docs fix waits for a release again. `cli/hack/platform/` is a test fixture and never a pin.

So a docs fix in any of the five released repositories reaches the site at the next build, from its release branch head (from `main` during beta), with no release. That matters because `docs` commits stop releasing in library, opm-operator and cli once their `prepare-release-cascade` changes hide that changelog section (workspace `RELEASING.md`, "Pin classes"). The versions the stamp names still move only through releases: a new cli tag, and the library and opm-operator releases it pins.

A new catalog major (`catalog-line = opm-v5`) or a new cli line (`cli-line = v1.1`) is a commit to the manifest, made when the cli moves to it; a new catalog minor or patch is not.

**Overrides.** `override = <repo> <ref> <reason>` replaces one row with a tag or a full SHA; the reason is required and is recorded in the build stamp (the footer link title and `build-stamp.json`). cli is never overridden. In a line version an override is only for a row that fails: the row it replaces is still resolved and checked, the stamp records it (`override:<reason>; replaces <ref> (<rule>)`), and once that row passes every check the build fails with `... no longer needed: the line resolves <ref> (<rule>), which passes every check; remove the override`. An override written for one cli release therefore fails at the first release that no longer needs it, instead of replacing the pins of every later one. An opm override fails unless `main`'s head itself fails. An anchored version's overrides change only by commit, as the version does.

**Refs and fetching.** A line version reads tags and the remote-tracking refs `refs/remotes/origin/main` and `refs/remotes/origin/release/*`, never a local branch or `HEAD`, so a worktree resolves exactly as its main checkout does. It assumes that `origin` is the upstream open-platform-model repository, so a local build needs that `origin`: a clone whose `origin` is a fork resolves the fork's tags and branches. It refuses a shallow root or one without `origin/main`, with a named error, and it never fetches. After a release, fetch first:

```bash
task versions:fetch build
```

`task versions:fetch` runs `git fetch` in the six roots with explicit refspecs, `+refs/heads/*:refs/remotes/origin/*` and `refs/tags/*:refs/tags/*` (the tag one without `+`), an empty `--refmap=` and `--no-prune --no-prune-tags --no-tags --no-write-fetch-head`. Without `--refmap=`, git would still apply every configured `remote.origin.fetch` as an extra forced mapping (a configured `+refs/heads/*:refs/heads/*` resets local branches); with it, git ignores them all. So whatever your git config says, it never moves or deletes a tag or a local branch and writes nothing in a worktree. A local tag that differs from origin's fails it, naming the root, with `would clobber existing tag`; tags are immutable, so report it and never force it. CI needs no fetch: its checkouts carry every tag and branch.

**The record.** Every build records, per version and repository, the ref, the SHA of the tree built, the rule that chose it and where that tree came from (`docs`: `tag`, `sha`, `main`, `release/...`, or `worktree` for `source = main`), plus the opmodel.dev commit, the seventh input (the layouts, the site-owned pages, the floors, the image):

- `site/.versions/versions.tsv`, with a `# site <sha>` line;
- `site/public/build-stamp.json`: `versions.<v>.refs.<repo>.{ref,sha,how,docs}` and `site`;
- the footer stamp, for example `core v2.0.0-beta.1 (docs main f5c4463)`, and every page's "View source at <ref>" link to the archived SHA;
- the CI job summary.

`site/.versions/frozen.conf` is the same build as an anchored manifest: a tree read at its tag by the tag name, every other tree by its SHA, every derived repository overridden, so nothing is derived again. A cli whose docs came from a branch head is frozen as `cli = <that SHA>` under a `; cli <tag>, docs <branch>` comment naming the release; with library, core and opm-operator all overridden, no pin is read at that SHA. CI keeps it for 90 days as the `build-manifest` artifact of every run but pull requests (CI below). To rebuild the same trees, check out opmodel.dev at the commit its header names, copy the file outside `site/.versions/` (the resolver refuses the generated file itself, because a run rewrites it), copy the same artifact's `.bundles/lock.json` to `site/bundles.frozen.json` and run `task bundles:pull` (the same docs bundles), then run `OPM_VERSIONS_MANIFEST=<the copy> task build`.

**When the resolution fails.** A new upstream release or head that fails a check turns every run red, pushes, pull requests and the nightly alike, until it is recovered; the whole manifest fails, never one version, and the deployed site stays at the last good deploy. A resolver error names the version, the repository, the ref and the rule that chose it; a build error names the page. Recover by the kind of failure:

- A resolver check in library, core, opm-operator or catalog_opm (a pseudo-version or `replace` pin, a release older than its floor, a release branch that does not contain the release the stamp names): add an override for that row; it fails again, as no longer needed, once the line passes on its own.
- Anything else, in any row: cli failing a resolver check (its newest tag is older than its floor, or the tree its docs come from has no `docs/site/` or does not contain that tag; cli is never overridden), or a resolved tree that fails the build itself (the source lint, the page set, a link). An override cannot cover a build failure, because the row it would replace passes every resolver check, so it is refused as no longer needed. Switch the version to anchored: replace its block in `site/versions.conf` with the `[version ...]` block of the last good `build-manifest` artifact's `frozen.conf` (a run of `main`), which pins the trees that last built green, and commit. Move it back to line mode (`cli-line`, `catalog-line`) once upstream fixes the cause (a release, or a fix on the branch head its docs come from). The resolver tests prove it accepts that block, on fixtures and on the real roots.

Every repository has a dialect floor in the manifest: the commit that moved its `docs/site/` pages to the page dialect. No ref older than its floor builds: the resolver fails first, naming the repository and the ref (in a line version also the rule), and it never skips back to an older tag.

The site-owned pages (`site/content/`) are built into every version, so every link on them must resolve in every version, older ones included; a link to a page that exists only in a newer version fails that version's build.

### The Catalogs section

The catalog reference is a tab of its own, outside the site versions: `/catalogs/opm/<MAJOR.MINOR>/` for every opm minor from 4.5 on (the first release after catalog_opm adopted docs-kit; there is no backfill) and `/catalogs/opm/edge/`, labelled "main (unreleased)". Each comes from one signed OCI docs bundle that catalog_opm's CI publishes through docs-kit's reusable `publish.yml` (`ghcr.io/open-platform-model/docs/catalog-opm`). `site/bundles.cue` names the tab (docs-kit contract C7): its `repo`, its `root` and `from`, the oldest minor shown. `task bundles:pull` runs `opm-docs pull` in the build image, the one step besides the image builds and `versions:fetch` that reaches the network: it resolves every minor tag at or above `from`, and `edge`, and accepts a bundle only when its Sigstore signature names docs-kit's `publish.yml` at a `refs/tags/v[0-9]*` ref as the signer and `open-platform-model/catalog_opm` at `refs/heads/main` as the source (C9); it unpacks into `site/.bundles/` and writes `site/.bundles/lock.json`. A new minor or a new `edge` build reaches the site at the next build, with no commit here. The lock is never committed; the build stamp (`sections.catalogs`) records it and every bundle's digest and commit. `task build` never pulls: in manifest mode it fails without a lock pulled for the current `bundles.cue` (naming `task bundles:pull`); an explicit build (`OPM_VERSIONS`) has the section only when `site/.bundles/` holds a lock; `OPM_BUNDLES=<dir>` builds from a saved unpacked tree instead. `opm-docs` is pinned by version and by the SHA-256 of its `linux_amd64` archive in `site/Dockerfile` (the line in that release's `checksums.txt`, checked against a second download); a bump re-syncs the lint fixtures (Page dialect). The site bumps first (docs-kit C12): a producer (catalog_opm, core, cli, opm-operator) moves its `.opm-docs-version` to a docs-kit release only after `site/Dockerfile` pins that release or a newer one, since an older `opm-docs` refuses a bundle or lock field it does not know.

Every minor and `edge` has its own sidebar, its own Pagefind index, and a switcher on every page (newest first, `edge` last) that keeps the reader on the same page, else its nearest parent, else the landing. The landing of each minor is catalog_opm's contract page followed by the generated `## Catalog members` block (`#catalog-members`). `/catalogs/opm/` and `/catalogs/opm/<MAJOR>/...` are aliases of the newest minor (of that major), as `_redirects` lines and as `noindex` meta-refresh stubs; `edge` has none. Only the newest minor of each major is indexed and listed in `llms.txt` and the sitemap; older minors and `edge` are `noindex`.

**Version history.** `opm-docs pull` also writes `site/.bundles/catalog-opm/history.json` (docs-kit contract C13), which compares the segments it pulled, and records its SHA-256 in the lock's `history` key. The site reads that file and never computes history itself. `gen-catalogs.sh` checks it against the lock and fails the build when the digest differs, the file is missing, or the file holds a value C13 does not allow; recovery is a fresh `task bundles:pull`, never an edited file. A file the lock does not record (left by an older pull) is ignored. From it, a member page shows badges beside its type badge ("Added in X", "In <floor> or earlier", "Unreleased", "Changed in X" for its own segment, "Newer version" linking the newest apiVersion's page in that segment), and a page-end "Changes in X" section lists its field changes, one line each, worded as C13 words them and more cautiously for a pair compared by field paths only. A kind index lists the members removed in its segment under "Removed in X", each linking its page in the last segment that had it; a kind with no index left lists them on the segment's landing. Field changes appear only in that list, never inside the spec block, which is a code fence the bundle publishes as built. Both sections are Markdown the adapter appends to the page body, so the table of contents and the `.md` output carry them; a Removed link carries the title `opm:removed`, which lets it name another segment only when it matches one of the page's own removals. The fixtures in `site/tests/fixtures/bundles/` include the history the pinned `opm-docs` writes for them.

`/catalogs/` is a picker: one full-width card per catalog, stacked at any count, and one sidebar entry per catalog, both generated (`site/layouts/_partials/opm/catalog-entries.html`, `catalog-picker.html`). A card's title, `<name> catalog`, links the newest release (`edge` for a catalog with no release yet), and the card also shows the CUE module path and the member kinds with counts (from the bundle's `data/catalog.json`, when it carries one), the repository, and a link to `edge` as "main (unreleased)". It shows only facts the bundles carry. The catalog's one-line description exists at its source (core's `#Catalog.metadata.description`, which catalog_opm fills), but docs-kit's cue-catalog extractor does not yet copy it into `data/catalog.json`; the card shows it once the extractor writes `description` there. A display name waits on a tab-only `placement.title` in docs-kit's manifest; `#Placement` is closed, so the site must accept the field before any bundle carries it. `gen-catalogs.sh` marks the page `params.picker: true`, which `opm/docs-main.html` and `sidebar.html` key on. In HTML the cards replace the page body; the body `gen-catalogs.sh` writes (the description sentence and one line per catalog with both links) feeds only the page's Markdown twin. `task test:site` (`catalogs/picker`) fails when a catalog has no card or sidebar entry linking its newest release.

An author previews a local catalog build with `OPM_BUNDLES_LOCAL="catalog-opm@4.5=<release build> catalog-opm@edge=<catalog_opm>/out/catalog-opm" task bundles:pull build` (`opm-docs build` outputs, `--release opm-v4.5.1` and the default edge; one pair per segment, space-separated). A local project skips the registry entirely, so name a release minor of every major the docs link (`/catalogs/opm/4/`), or those links fail the build. A pull whose every tab is local runs with no network, and the stamp marks those bundles `local`. When a newly published bundle breaks the build (it fails `pull`'s lint or a site check), commit the last good `build-manifest` artifact's `.bundles/lock.json` as `site/bundles.frozen.json`: `task bundles:pull` then pulls exactly those digests (`--frozen`, signatures still checked) until the file is deleted, and the stamp and the CI summary say the bundles are frozen. `opm-docs` refuses a frozen lock once `site/bundles.cue` has changed (the lock's `config` digest must match), so take a lock pulled for the current file. A frozen pull still fetches the blobs and the Sigstore trusted root, so it is no way around a GHCR or Sigstore outage: an outage fails `task bundles:pull` and every site build, and is waited out.

The tab replaced catalog_opm's Reference copies of the members (`reference/catalog-members/` and `reference/catalog-contract.md`), which catalog_opm deleted on 2026-10-03; their old URLs get no redirects. A version whose catalog_opm tree is older still holds them, and they publish in that version like any page, so its own links to `/docs/reference/catalog-contract/` and `/docs/reference/catalog-members/` resolve there; the build neither hides them nor maps those links to the tab.

The fixtures in `site/tests/fixtures/bundles/` are three bundle trees (`catalog-opm` 4.4, 4.5 and `edge`) plus the `history.json` and the lock an all-local pull writes over them. `task test:site` first re-pulls them with the pinned `opm-docs`, offline (`--local`), and fails unless the result is byte-identical, lock included; every fixture build then reads that pulled copy. A fixture edit regenerates `lock.json` with the same pull.

### The Enhancements section

The enhancements repository is an eighth input and belongs to no version: `[section "enhancements"]` in `site/versions.conf` names its `ref` (`origin/main`, the remote-tracking ref, never a local branch or `HEAD`; a tag or a full SHA also work), resolved on every build like a line version. When a push there breaks the build, `override = <full SHA> <reason>` pins a commit that built, until it is fixed there. The resolver records the SHA in `versions.tsv` (a `# section` line), `build-stamp.json` (`sections.enhancements`), the CI summary and `frozen.conf`; `materialise.sh` writes a `git archive` of only the published files (`INDEX.md`, `GRAPH.md`, and of every entry but the `0000` template its `config.yaml`, `README.md` and seven numbered documents) to `site/.versions/enhancements/tree/`, with every path of the repository in `paths.txt`. Explicit mode (`OPM_VERSIONS`) reads `<default root>/enhancements/` in place: `/src/enhancements`, the root `OPM_SRC_ENHANCEMENTS` names (default `$OPM_WS/enhancements`), or the fixture workspace's. A build without that tree, or with a manifest that names no section, has no section and no Enhancements tab.

The content adapter `site/enhancements/_content.gotmpl` is mounted into the default version only and gives every page a `url`, so the section publishes once, at `/enhancements/`, outside `/<version>/`, and keeps its URLs when the default version changes. URLs are keyed by entry id, so archiving an entry keeps them: `/enhancements/` (the INDEX, generated by `gen-mounts.sh` as `.gen/enhancements/_index.md`, since an adapter cannot add a section page), `/enhancements/graph/`, `/enhancements/NNNN/` (the README, with a header from `config.yaml`) and `/enhancements/NNNN/{problem,design,decisions,graduation,risks,operational,questions}/`. A decision heading `D3: ...` also carries the anchor `#d3`. Every page carries a status banner; draft and accepted entries carry `noindex`; no section page is in `llms.txt`, a sitemap, the `/latest/` stubs or the docs search (the section has its own Pagefind bundle, `/enhancements/pagefind/`). Relative links are repository paths: an entry or one of its documents goes to its page, any other path that exists at the built SHA (a schema, an experiment, research, `config.yaml`) to GitHub at that SHA; a path that names nothing at that SHA, a link that climbs out of the repository, a broken `/docs/` link or a Hugo shortcode delimiter fails the build. A link whose text is the Markdown file name it targets reads as its page (`INDEX.md` as "the index", `GRAPH.md` as "the relationship graph", another as the page's title). A Mermaid fence in the section is drawn by Mermaid 11.17.2, vendored as `site/assets/lib/mermaid/mermaid.min.js` (its licence beside it, `site/NOTICE`) and pinned with its version, source and SHA-256 in `site/vendored.sha256`, which `site/scripts/check-vendored.sh` checks before every build; a re-vendor is a new download verified at its source, never a re-pin of what is on disk. Hextra loads it fingerprinted, with SRI, only on a page that holds a fence. The section's hook (`layouts/enhancements/_markup/render-codeblock-mermaid.html`) draws each diagram at its natural size (`useMaxWidth: false`) in a box that scrolls sideways and takes the keyboard focus, since fitted to the column most labels would shrink under 9 px; in the dark theme the edge labels get a darker box (`enhancements.css`), as Mermaid's own fails WCAG AA. `task shots` and `task qa` run `site/tests/browser/diagrams.py`, which draws every diagram of the section in the browser and fails on a Mermaid error, a label under 9 px or a label under AA contrast in either theme (and first proves it catches a broken and a squeezed diagram); its PNGs go to `site/.shots/diagrams/`.

`OPM_VERSIONS_MANIFEST=<file>` selects another manifest. `task versions:test` (part of `task test:site`) runs the resolver tests on fixture repositories (the line cases clone them, so `origin` and its refs exist as in CI) and on the real roots, then builds `site/tests/versions/two-versions.conf`, `v1.0` in line mode plus an anchored test version, into `site/.check/versions-test/`, never `site/public/`. When `task versions:test` fails naming `(version v0.9)`, a source or site-owned page no longer builds at the test version's SHAs: bump them in `two-versions.conf` to buildable SHAs after each floor, never edit the checks. A fixture-workspace build sets the versions itself, because its roots sit inside this repository and are no git top levels: `OPM_VERSIONS=v1.0=/src OPM_WS=$PWD/site/tests/fixtures/ws task build`.

## Implementation Status

- [x] Hugo + Hextra site, built and served in Docker with no network
- [x] Pages assembled from six source repositories, in one page dialect, with a source lint
- [x] Build checks: drift guard, lint, front matter, links, page set, stray files, placeholders that yield to source pages, planning comments, supply chain, redirects, git dates
- [x] Per-version Pagefind search in Hextra's palette; `/latest/` and root redirects
- [x] Browser QA: screenshots in six variants, WCAG 2.1 A and AA smoke test, search smoke test, theme switch smoke test
- [x] The theme switch animates with the View Transitions API: a circular reveal from the pointer, a short cross-fade for the keyboard and the OS, nothing under reduced motion (`site/assets/js/opm-theme-transition.js` wraps Hextra's `setTheme`; `site/tests/browser/theme_reveal.py` guards it)
- [x] All nine figures of the page dialect, drawn as inline SVG that follows the site's theme toggle
- [ ] Generated reference pages, committed in each owning repository (cli, opm-operator, catalog_opm, core)
- [x] Versions from a manifest of source refs (`site/versions.conf`), with dialect floors and a two-version regression test
- [x] `v1.0` follows its release lines (`cli-line`, `catalog-line`), with every resolved SHA recorded and a frozen manifest per build
- [x] The Catalogs tab, built from signed docs bundles per opm minor and `edge`
- [x] Catalog version history: badges, "Changes in" and "Removed in" sections, read from the history `opm-docs pull` writes
- [ ] CI and deployment

## Contributing

### Preview

Run `OPM_VERSIONS=v1.0=/src task serve` and open http://127.0.0.1:1313/. In that explicit mode it reads every source repository's `docs/site/` in place, so an edit to a page shows without a restart; a plain `task serve` serves the line version's archives at the refs it resolved. Before a pull request, run `task build` (every check) and, when anything visual changes, `task qa`, and look at the screenshots in `site/.shots/`.

### Page dialect

Pages in a source repository's `docs/site/` follow the site page rules in the workspace `STYLE.md` ("Site Pages"): front matter with `title`, `description` and, on a leaf page, `type`; a section page is `_index.md` and declares no type; order is `weight`, then title; callouts are GitHub alerts with a bold title line; figures are `{{< opm/<name> >}}` shortcodes; internal links are `/docs/<section>/<page>/`, or, into the Enhancements section, `/enhancements/`, `/enhancements/<NNNN>/` and `/enhancements/<NNNN>/<document>/` (one of the seven document slugs), each with an optional `#fragment` (`/enhancements/0021/decisions/#d3`); nothing else under `/enhancements`; or, into the Catalogs tab, the bare tab root `/catalogs/<name>/` or the major alias `/catalogs/<name>/<MAJOR>/` and below (`/catalogs/opm/4/traits/backup/#spec`), never a minor, `edge` or `/catalogs/` alone, and the site writes the URL of the newest minor of that major. `task lint:sources` checks every page and names the file and line of each problem. The lint (`site/scripts/lint-sources.sh`) is byte-identical to the workspace dialect contract (the embedded copy in `openspec/changes/deploy-site/orchestration.md`, with its SHA-256): fix the page, never the lint, and change both together when the contract changes.

`site/tests/lint/` and docs-kit's conformance set (`internal/dialect/testdata/conformance/`) are kept identical, so the shell lint and `opm-docs lint`, which lints every bundle, agree until docs-kit's phase 3 retires the shell lint. docs-kit is the source of new rules and their fixtures (the `/catalogs/` forms first): a rule lands there first, in a release, and this repository copies the changed cases and updates the lint in the same pull request that bumps the `opm-docs` pin in `site/Dockerfile`. `site/tests/lint/link-catalogs/SOURCE` names the tag the fixtures were last synced from.

The link hook (`site/layouts/_markup/render-link.html`) resolves a `/enhancements/` link to the one unversioned section from every version (the section's pages live only in the default version's page tree), and fails the build when the section has no such page or the build has no section; a `/catalogs/` link resolves the same way through the newest minor of its major, and fails naming `task bundles:pull` when the build has no Catalogs section.

A direction note is a NOTE alert whose bold title line is **Direction**:

```markdown
> [!NOTE]
> **Direction**
>
> Enhancement 0009, [Operational Primitives](/enhancements/0009/), is a draft, and none of it is built.
```

It renders labelled Direction in place of Note, with its title line not repeated, in a violet box with a dashed start border (`site/layouts/_markup/render-blockquote-alert.html`, an override of Hextra's alert hook pinned in `site/overrides.sha256`, and `typography.css`), so it stands apart from an ordinary note. Every other alert renders as before. `task shots` shoots the first direction note of every page that holds one, in the six variants, into `site/.shots/direction/<page>/`, and `task qa` runs axe on the first such page in both themes.

The site-owned pages in `site/content/` are not linted, but the build checks their front matter too.

### Adding a figure

A figure is inline SVG drawn by hand in the site engine. Mermaid draws only in the Enhancements section: a mermaid fence anywhere else, a docs page or a site-owned page, fails the build (`layouts/_markup/render-codeblock-mermaid.html`). A figure is two files:

1. The shortcode `site/layouts/_shortcodes/opm/<name>.html` renders the frame, `partial "opm/figure.html"`, with a dict of `id`, `title`, `claim`, `width`, `height` and `body`.
   - `id` is three letters, unique among the figures. The frame names the arrowhead marker `<id>-arrow` after it.
   - `width` is 360: every figure is drawn on a grid 360 units wide. `height` is the figure's own.
   - `claim` states the figure's one point. The frame prints it both as the caption and as the SVG's accessible label, so it must make sense to a reader who cannot see the drawing.
   - `body` is the body partial below, rendered with `partial`.
2. The body `site/layouts/_partials/opm/figures/<name>.html` holds the SVG elements, drawn with the `opm-fig` classes in `site/assets/css/opm/figures.css`. Reference the arrowhead as `marker-end="url(#<id>-arrow)"`, and write comments as Go template comments (`{{/* ... */}}`). A body is one of two kinds:
   - static: the elements written out, as in `helm-and-opm.html`;
   - data-driven: a `range` over a `slice` of `dict` values, one per row, with the coordinates computed in `add`, `mul` and `div` on integers, as in `component-to-objects.html`. `div` truncates, and `len` counts bytes, not characters, so size a box around non-ASCII text by hand.

Every figure keeps these rules:

- Colours come only from the `--opm-fig-*` tokens in `figures.css`. A `.opm-fig` rule never names a raw colour, a Hextra colour or `prefers-color-scheme`; raw values appear only where the tokens are defined. The tokens are set again under `html.dark`, so a figure follows the site's theme toggle, not the OS.
- One colour per role: blue for the module author (`author`), green for the deployer (`deployer`), orange for the platform team (`team`). Published and Kubernetes things stay neutral (`neutral`, `obj`). A new class gets its rule in `figures.css`, on the tokens.
- No text is under 10 px on the grid, so it stays at 9 px or more on a 390 px phone. `task shots` fails below 9 px.
- A page shows a figure at most once, because the arrowhead marker id is per figure.

A new figure name is a change to the page dialect. Add it to the workspace dialect contract first, then in the same change to `FIGURES` in `site/scripts/lint-sources.sh` (which stays byte-identical to the contract) and to the list of figure names in the workspace `STYLE.md` ("Site Pages"). Add its title, exactly as its shortcode passes it to the frame, to `site/layouts/_partials/opm/figure-titles.html`, which the Markdown outputs print where the page draws the figure; `task test:site` fails when the two differ. Pages then use it as `{{< opm/<name> >}}` on a line of its own.

One figure is site-owned and outside the dialect: the landing's `opm/landing-overview`, which only `site/content/_index.md` calls. It is not in `FIGURES` or `figure-titles.html` (the home page has no Markdown output). It is 372 wide, so its edges meet the hero's column and its labels stay at 9 px on a phone, and it passes `caption` set to `false`, which leaves the visible caption out while the claim stays the SVG's accessible label. A dialect figure always shows its caption and never passes `caption`.

To check a figure, run `task qa` and read its PNGs in `site/.shots/<page>/` in all six variants: light, dark, both theme and OS mismatches, and phone light and dark.

See the main [OPM documentation](https://github.com/open-platform-model) for general contribution guidelines.

## Page design

Rules for page authors and for anyone changing the site's layouts or styles.

- **The description is shown three times.** A page's front-matter `description` is its lead paragraph under the title, its card text on its section's index page, and its sub-line in search results. Write it as one plain sentence that stands alone: no Markdown, no link, and nothing that only makes sense after the title or next to the body.
- **Table of contents.** From 80 rem (1280 px) the page's headings are the right rail, where the current heading's entry is bold and barred. Below 80 rem the rail is hidden, and the page's h2 headings are listed under its entry in the sidebar (the phone menu below 48 rem).
- **Section index pages list their children as generated cards** (`site/layouts/_partials/opm/section-children.html`): subsections first, then pages grouped by type (tutorials, how-to guides, explanations, reference), each group ordered by `weight`, then title. Nobody writes a child list by hand, in a site-owned overview or a source page.
- **Search** indexes only `main#content > .content`. Three things there are deliberate: the lead is indexed and is the page's Pagefind `description` metadata (the search sub-line); the section cards carry `data-pagefind-ignore`, so a section page does not match every child; and the `crumbs` metadata starts below the docs root, so no result reads "Documentation / ...". A change to the markup under `.content` keeps all three true and keeps `task qa`'s search smoke test green.
- **Reference is its own tab.** Its pages keep their `/docs/reference/` URLs, but the sidebar treats the section as a separate tree (`site/layouts/_partials/sidebar.html`): a reference page shows only the Reference tree, and every other docs page's tree, like the docs home's cards, leaves it out. The navbar marks only the Reference tab current there (`site/layouts/_partials/navbar-link.html`, an override pinned in `overrides.sha256`). The build records both trees, `nav-order.txt` and `nav-order-reference.txt`.
- **Breadcrumb.** It is a `nav` landmark holding a list, with the current page marked `aria-current="page"`. The crumbs wrap instead of clipping; below 48 rem the docs-root crumb is hidden, since the sidebar's first row and the navbar's Docs link already lead there.
- **Two theme override copies exist only for these fixes**, each pinned in `site/overrides.sha256`. Delete each, and its line, when upstream Hextra fixes the problem:
  - `site/layouts/_partials/breadcrumb.html`: Hextra's breadcrumb is a `div` of `div`s with no `nav`, no list and no `aria-current`, and it clips crumbs on a phone.
  - `site/assets/js/core/sidebar.js`: Hextra always scrolls the sidebar to put the current page near its top, so the phone menu opened scrolled past the section root. The copy scrolls only when the current page's entry is out of view.

## Brand marks

- **The mark is a placeholder** until the owner picks a mark; replace `site/static/images/opm-mark*.svg` (and `site/static/favicon.svg`, the same mark on its tile) and run `task brand:favicons brand:og`. The placeholder is a rounded tile with an O knocked out, outlined as two ellipses fitted to the O of Geist ExtraBold.
- **Drawn sources.** Three hand-written SVGs: `site/static/images/opm-mark.svg` (the mark in `#0a0a0a`, for the light theme), `site/static/images/opm-mark-dark.svg` (the same path data in `#fafafa`, for the dark theme) and `site/static/favicon.svg` (the mark in `#fafafa` on a `#0a0a0a` rounded tile, the same colours in every theme). A redraw edits all three.
- **Generated files.** Every raster is generated and never hand-edited. `task brand:favicons` writes, from `favicon.svg`, `site/static/favicon-16x16.png`, `favicon-32x32.png` and `favicon.ico` (16, 32 and 48 px frames), and `apple-touch-icon.png`, `android-chrome-192x192.png` and `android-chrome-512x512.png` (opaque: the favicon at 6/7 of the icon on a full-bleed tile-coloured square). `task brand:og` writes `site/static/images/og-default.png`, the 1200x630 Open Graph card, from `site/tools/og-card.html`. Both run `site/tools/*.py` in the QA image with no network; the site build never runs them, and their output is committed.
- **The mark brief.** Original, drawn from simple geometry for OPM; not traced or adapted from an icon set, and not Hextra's hexagon, the Kubernetes wheel or the CUE logo. One ink at full opacity: shapes are separated by gaps, never by tints or opacity. A square `viewBox="0 0 24 24"` with no stroke, gap or feature narrower than 2.5 units, filled shapes preferred. Legible at 16 px on the tile, 24 px in the navbar, 64 and 512 px, in both inks. Only `<svg>`, `<path>`, `<rect>`, `<circle>`, `<polygon>` and `<g>`, one `xmlns`, no `<text>`, `<style>`, `<script>`, `href`, comments, `xlink` or editor namespaces, and under 1 KB. The brief is for the real mark; the placeholder breaks two of its rules on purpose (it is a tile, not an original drawing, and it carries a comment naming it a placeholder).
- **Favicons replace the theme's by name.** Hextra's `favicons.html` links `favicon.ico`, `favicon.svg`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png` and `site.webmanifest`, and its manifest names the two `android-chrome-*.png` icons. Same-named files in `site/static/` win over the theme's, so no theme file is overridden. There is deliberately no `favicon-dark.svg`: the tile carries its own contrast on light and dark tab strips, and without that file Hextra's favicon swap stays off. A Hextra re-pin that changes this set is not caught by the drift guard; check it against `favicons.html`.
- **The wordmark is text.** The navbar title is the live site title, typeset in `site/assets/css/opm/brand.css` (Geist, weight 600, -0.01em tracking) through the hooks `opm-brand`, `opm-title-long` and `opm-title-short` in `site/layouts/_partials/navbar-title.html`, never through Hextra's `hx:` classes. The mark beside it is set by `params.navbar.logo` in `site/config/_default/hugo.toml`.
- **Keep the card current.** Rerun `task brand:og` when `title` or `params.description` in `hugo.toml` changes, and both tasks after a redraw.

## License

Apache 2.0
