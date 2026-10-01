# opmodel.dev

Documentation site for the Open Platform Model, built with [Hugo](https://gohugo.io/) and the [Hextra](https://github.com/imfing/hextra) theme (v0.13.0, neutral skin), plus `docgen`, a Go tool that generates reference pages from the CUE schema and the CLI's commands.

## Overview

This repository contains:

- **`site/`** - the Hugo site: configuration, the site-owned pages (the landing and the section overviews), layouts and theme overrides, styles, the vendored theme, build scripts, the build image and the tests.
- **`cmd/docgen/`** and **`internal/`** - the `docgen` tool: CUE schema extraction and cobra doc generation.

Most pages do not live here. Each of six repositories (opm, core, catalog_opm, cli, library, opm-operator) keeps its pages in `docs/site/`, and the build assembles them.

## Architecture

```text
<repo>/docs/site/**/*.md  (six source repos, mounted read-only at /src/<repo>)
site/content/             (landing and section overviews)
        |
        v
  drift guard -> source lint -> git dates, mounts, page-set checks
        -> hugo build (Hextra, vendored) -> output checks -> Pagefind per version
        |
        v
  site/public/   /v1.0/...   /latest/ -> /v1.0/   / -> /latest/

docgen: CUE schema -> site/data/schema/*.json; cobra -> CLI reference Markdown (planned)
```

Everything runs in Docker. The build image (`site/Dockerfile`) holds Hugo 0.167.0, Pagefind 1.5.2 and git, each pinned; a build runs with no network. The QA image (`site/tests/browser/Dockerfile`) holds Chromium, Playwright and axe-core for the screenshots and the smoke tests. Image tags come from the Dockerfile hashes (`opmodel-dev-hugo:<12 hex>`, `opmodel-dev-qa:<12 hex>`).

There is one version, `v1.0` (beta), built from each source repository's current checkout. Every version lives under `/<version>/`; `/latest/` points at the default version and `/` at `/latest/`. How versions map to component releases is an open question (enhancement 0021:OQ15).

See [RFC-0006](https://github.com/open-platform-model/cli/blob/main/docs/rfc/0006-documentation-generation.md) for the docgen design.

## Prerequisites

- Docker
- [Task](https://taskfile.dev/)
- git
- Go 1.25+ (see `go.mod`) and the OpenSpec CLI, for `task check`
- The six source repositories checked out next to this one (the default), or pointed at with the variables below

## Quick Start

```bash
# Dev server with live reload on http://127.0.0.1:1313/ (reads the sources in place)
task serve

# Full build with every check into site/public/, then serve it
task build
task preview
```

The first run builds the image, which needs the network. The build reads the source repositories from the workspace root, the parent directory of this checkout. To read them from elsewhere:

```bash
OPM_WS=/path/to/workspace task build                  # another workspace root
OPM_SRC_WORKTREE=site-src task build                  # <repo>/.claude/worktrees/site-src in each repo
OPM_SRC_CLI=/path/to/cli task build                   # one repo from elsewhere (OPM_SRC_<REPO>)
SITE_PORT=1314 task serve                             # another port for serve and preview
```

## Directory Structure

```text
opmodel.dev/
├── cmd/docgen/                 # docgen CLI (schema, cli, all)
├── internal/                   # cuedoc (CUE extraction), cobradoc (cobra docs)
├── site/
│   ├── Dockerfile              # Build image: Hugo, Pagefind, git
│   ├── NOTICE                  # Third-party licences
│   ├── overrides.sha256        # Theme files behind every override copy (drift guard)
│   ├── config/_default/        # hugo.toml
│   ├── content/                # Site-owned pages: _index.md landing, docs/**/_index.md overviews
│   ├── layouts/                # Theme overrides, OPM partials, figure shortcodes
│   ├── assets/css/opm/         # One CSS file per owner, concatenated in file-name order
│   ├── assets/js/              # Pagefind adapter for Hextra's search palette
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
task serve             # Dev server on http://127.0.0.1:${SITE_PORT:-1313}/, live reload
task build             # Lint, build and check the site into site/public/ (no network)
task build OPM_BASE_URL=<url>  # The same, for another base URL (a path allowed); qa, shots and preview use the root
task preview           # Serve the built site/public/ on SITE_PORT
task lint:sources      # Lint the six source repos' docs/site pages
task test:site         # Prove every check fails when it should (fixtures), then task versions:test
task shots             # Build, then screenshot every figure page and the extras into site/.shots/
task qa                # shots, the axe accessibility and the search smoke tests
task ci                # check, image, build, test:site
task check             # Go fmt, vet and test, and openspec validate
task image             # Build the site's image if its tag is missing
task qa:image          # Build the QA image if its tag is missing
task brand:favicons    # Regenerate the favicon PNGs and favicon.ico from the drawn SVGs
task brand:og          # Regenerate the Open Graph card, site/static/images/og-default.png
task versions:prepare  # Resolve site/versions.conf on the host: refs, archives, git dates (build and serve run it)
task versions:check    # Print every version's resolved refs and SHAs; writes nothing
task versions:test     # Resolver tests and a two-version build into site/.check/versions-test/
task clean             # Remove generated files
task build:docgen      # Build the docgen tool
task generate          # Generate the schema JSON and the CLI reference
```

## CI

The `Site` workflow (`.github/workflows/site.yml`) builds and tests the site on every pull request to `main`, on every push to `main`, nightly at 03:23 UTC, and on demand (`workflow_dispatch`). Its `build` job runs the Taskfile targets you run locally:

| CI step | Local equivalent |
|---|---|
| Lint the workflows | `task ci:lint`: actionlint, with its bundled shellcheck, from a digest-pinned image (`task ci:lint -- -verbose` names each file) |
| Check, build and test the site | `task ci`: `check`, `image`, `build`, `test:site` |
| The build leaves the tree clean | `task ci`, then `git status --porcelain` |
| Build for GitHub Pages (interim) | `OPM_BASE_URL=https://open-platform-model.github.io/opmodel.dev/ task build`, after the steps above (see GitHub Pages (interim) below) |

- **Clean tree.** CI fails when `task ci` leaves the tree dirty, `.task/` excluded (Task's checksum files; one of them is tracked). Two examples: `go fmt` rewrote unformatted Go (`task check` formats but never fails), or a build step wrote a file that is not gitignored.
- **Checkout layout.** Every repository is checked out with `path:` under `$GITHUB_WORKSPACE`, opmodel.dev included, so `OPM_WS` is `$GITHUB_WORKSPACE` and the six source repositories sit beside opmodel.dev as they do in the workspace. opmodel.dev is at the event's ref and the sources are at `main`. Every checkout has full history and tags (`fetch-depth: 0`, which the git dates and the resolver tests of `task versions:test` need) and `persist-credentials: false`: no step pushes, so no clone keeps a token that the build containers could read.
- **Dates.** The workflow sets `OPM_REQUIRE_DATES=1`, so a page without a git date fails the build. `task versions:prepare` computes every date on the host, so a local build passes the same check, from worktrees too: `OPM_REQUIRE_DATES=1 task build`. `task test:site` sets it back to 0 for its fixtures; the two-version build of `task versions:test` keeps it.
- **Summary and artifacts.** The job summary lists the six source SHAs from `site/public/build-stamp.json` and the number of files in `site/public/`. The `site-public` artifact holds the whole `site/public/` for 14 days; `build-stamp` holds the stamp for 90 days. After those uploads, the GitHub Pages build adds one summary line with its file count and uploads its tree as the `github-pages` artifact, kept for one day; a deploy adds a summary naming the deployed URL.
- **Browser job.** The `browser` job runs `task qa`, as you do locally, in parallel with `build`: it builds the site itself (with the same seven checkouts, since that build reads every source repository), takes the screenshots in six variants, fails when figure text drops below 9 px at phone width, and runs the axe WCAG 2.1 A and AA smoke test and the search smoke test, all in the QA image with no network. The `site-shots` artifact holds `site/.shots/` for 7 days from every run that got as far as taking screenshots, a failed run's included: when an accessibility or search test fails in CI, the screenshots show why. Its upload sets `include-hidden-files: true`, because `actions/upload-artifact` skips every file under a directory whose name starts with a dot, and `.shots` is one.
- **Pins.** Every action is pinned by full commit SHA, with its version in a comment. Task is pinned to an exact version (3.52.0), the openspec CLI to 1.12.0, Go comes from `go.mod`, and the `ci:lint` task pins actionlint by image digest. Nothing floats: bump each on purpose.
- **Concurrency.** It is set per job, one group per job (`<workflow>-<ref>-<job>`), and a newer run cancels the older run's job. It is never set at workflow level, which would cancel a deploy job with the rest of a run; and two jobs never share one cancelling group, because they would cancel each other. A deploy job uses its own group, without `cancel-in-progress`. The `opmodel.dev` working directory is a per-job `defaults` entry for the same reason, never workflow-level: a deploy job runs a step before its checkout.
- **Source repositories.** The nightly run is how a merge in a source repository reaches CI; no source repository dispatches a run. A source page that breaks the lint or a link fails the nightly run and every opmodel.dev pull request until it is fixed in its own repository, never here. GitHub disables a scheduled workflow after 60 days without repository activity (re-enable it on the Actions tab), and it mails a scheduled run's failure to whoever last edited the cron line.
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
# the six source SHAs of the run's job summary
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

`site/versions.conf` is the only list of the versions the site publishes. It is in git-config syntax (`git config --file` reads it, so nothing new enters the build image), and it changes only by a reviewed commit. `task build` and `task serve` resolve it on the host first (`task versions:prepare`); `task versions:check` resolves it and prints every version's refs and SHAs without building.

A version is one of two kinds:

- `source = main`: every source repository at its checked-out `HEAD` (in CI that is `main`; locally whatever `OPM_SRC_WORKTREE` points at). It is allowed only until `v1.0.0-beta.N` tags exist, and only for one version. The build records the six SHAs in the footer stamp and in `site/public/build-stamp.json`.
- Anchored: fixed refs, bumped by commit, never a moving line resolved at build time. `cli` is the anchor, a tag or a full SHA. The library ref comes from the anchor's `go.mod`, core from that library's `DefaultSchemaModule` (`opm/schema/loader.go`), and opm-operator from the anchor's `PinnedOperatorVersion` (`internal/operator/manifest.go`). `catalog` and `opm` are explicit, because the CLI pins no catalog and opm has no repository-level tag. `cli/hack/platform/` is a test fixture and never a pin. A pin that is not an exact release, or that is wrong for the site, is replaced by `override = <repo> <ref> <reason>`; the reason is required and is recorded in the build stamp (the footer link title and `build-stamp.json`).

Moving `v1.0` onto beta tags is this edit (the tag names are examples):

```ini
[version "v1.0"]
	label = v1.0 (beta)
	weight = 1
	default = true
	cli = v1.0.0-beta.1
	catalog = opm-v4.6.0
	opm = 0123456789abcdef0123456789abcdef01234567
```

Every repository has a dialect floor in the manifest: the commit that moved its `docs/site/` pages to the page dialect. No ref older than its floor builds, and no tag cut before it can: the resolver fails first, naming the repository and the ref. So each repository needs a tag cut after its floor before `v1.0` can move onto tags.

The site-owned pages (`site/content/`) are built into every version, so every link on them must resolve in every version, older ones included; a link to a page that exists only in a newer version fails that version's build.

`OPM_VERSIONS_MANIFEST=<file>` selects another manifest. `task versions:test` (part of `task test:site`) builds `site/tests/versions/two-versions.conf`, which adds a test version, into `site/.check/versions-test/`, never `site/public/`. When `task versions:test` fails naming `(version v0.9)`, a source or site-owned page no longer builds at the test version's SHAs: bump them in `two-versions.conf` to buildable SHAs after each floor, never edit the checks. A fixture-workspace build sets the versions itself, because its roots sit inside this repository and are no git top levels: `OPM_VERSIONS=v1.0=/src OPM_WS=$PWD/site/tests/fixtures/ws task build`.

## Implementation Status

- [x] Hugo + Hextra site, built and served in Docker with no network
- [x] Pages assembled from six source repositories, in one page dialect, with a source lint
- [x] Build checks: drift guard, lint, front matter, links, page set, stray files, reserved sections, planning comments, supply chain, redirects, git dates
- [x] Per-version Pagefind search in Hextra's palette; `/latest/` and root redirects
- [x] Browser QA: screenshots in six variants, WCAG 2.1 A and AA smoke test, search smoke test
- [x] All seven figures of the page dialect, drawn as inline SVG that follows the site's theme toggle
- [ ] `docgen schema` and `docgen cli` implementations, and pages generated from their output
- [x] Versions from a manifest of source refs (`site/versions.conf`), with dialect floors and a two-version regression test
- [ ] `v1.0` on release tags (needs a tag cut after each repository's dialect floor)
- [ ] CI and deployment

## Contributing

### Preview

Run `task serve` and open http://127.0.0.1:1313/. It reads every source repository's `docs/site/` in place, so an edit to a page shows without a restart. Before a pull request, run `task build` (every check) and, when anything visual changes, `task qa`, and look at the screenshots in `site/.shots/`.

### Page dialect

Pages in a source repository's `docs/site/` follow the site page rules in the workspace `STYLE.md` ("Site Pages"): front matter with `title`, `description` and, on a leaf page, `type`; a section page is `_index.md` and declares no type; order is `weight`, then title; callouts are GitHub alerts with a bold title line; figures are `{{< opm/<name> >}}` shortcodes; internal links are `/docs/<section>/<page>/`. `task lint:sources` checks every page and names the file and line of each problem. The lint (`site/scripts/lint-sources.sh`) is byte-identical to the workspace dialect contract: fix the page, never the lint.

The site-owned pages in `site/content/` are not linted, but the build checks their front matter too.

### Adding a figure

A figure is inline SVG drawn by hand in the site engine. It is two files:

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
