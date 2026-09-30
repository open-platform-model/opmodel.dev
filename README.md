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
│   └── tests/                  # Fixture workspace, lint and check cases, dialect tree, browser QA, version tests
├── Taskfile.yml
└── README.md
```

## Tasks

```bash
task serve             # Dev server on http://127.0.0.1:${SITE_PORT:-1313}/, live reload
task build             # Lint, build and check the site into site/public/ (no network)
task preview           # Serve the built site/public/ on SITE_PORT
task lint:sources      # Lint the six source repos' docs/site pages
task test:site         # Prove every check fails when it should (fixtures), then task versions:test
task shots             # Build, then screenshot every figure page and the extras into site/.shots/
task qa                # shots, the axe accessibility and the search smoke tests
task ci                # check, image, build, test:site
task check             # Go fmt, vet and test, and openspec validate
task image             # Build the site's image if its tag is missing
task qa:image          # Build the QA image if its tag is missing
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

- **Clean tree.** CI fails when `task ci` leaves the tree dirty, `.task/` excluded (Task's checksum files; one of them is tracked). Two examples: `go fmt` rewrote unformatted Go (`task check` formats but never fails), or a build step wrote a file that is not gitignored.
- **Checkout layout.** Every repository is checked out with `path:` under `$GITHUB_WORKSPACE`, opmodel.dev included, so `OPM_WS` is `$GITHUB_WORKSPACE` and the six source repositories sit beside opmodel.dev as they do in the workspace. opmodel.dev is at the event's ref and the sources are at `main`. Every checkout has full history and tags (`fetch-depth: 0`, which the git dates and the resolver tests of `task versions:test` need) and `persist-credentials: false`: no step pushes, so no clone keeps a token that the build containers could read.
- **Dates.** The workflow sets `OPM_REQUIRE_DATES=1`, so a page without a git date fails the build. `task versions:prepare` computes every date on the host, so a local build passes the same check, from worktrees too: `OPM_REQUIRE_DATES=1 task build`. `task test:site` sets it back to 0 for its fixtures; the two-version build of `task versions:test` keeps it.
- **Summary and artifacts.** The job summary lists the six source SHAs from `site/public/build-stamp.json` and the number of files in `site/public/`. The `site-public` artifact holds the whole `site/public/` for 14 days; `build-stamp` holds the stamp for 90 days.
- **Browser job.** The `browser` job runs `task qa`, as you do locally, in parallel with `build`: it builds the site itself (with the same seven checkouts, since that build reads every source repository), takes the screenshots in six variants, fails when figure text drops below 9 px at phone width, and runs the axe WCAG 2.1 A and AA smoke test and the search smoke test, all in the QA image with no network. The `site-shots` artifact holds `site/.shots/` for 7 days from every run that got as far as taking screenshots, a failed run's included: when an accessibility or search test fails in CI, the screenshots show why. Its upload sets `include-hidden-files: true`, because `actions/upload-artifact` skips every file under a directory whose name starts with a dot, and `.shots` is one.
- **Pins.** Every action is pinned by full commit SHA, with its version in a comment. Task is pinned to an exact version (3.52.0), the openspec CLI to 1.12.0, Go comes from `go.mod`, and the `ci:lint` task pins actionlint by image digest. Nothing floats: bump each on purpose.
- **Concurrency.** It is set per job, one group per job (`<workflow>-<ref>-<job>`), and a newer run cancels the older run's job. It is never set at workflow level, which would cancel a deploy job with the rest of a run; and two jobs never share one cancelling group, because they would cancel each other. A deploy job uses its own group, without `cancel-in-progress`. The `opmodel.dev` working directory is a per-job `defaults` entry for the same reason, never workflow-level: a deploy job runs a step before its checkout.
- **Source repositories.** The nightly run is how a merge in a source repository reaches CI; no source repository dispatches a run. A source page that breaks the lint or a link fails the nightly run and every opmodel.dev pull request until it is fixed in its own repository, never here. GitHub disables a scheduled workflow after 60 days without repository activity (re-enable it on the Actions tab), and it mails a scheduled run's failure to whoever last edited the cron line.
- **Pull request titles.** The `PR Title` workflow (`.github/workflows/pr-title.yml`) fails a pull request whose title is not a Conventional Commit with this repository's types (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `build`, `ci`; the "Commit Standards" in `openspec/config.yaml`) and a lower-case subject. The squash merge keeps a single commit's subject, but a pull request with several commits, as every OpenSpec change has, lands on `main` under its title. The workflow runs on `pull_request_target`, which reads the workflow from `main`, so a change to it first applies to the pull request after it merges.

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
- [x] All six figures of the page dialect, drawn as inline SVG that follows the site's theme toggle
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

To check a figure, run `task qa` and read its PNGs in `site/.shots/<page>/` in all six variants: light, dark, both theme and OS mismatches, and phone light and dark.

See the main [OPM documentation](https://github.com/open-platform-model) for general contribution guidelines.

## License

Apache 2.0
