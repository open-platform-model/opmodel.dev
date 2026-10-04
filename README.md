# opmodel.dev

Documentation site for the Open Platform Model, built with [Hugo](https://gohugo.io/) and the [Hextra](https://github.com/imfing/hextra) theme (v0.13.0, neutral skin).

## Overview

This repository contains:

- **`site/`** - the Hugo site: configuration, the site-owned pages (the landing and the section overviews), layouts and theme overrides, styles, the vendored theme, build scripts, the build image and the tests.

Most pages do not live here. Each of six repositories (opm, core, catalog_opm, cli, library, opm-operator) keeps its pages in `docs/site/`, generates its reference pages from source in its own CI (the CLI's commands, the operator's resources, core's definitions, the library's Go API), and publishes both in its signed docs bundle; a site version reads every one of them from those bundles (see "Docs bundles in a site version" under Site versions), and the build reads no repository but this one. The catalog's members come the same way: catalog_opm publishes them as signed docs bundles, one per release and one for `main`, which the site pulls and builds as the unversioned Catalogs tab at `/catalogs/` (see "The Catalogs section" under Site versions). The enhancements repository, OPM's design record, is built in the same run from its section bundle as one unversioned section at `/enhancements/` (see "The Enhancements section" under Site versions).

## Architecture

```text
site/content/             (landing and section overviews, dated on the host from this repository's git)
site/.bundles/            (signed docs bundles, task bundles:pull from ghcr.io/open-platform-model/docs:
                           each site version's docs projects, the Catalogs tab, the Enhancements section)
        |
        v
  drift guard -> docs bundles -> dates, mounts, page-set checks
        -> hugo build (Hextra, vendored) -> output checks -> Pagefind per version and catalog minor
        |
        v
  site/public/   /v1.0/...   /latest/ -> /v1.0/   / -> /latest/   /enhancements/...
                 /catalogs/opm/<MAJOR.MINOR>/...   /catalogs/opm/edge/...   /catalogs/opm/<MAJOR>/ -> newest minor
```

Everything runs in Docker. The build image (`site/Dockerfile`) holds Hugo 0.167.0, Pagefind 1.5.2, opm-docs 0.7.0 (docs-kit), git and jq, each pinned; a build runs with no network, and only `task bundles:pull` runs `opm-docs` with it. The QA image (`site/tests/browser/Dockerfile`) holds Chromium, Playwright and axe-core for the screenshots and the smoke tests. Image tags come from the Dockerfile hashes (`opmodel-dev-hugo:<12 hex>`, `opmodel-dev-qa:<12 hex>`).

There is one version, `v1.0` (beta): the docs bundles of the newest cli `1.0` release and of exactly the library, core and opm-operator releases it pins, opm's newest 1.0 release, and catalog_opm's `docs/site` from the newest `opm-v4` catalog release (its `catalog-opm-docs` bundle), resolved again on every pull (see Site versions). Every version lives under `/<version>/`; `/latest/` points at the default version and `/` at `/latest/`. How versions map to component releases is an open question (enhancement 0021:OQ15).

## Prerequisites

- Docker
- [Task](https://taskfile.dev/)
- git
- jq, for the host steps (the site-owned pages' dates, the two-version test)
- The OpenSpec CLI, for `task check`

No other repository needs to be on disk: every source page comes from a signed docs bundle.

## Quick Start

```bash
# Full build with every check into site/public/, then serve it. The build reads the
# docs bundles of the last pull; pull again after a release (task bundles:pull build).
task bundles:pull
task build
task preview

# Dev server with live reload of the site-owned pages and layouts, over the same bundles
task serve

# Every repository's main together, as CI's sources-main job checks it (not published):
# every repository from its edge docs bundle
task build:edge
```

The first run builds the image, which needs the network, as `task bundles:pull` does. `SITE_PORT=1314 task serve` takes another port for serve and preview.

A source repository's pages are previewed through their bundle, never from a checkout: `opm-docs serve` in that repository renders them alone with live reload, and `OPM_BUNDLES_LOCAL="<project>@v1.0=<repo>/out/<project>" task bundles:pull serve` shows them in this site (after `task docs:bundle`, or `opm-docs build`, in that repository; a checkout whose `origin` is the GitHub repository, since the bundle's `source.repo` comes from it). `OPM_BUNDLES_LOCAL="core@v1.0=<core>/out/core" task build:edge` checks a product's branch against every other `main`. A local pull stays in the lock until the next pull: run a plain `task bundles:pull` before a `task build` meant to show the released pages (the footer marks a local bundle `local`).

## Directory Structure

```text
opmodel.dev/
├── site/
│   ├── Dockerfile              # Build image: Hugo, Pagefind, opm-docs, git, jq
│   ├── bundles.cue             # The docs bundles: the site versions and their docs projects, the Catalogs tab, the Enhancements section (task bundles:pull)
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
│   ├── versions.conf           # Each site version's label, weight and default (see Site versions)
│   ├── scripts/                # Build, checks, dev server, vendoring, host-side runner and dates
│   ├── tools/                  # Brand rasters: favicons.py, og-card.{py,html} (task brand:*)
│   └── tests/                  # Fixture bundles, check cases, dialect pages, base-path build, browser QA, two-version test
├── Taskfile.yml
└── README.md
```

## Tasks

```bash
task serve             # Dev server on http://127.0.0.1:${SITE_PORT:-1313}/ over the docs bundles of the last pull
task build             # Build and check the site into site/public/ from the docs bundles of the last pull (no network)
task build OPM_BASE_URL=<url>  # The same, for another base URL (a path allowed); qa, shots and preview use the root
task build:edge        # Every repository's main together: every repository's edge docs bundle (CI's sources-main; not published)
task preview           # Serve the built site/public/ on SITE_PORT
task test:site         # Prove every check fails when it should (fixtures), then task versions:test
task shots             # Build, then screenshot every figure page and the extras, and check every Enhancements diagram, into site/.shots/
task qa                # shots, the axe accessibility, search and theme switch smoke tests
task ci                # check, image, build, test:site
task check             # openspec validate
task image             # Build the site's image if its tag is missing
task qa:image          # Build the QA image if its tag is missing
task brand:favicons    # Regenerate the favicon PNGs and favicon.ico from the drawn SVGs
task brand:og          # Regenerate the Open Graph card, site/static/images/og-default.png
task bundles:pull      # Pull, verify, lint and unpack every docs bundle of site/bundles.cue into site/.bundles/ (network)
task versions:test     # A two-version build (v1.0 from the pull, a fixture v0.9) into site/.check/versions-test/
task clean             # Remove generated files
```

## CI

The `Site` workflow (`.github/workflows/site.yml`) builds and tests the site on every pull request to `main`, on every push to `main`, nightly at 03:23 UTC, and on demand (`workflow_dispatch`). Its `build` job runs the Taskfile targets you run locally:

| CI step | Local equivalent |
|---|---|
| Lint the workflows | `task ci:lint`: actionlint, with its bundled shellcheck, from a digest-pinned image (`task ci:lint -- -verbose` names each file) |
| Pull the docs bundles | `task bundles:pull`: anonymous, no token; the `browser` job waits for `build` and pulls its lock frozen: `OPM_BUNDLES_FROZEN=<lock> task bundles:pull` |
| Check, build and test the site | `task ci`: `check`, `image`, `build`, `test:site` |
| The build leaves the tree clean | `task ci`, then `git status --porcelain` |
| Source pages on main (the `sources-main` job, not published) | `task build:edge` (every repository comes from its `edge` docs bundle) |
| Build for GitHub Pages (interim) | `OPM_BASE_URL=https://open-platform-model.github.io/opmodel.dev/ task build`, after the steps above (see GitHub Pages (interim) below) |

- **Clean tree.** CI fails when `task ci` leaves the tree dirty, `.task/` excluded (Task's checksum files; one of them is tracked). For example, a build step wrote a file that is not gitignored.
- **Checkout layout.** Every job checks out only opmodel.dev, with `path: opmodel.dev` under `$GITHUB_WORKSPACE`: every source page comes from a signed docs bundle, so no job reads another repository. The `build` and `browser` jobs fetch its full history (`fetch-depth: 0`) for the site-owned pages' dates; `sources-main` checks it out shallow. `gen-site-dates.sh` dates no page in a shallow clone (one commit would date them all), so a lost `fetch-depth: 0` fails the dates check below. Every checkout sets `persist-credentials: false`: no step pushes, so no clone keeps a token that the build containers could read.
- **Dates.** The workflow sets `OPM_REQUIRE_DATES=1`, so a site-owned page without a git date fails the build. `site/scripts/gen-site-dates.sh` dates them on the host before the build container starts (`task build` and `task serve` run it), so a local build passes the same check, from worktrees too: `OPM_REQUIRE_DATES=1 task build`. Every other page is dated by its bundle's manifest. `task test:site` sets it back to 0 for its fixtures.
- **Summary and artifacts.** The job summary names the opmodel.dev commit and lists every docs bundle the build read from `site/public/build-stamp.json`: the Enhancements section (ref, commit, digest), a Catalogs table (project, segment, version, revision, digest, commit) and a Docs bundles table per site version (project, role, tag, version, revision, digest, commit, pins), and the number of files in `site/public/`. The `bundles-lock` artifact holds the lock the build read and `build-stamp` the stamp, both for 90 days (the `browser` job pulls that lock frozen), and `site-public` the whole `site/public/` for 14 days; the stamp and the lock are the build's record (Site versions, "The record"). After those uploads, the GitHub Pages build adds one summary line with its file count and uploads its tree as the `github-pages` artifact, kept for one day; a deploy adds a summary naming the deployed URL.
- **Browser job.** The `browser` job runs `task qa`, as you do locally, after `build`, on exactly the docs bundles `build` read (its `bundles-lock` artifact, pulled `--frozen`), so QA checks what deploys: it builds the site itself, takes the screenshots in six variants, fails when figure text drops below 9 px at phone width, and runs the axe WCAG 2.1 A and AA smoke test and the search smoke test, all in the QA image with no network. The `site-shots` artifact holds `site/.shots/` for 7 days from every run that got as far as taking screenshots, a failed run's included: when an accessibility or search test fails in CI, the screenshots show why. Its upload sets `include-hidden-files: true`, because `actions/upload-artifact` skips every file under a directory whose name starts with a dot, and `.shots` is one.
- **Pins.** Every action is pinned by full commit SHA, with its version in a comment. Task is pinned to an exact version (3.52.0), the openspec CLI to 1.12.0, and the `ci:lint` task pins actionlint by image digest. Nothing floats: bump each on purpose.
- **Concurrency.** It is set per job, one group per job (`<workflow>-<ref>-<job>`), and a newer run cancels the older run's job. It is never set at workflow level, which would cancel a deploy job with the rest of a run; and two jobs never share one cancelling group, because they would cancel each other. A deploy job uses its own group, without `cancel-in-progress`. The `opmodel.dev` working directory is a per-job `defaults` entry for the same reason, never workflow-level: a deploy job runs a step before its checkout.
- **Source repositories.** Every pull resolves v1.0's release lines again, so the nightly run of `main` publishes what moved upstream within about a day, and `gh workflow run Site --ref main` publishes it at once; no source repository dispatches a run. What reaches the published build: new releases (a cli release's docs bundle with the bundles of the library, core and opm-operator releases it pins, an opm release's docs bundle in its 1.0 line, every `opm-v4.*` catalog release with its docs bundle, and a docs revision of any of them). The `sources-main` job keeps the early warning for all six: it runs `task build:edge`, which reads every repository from its `edge` docs bundle (each publishes one on every push to `main`, its generated reference included), its pull lints every page in bundle mode (opm-docs), and the build runs every check and the link crawl over them together, so a `main` that breaks a cross-repository link or publishes a colliding page fails here before its next release. A product with no `edge` bundle fails the job (exit 2, naming the repository). It waits for no job, fails unless the build stamp shows all six read from pulled `edge` bundles, uploads only the `edge-lock` artifact (the edge lock, 7 days, also after a failed build; `OPM_BUNDLES_FROZEN=<that lock> task build:edge` replays it) and lists the edge entries and catalog segments in its summary, with a warning when an edge bundle's commit is not its repository's `main` head (`git ls-remote`; a failed or lagging edge publish, so that `main` went unchecked); `pages-deploy` does not wait for it. It must never become a required status check: it reads other repositories' moving `edge` bundles, so it turns red for reasons no opmodel.dev pull request can fix, and while a committed `site/bundles.frozen.json` pins a bad catalog bundle for the published build it stays red, because the edge pull resolves the Catalogs tab fresh. v1.0 reads no branch head, so only `sources-main` catches a broken `main`. A new release whose bundle fails the pull or the build turns every run red and holds the deploy until it is recovered (Site versions, "When a bundle fails"). GitHub disables a scheduled workflow after 60 days without repository activity (re-enable it on the Actions tab), and it mails a scheduled run's failure to whoever last edited the cron line.
- **Pull request titles.** The `PR Title` workflow (`.github/workflows/pr-title.yml`) fails a pull request whose title is not a Conventional Commit with this repository's types (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `build`, `ci`; the "Commit Standards" in `openspec/config.yaml`) and a lower-case subject. The squash merge keeps a single commit's subject, but a pull request with several commits, as every OpenSpec change has, lands on `main` under its title. The workflow runs on `pull_request_target`, which reads the workflow from `main`, so a change to it first applies to the pull request after it merges.

### GitHub Pages (interim)

Until the Cloudflare deploy replaces it, the site is published at https://open-platform-model.github.io/opmodel.dev/. It is public and linkable, but interim: the documentation is not finished, and the address goes away when the site moves to `opmodel.dev`.

**What and when.** The `build` job builds the site a second time for that URL (`PAGES_BASE_URL` in the workflow, passed to `task build` as `OPM_BASE_URL`), from the same docs bundles, dates and checks, and uploads it as the `github-pages` artifact on every run, pull requests included. The `pages-deploy` job publishes that artifact on pushes to `main`, the nightly run and manual runs of `main`, and only after `build` and `browser` pass (`needs: [build, browser]`). It never runs on a pull request, and the `github-pages` environment allows only `main`. Every HTML page of this build carries `<meta name="robots" content="noindex, nofollow">`, because its host is not `opmodel.dev` (`params.opm.indexedHost`).

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
# the opmodel.dev commit and every docs bundle the build read, as in the run's job summary
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

The site versions are `site/bundles.cue`'s `versions`: each names the docs bundles that make up that version's pages (see "Docs bundles in a site version" below), and `task bundles:pull` resolves them into the lock. The build reads no repository but this one. `site/versions.conf` only says how each version is shown, and must name exactly the versions the lock names (the build fails otherwise, naming both lists):

```ini
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
```

`label` is the switcher's text, `weight` its position (a positive integer, one per version), and exactly one version has `default = true`: `/` and `/latest/` go to it. Any other section or key fails the build. The file is read as a strict subset of git-config syntax (comment lines, `[version "<name>"]` headers, `key = value` lines), without git, since the build container cannot run git inside a worktree. `OPM_VERSIONS_CONF=<path under site/>` selects another file for one build (the two-version test).

With `site/bundles.cue`'s `versions."v1.0"` (`anchor: {project: "cli", tag: "1.0"}`, `pinned: ["library", "core", "opm-operator"]`, `tags: {"opm": "1.0", "catalog-opm-docs": "4"}`), v1.0 reads the newest cli release in 1.0 and exactly the library, core and opm-operator releases its bundle's `manifest.json` pins, opm's newest release in its own 1.0 line (opm's minor follows the site version, docs-kit DESIGN decision 21; the cli pins no opm), and `catalog-opm-docs` (catalog_opm's `docs/site`) at the catalog's major `4`, its newest `opm-v4.*` release. They are resolved again on every pull, the nightly one included, so a new release reaches the site with no commit here (the owner chose release lines over a fixed anchor bumped by commit on 2026-10-01). A docs fix in any repository reaches v1.0 through its next release or a docs revision of the released version (`mode: revision` in its `Docs` workflow), not at the next site build; catalog_opm hides `docs` commits from its releases, so a catalog_opm docs fix reaches v1.0 only through a hand-dispatched `catalog-opm-docs` revision (catalog_opm#130 tracks automating it); the `/docs/` landing and Start here are opm's pages, so they move the same way. A new cli line or catalog major is a commit to `site/bundles.cue`.

**The record.** Every build records what it read: `site/public/build-stamp.json` holds `site` (this repository's commit, resolved on the host), `versions.<v>.bundles` (each docs bundle's project, role, tag, version, revision, digest, commit and the anchor's pins) and `sections` (the Enhancements and Catalogs bundles); the footer names the bundles of the page's version; CI uploads the lock as `bundles-lock` and the stamp as `build-stamp`, each kept 90 days. To rebuild the same pages, check out opmodel.dev at the stamp's `site`, copy that run's lock to `site/bundles.frozen.json` and run `task bundles:pull build`.

**When a bundle fails.** A new release whose bundle fails `opm-docs pull` (a signature, the lint, a collision, a missing pin) or the site build (a page-set check, a link) turns every run red, pushes, pull requests and the nightly alike, until it is recovered; the deployed site stays at the last good deploy. Commit the last good run's lock (its `bundles-lock` artifact, kept 90 days) as `site/bundles.frozen.json`: `task bundles:pull` then pulls exactly those digests (`--frozen`, signatures and lint still checked) until upstream publishes a fix and the file is deleted. Never loosen a check.

The site-owned pages (`site/content/`) are built into every version, so every link on them must resolve in every version.

### The Catalogs section

The catalog reference is a tab of its own, outside the site versions: `/catalogs/opm/<MAJOR.MINOR>/` for every opm minor from 4.5 on (the first release after catalog_opm adopted docs-kit; there is no backfill) and `/catalogs/opm/edge/`, labelled "main (unreleased)". Each comes from one signed OCI docs bundle that catalog_opm's CI publishes through docs-kit's reusable `publish.yml` (`ghcr.io/open-platform-model/docs/catalog-opm`). `site/bundles.cue` names the tab (docs-kit contract C7): its `repo`, its `root` and `from`, the oldest minor shown. `task bundles:pull` runs `opm-docs pull` in the build image, the one step besides the image builds that reaches the network: it resolves every minor tag at or above `from`, and `edge`, and accepts a bundle only when its Sigstore signature names docs-kit's `publish.yml` at a `refs/tags/v[0-9]*` ref as the signer and `open-platform-model/catalog_opm` at `refs/heads/main` as the source (C9); it unpacks into `site/.bundles/` and writes `site/.bundles/lock.json`. A new minor or a new `edge` build reaches the site at the next build, with no commit here. The lock is never committed; the build stamp (`sections.catalogs`) records it and every bundle's digest and commit. `task build` never pulls: it fails without a lock pulled for the current `bundles.cue` (naming `task bundles:pull`); `OPM_BUNDLES=<dir>` builds from a saved unpacked tree instead. A lock with no tab bundle builds no Catalogs section and no tab. `opm-docs` is pinned by version and by the SHA-256 of its `linux_amd64` archive in `site/Dockerfile` (the line in that release's `checksums.txt`, checked against a second download). The site bumps first (docs-kit C12): a producer (catalog_opm, core, cli, opm-operator) moves its `.opm-docs-version` to a docs-kit release only after `site/Dockerfile` pins that release or a newer one, since an older `opm-docs` refuses a bundle or lock field it does not know.

Every minor and `edge` has its own sidebar, its own Pagefind index, and a switcher on every page (newest first, `edge` last) that keeps the reader on the same page, else its nearest parent, else the landing. The landing of each minor is catalog_opm's contract page followed by the generated `## Catalog members` block (`#catalog-members`). `/catalogs/opm/` and `/catalogs/opm/<MAJOR>/...` are aliases of the newest minor (of that major), as `_redirects` lines and as `noindex` meta-refresh stubs; `edge` has none. Only the newest minor of each major is indexed and listed in `llms.txt` and the sitemap; older minors and `edge` are `noindex`.

**Version history.** `opm-docs pull` also writes `site/.bundles/catalog-opm/history.json` (docs-kit contract C13), which compares the segments it pulled, and records its SHA-256 in the lock's `history` key. The site reads that file and never computes history itself. `gen-catalogs.sh` checks it against the lock and fails the build when the digest differs, the file is missing, or the file holds a value C13 does not allow; recovery is a fresh `task bundles:pull`, never an edited file. A file the lock does not record (left by an older pull) is ignored. From it, a member page shows badges beside its type badge ("Added in X", "In <floor> or earlier", "Unreleased", "Changed in X" for its own segment, "Newer version" linking the newest apiVersion's page in that segment), and a page-end "Changes in X" section lists its field changes, one line each, worded as C13 words them and more cautiously for a pair compared by field paths only. A kind index lists the members removed in its segment under "Removed in X", each linking its page in the last segment that had it; a kind with no index left lists them on the segment's landing. Field changes appear only in that list, never inside the spec block, which is a code fence the bundle publishes as built. Both sections are Markdown the adapter appends to the page body, so the table of contents and the `.md` output carry them; a Removed link carries the title `opm:removed`, which lets it name another segment only when it matches one of the page's own removals. The fixtures in `site/tests/fixtures/bundles/` include the history the pinned `opm-docs` writes for them.

`/catalogs/` is a picker: one full-width card per catalog, stacked at any count, and one sidebar entry per catalog, both generated (`site/layouts/_partials/opm/catalog-entries.html`, `catalog-picker.html`). A card's title, `<name> catalog`, links the newest release (`edge` for a catalog with no release yet), and the card also shows the CUE module path and the member kinds with counts (from the bundle's `data/catalog.json`, when it carries one), the repository, and a link to `edge` as "main (unreleased)". It shows only facts the bundles carry. The catalog's one-line description exists at its source (core's `#Catalog.metadata.description`, which catalog_opm fills), but docs-kit's cue-catalog extractor does not yet copy it into `data/catalog.json`; the card shows it once the extractor writes `description` there. A display name waits on a tab-only `placement.title` in docs-kit's manifest; `#Placement` is closed, so the site must accept the field before any bundle carries it. `gen-catalogs.sh` marks the page `params.picker: true`, which `opm/docs-main.html` and `sidebar.html` key on. In HTML the cards replace the page body; the body `gen-catalogs.sh` writes (the description sentence and one line per catalog with both links) feeds only the page's Markdown twin. `task test:site` (`catalogs/picker`) fails when a catalog has no card or sidebar entry linking its newest release.

An author previews a local catalog build with `OPM_BUNDLES_LOCAL="catalog-opm@4.5=<release build> catalog-opm@edge=<catalog_opm>/out/catalog-opm" task bundles:pull build` (`opm-docs build` outputs, `--release opm-v4.5.1` and the default edge; one pair per segment, space-separated). A local project skips the registry entirely, so name a release minor of every major the docs link (`/catalogs/opm/4/`), or those links fail the build. A pull whose every tab is local runs with no network, and the stamp marks those bundles `local`. When a newly published bundle breaks the build (it fails `pull`'s lint or a site check), commit the last good run's `bundles-lock` artifact as `site/bundles.frozen.json`: `task bundles:pull` then pulls exactly those digests (`--frozen`, signatures still checked) until the file is deleted, and the stamp and the CI summary say the bundles are frozen. `opm-docs` refuses a frozen lock once `site/bundles.cue` has changed (the lock's `config` digest must match), so take a lock pulled for the current file. A frozen pull still fetches the blobs and the Sigstore trusted root, so it is no way around a GHCR or Sigstore outage: an outage fails `task bundles:pull` and every site build, and is waited out.

The tab replaced catalog_opm's Reference copies of the members (`reference/catalog-members/` and `reference/catalog-contract.md`), which catalog_opm deleted on 2026-10-03; their old URLs get no redirects. A version whose `catalog-opm-docs` bundle is older and still holds them publishes them like any page, so its own links to them resolve there; the build neither hides them nor maps those links to the tab.

The fixtures in `site/tests/fixtures/bundles/` are three bundle trees (`catalog-opm` 4.4, 4.5 and `edge`) plus the `history.json` and the lock an all-local pull writes over them. `task test:site` first re-pulls them with the pinned `opm-docs`, offline (`--local`), and fails unless the result is byte-identical, lock included; every fixture build then reads that pulled copy. A fixture edit regenerates `lock.json` with the same pull.

### Docs bundles in a site version

Every page of a site version outside `site/content/` comes from a source repository's signed docs bundle (docs-kit contracts C15, C16): the generated reference and the authored `docs/site/` pages together, as the repository published them for a release. `site/bundles.cue` names the docs projects under `docs` (`cli`, `core`, `library`, `opm-operator`, `opm`, `catalog-opm-docs`, each with the only repository allowed to sign it) and, under `versions`, what each site version pulls: an `anchor` project at a tag (`cli` at `1.0`, its newest release in that minor), the `pinned` projects at exactly the versions the anchor's `manifest.json` pins, so a version shows the docs of what its cli pins (docs-kit DESIGN decision 10), and the projects under `tags` at their own tag (`opm` at `1.0`, its newest release in that minor: the cli pins no opm, and opm's minor follows the site version, docs-kit DESIGN decision 21; `catalog-opm-docs` at the catalog's major `4`, its newest `opm-v4.*` release, a second project of catalog_opm beside its Catalogs tab, docs-kit C1 and C15). `opm-docs pull` resolves and verifies them like the tab bundles, lints every page in bundle mode (docs-kit C11), refuses two bundles that publish one page or own nested paths, and unpacks them to `site/.bundles/_versions/<v>/<project>/` with `docs` entries in the lock; the site never resolves a pin itself.

The lock decides: a version's pages are the bundles its `docs` entries name. `gen-docs-bundles.sh` writes `data/opm/docs-bundles.json` from the lock and the manifests, and fails the build on a lock or manifest that disagree, a manifest `source.repo` other than the `repo` `bundles.cue` names for its project, a placement other than `docs`, or a page under `content/` the manifest does not list. Each bundle's `content/` is mounted at that version's `content/docs`, and the page-set checks (A1, Q2) and the link crawl cover the bundle pages with the site-owned ones, which is where a `/docs/` link from one bundle into another is checked (C15 leaves it to the site).

A bundle page's links come from its manifest (docs-kit C8): "Edit this page" goes to `https://github.com/<source.repo>/edit/main/<edit>` when the page has an `edit` path (an authored page whose file `main` still has), on every version, because it names `main`, where a fix lands (docs-kit DESIGN decision 19); a generated page has none. "View source at <release>" goes to the page's `source` at the bundle's commit. "Last updated" and the sitemap's `lastmod` are the manifest's `lastmod`; a page without one shows no date. The footer names each bundle's version ("docs bundles cli 1.0.0-beta.7, ..."), and `build-stamp.json` lists them under `versions.<v>.bundles` with roles, tags, digests and the anchor's pins; the CI summary prints them. A docs fix reaches a bundle-backed version through that repository's next release or a docs revision (`mode: revision` in its `Docs` workflow, docs-kit DESIGN decision 9), never at the next site build.

**The edge build.** `task build:edge` (CI's `sources-main` job) checks every repository's `main` together. `site/scripts/edge-config.sh` derives `site/.edge/bundles.cue` from `site/bundles.cue`: every top-level block kept in order, `versions` replaced by one site version, `"v1.0"`, whose anchor is `cli` at `edge` and whose `tags` put every other `docs` project at `edge`, so a project that joins `docs` needs no edit here. The pull (`OPM_BUNDLES_CONFIG=site/.edge/bundles.cue OPM_BUNDLES_OUT=site/.edge/bundles`) writes its own directory, never the `site/.bundles/` that `task build` reads, and skips a committed `site/bundles.frozen.json` (pulled for `bundles.cue`); `OPM_BUNDLES_OUT` must be a dot-directory under `site/`, since the pull removes whatever it did not write there; then the build reads every repository from those bundles (`OPM_BUNDLES=site/.edge/bundles`). A missing edge bundle fails the pull (exit 2, naming the repository), with no fallback to git. It is CI-only, never a published version: the site's version set, URLs, sitemap and switcher do not change, and its `site/public/` is discarded (openspec `add-edge-build`, Decision 2, has what a published `/edge/` version would need). A local preview of a bundle names a site version's project as `<project>@v<M>.<m>`: `OPM_BUNDLES_LOCAL="cli@v1.0=<cli>/out/cli ..." task bundles:pull build`; a pull runs with no network only when every tab and every docs project of every site version is local. The fixtures in `site/tests/fixtures/bundles/_versions/v1.0/` are the six docs bundles of v1.0 (cli the anchor with pins, opm and catalog-opm-docs by their own tags), pulled offline with the tab fixtures; every fixture build reads them, and `site/tests/bundle-page.sh` adds or drops a page, drops the tabs or adds a version on a test's copy.

### The Enhancements section

The enhancements repository's section bundle is an input that belongs to no version (docs-kit C21). `site/bundles.cue` names it under `sections` (`"enhancements": {repo: "open-platform-model/enhancements", root: "/enhancements/"}`), and `task bundles:pull` resolves only its `edge` tag, verifies the signature (the enhancements repository at `refs/heads/main`), lints every page in bundle mode, markup check included, and unpacks it to `site/.bundles/enhancements/edge/` with a lock entry rooted at `/enhancements/`. A merge there reaches the site after its `edge` publish, at the next build. The producer builds every page: it strips HTML comments and the title line, gives every unlabelled fence `text`, resolves every relative link (an entry or document to its `/enhancements/` page, any other path to GitHub at the commit built), reads a file-name link text as the target page's title, and refuses what the site would execute. The site never rewrites a page. The build stamp (`sections.enhancements`: ref `edge`, the bundle's commit and digest), the footer, View source and the CI summary name the bundle's commit. A build without the lock entry has no section and no Enhancements tab. The fixture `site/tests/fixtures/bundles/enhancements/edge/` is what `opm-docs build` writes from `site/tests/fixtures/ws/enhancements/` committed as one commit (fixed author and dates, `origin` the enhancements repository) with a `docs-kit.cue` holding the C21 entry. `sh site/tests/fixtures/regen-enhancements.sh` rebuilds it (in the build image, offline); run it after a fixture edit, then re-pull the fixture lock. `task test:site` rebuilds it into a scratch directory and fails unless it is byte-identical (`enhancements/fixture-regen`).

The content adapter `site/enhancements/_content.gotmpl` reads the bundle's `manifest.json`, `content/` and `data/enhancements.json`, is mounted into the default version only and gives every page a `url` (a bundle page cannot carry one: the dialect forbids the key), so the section publishes once, at `/enhancements/`, outside `/<version>/`, and keeps its URLs when the default version changes. URLs are keyed by entry id, so archiving an entry keeps them: `/enhancements/` (the bundle's `content/_index.md`, written by `gen-mounts.sh` as `.gen/enhancements/_index.md` with its `url` and params, since an adapter cannot add a section page), `/enhancements/graph/`, `/enhancements/NNNN/` (the README, with a header from its `data/enhancements.json` entry) and `/enhancements/NNNN/{problem,design,decisions,graduation,risks,operational,questions}/`. A decision heading `D3: ...` also carries the anchor `#d3`. Every page carries a status banner; draft and accepted entries carry `noindex`; no section page is in `llms.txt`, a sitemap, the `/latest/` stubs or the docs search (the section has its own Pagefind bundle, `/enhancements/pagefind/`). A `/docs/` or `/enhancements/` link resolves through the site's link hook like a docs page's, and a miss fails the build. `gen-mounts.sh` fails the build on a bundle whose placement is not the section at `/enhancements/`, whose `content/` and `manifest.json` disagree, or whose entry page has no `data/enhancements.json` entry. A Mermaid fence in the section is drawn by Mermaid 11.17.2, vendored as `site/assets/lib/mermaid/mermaid.min.js` (its licence beside it, `site/NOTICE`) and pinned with its version, source and SHA-256 in `site/vendored.sha256`, which `site/scripts/check-vendored.sh` checks before every build; a re-vendor is a new download verified at its source, never a re-pin of what is on disk. Hextra loads it fingerprinted, with SRI, only on a page that holds a fence. The section's hook (`layouts/enhancements/_markup/render-codeblock-mermaid.html`) draws each diagram at its natural size (`useMaxWidth: false`) in a box that scrolls sideways and takes the keyboard focus, since fitted to the column most labels would shrink under 9 px; in the dark theme the edge labels get a darker box (`enhancements.css`), as Mermaid's own fails WCAG AA. `task shots` and `task qa` run `site/tests/browser/diagrams.py`, which draws every diagram of the section in the browser and fails on a Mermaid error, a label under 9 px or a label under AA contrast in either theme (and first proves it catches a broken and a squeezed diagram); its PNGs go to `site/.shots/diagrams/`.

`task versions:test` (part of `task test:site`) builds two versions into `site/.check/versions-test/`, never `site/public/`: `v1.0` from the real docs bundles of the last `task bundles:pull` (run it first; the test fails naming it otherwise) and `v0.9` from the fixture docs bundles relabelled, with `site/tests/versions/two-versions.conf` as `OPM_VERSIONS_CONF`, and checks that each publishes its own bundles' pages, the switcher, the redirects, one Catalogs and one Enhancements section outside both, and the stamp.

## Implementation Status

- [x] Hugo + Hextra site, built and served in Docker with no network
- [x] Pages assembled from six source repositories' signed docs bundles, in one page dialect that `opm-docs pull` lints
- [x] Build checks: drift guard, front matter, links, page set, stray files, planning comments, supply chain, redirects, dates
- [x] Per-version Pagefind search in Hextra's palette; `/latest/` and root redirects
- [x] Browser QA: screenshots in six variants, WCAG 2.1 A and AA smoke test, search smoke test, theme switch smoke test
- [x] The theme switch animates with the View Transitions API: a circular reveal from the pointer, a short cross-fade for the keyboard and the OS, nothing under reduced motion (`site/assets/js/opm-theme-transition.js` wraps Hextra's `setTheme`; `site/tests/browser/theme_reveal.py` guards it)
- [x] All nine figures of the page dialect, drawn as inline SVG that follows the site's theme toggle
- [x] Generated reference pages (cli, core, library, opm-operator), read with each repository's authored pages from its signed docs bundle
- [x] Versions from `site/bundles.cue`, shown as `site/versions.conf` says, with a two-version regression test
- [x] `v1.0` follows the cli 1.0 line through its docs bundle and its pins, opm's 1.0 line and the catalog's major 4, with every bundle digest recorded per build
- [x] The Catalogs tab, built from signed docs bundles per opm minor and `edge`
- [x] Catalog version history: badges, "Changes in" and "Removed in" sections, read from the history `opm-docs pull` writes
- [ ] CI and deployment

## Contributing

### Preview

Run `task serve` and open http://127.0.0.1:1313/: it serves the docs bundles of the last pull and reloads the site-owned pages, layouts and styles on an edit. A source repository's pages are previewed through their bundle: `opm-docs serve` in that repository, or its build output pulled here with `OPM_BUNDLES_LOCAL="<project>@v1.0=<dir>" task bundles:pull serve` (Quick Start). Before a pull request, run `task build` (every check) and, when anything visual changes, `task qa`, and look at the screenshots in `site/.shots/`.

### Page dialect

Pages in a source repository's `docs/site/` follow the site page rules in the workspace `STYLE.md` ("Site Pages"): front matter with `title`, `description` and, on a leaf page, `type`; a section page is `_index.md` and declares no type; order is `weight`, then title; callouts are GitHub alerts with a bold title line; figures are `{{< opm/<name> >}}` shortcodes; internal links are `/docs/<section>/<page>/`, or, into the Enhancements section, `/enhancements/`, `/enhancements/<NNNN>/` and `/enhancements/<NNNN>/<document>/` (one of the seven document slugs), each with an optional `#fragment` (`/enhancements/0021/decisions/#d3`); nothing else under `/enhancements`; or, into the Catalogs tab, the bare tab root `/catalogs/<name>/` or the major alias `/catalogs/<name>/<MAJOR>/` and below (`/catalogs/opm/4/traits/backup/#spec`), never a minor, `edge` or `/catalogs/` alone, and the site writes the URL of the newest minor of that major. The dialect is docs-kit contract C11, enforced by `opm-docs lint`: a repository's `Docs` workflow lints its pages when it builds its bundle, and `task bundles:pull` lints every bundle again in bundle mode, naming the file and line of each problem. The site has no lint of its own and no copy of the conformance cases (docs-kit's `internal/dialect/testdata/conformance/` holds them): fix the page in its repository, and change a rule in docs-kit first.

The link hook (`site/layouts/_markup/render-link.html`) resolves a `/enhancements/` link to the one unversioned section from every version (the section's pages live only in the default version's page tree), and fails the build when the section has no such page or the build has no section; a `/catalogs/` link resolves the same way through the newest minor of its major, and fails naming `task bundles:pull` when the build has no Catalogs section. Both link hooks (this one and the Catalogs section's) fail the build on a destination with a scheme other than http, https or mailto, or a protocol-relative `//host`, after decoding it as goldmark does (`site/layouts/_partials/opm/link-unsafe.html`); `opm-docs pull` refuses the same, and the hooks do not rely on it.

A direction note is a NOTE alert whose bold title line is **Direction**:

```markdown
> [!NOTE]
> **Direction**
>
> Enhancement 0009, [Operational Primitives](/enhancements/0009/), is a draft, and none of it is built.
```

It renders labelled Direction in place of Note, with its title line not repeated, in a violet box with a dashed start border (`site/layouts/_markup/render-blockquote-alert.html`, an override of Hextra's alert hook pinned in `site/overrides.sha256`, and `typography.css`), so it stands apart from an ordinary note. Every other alert renders as before. `task shots` shoots the first direction note of every page that holds one, in the six variants, into `site/.shots/direction/<page>/`, and `task qa` runs axe on the first such page in both themes.

The site-owned pages in `site/content/` are outside the dialect lint, but the build checks their front matter too.

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

A new figure name is a change to the page dialect. Add it to docs-kit's C11 and `opm-docs lint` first, in a docs-kit release the site's `opm-docs` pin reaches before any page uses it, and to the list of figure names in the workspace `STYLE.md` ("Site Pages"). Add its title, exactly as its shortcode passes it to the frame, to `site/layouts/_partials/opm/figure-titles.html`, which the Markdown outputs print where the page draws the figure; `task test:site` fails when the two differ. Pages then use it as `{{< opm/<name> >}}` on a line of its own.

One figure is site-owned and outside the dialect: the landing's `opm/landing-overview`, which only `site/content/_index.md` calls. It is not in C11's figure names or `figure-titles.html` (the home page has no Markdown output). It is 372 wide, so its edges meet the hero's column and its labels stay at 9 px on a phone, and it passes `caption` set to `false`, which leaves the visible caption out while the claim stays the SVG's accessible label. A dialect figure always shows its caption and never passes `caption`.

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
