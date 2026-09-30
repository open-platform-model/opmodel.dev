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
│   ├── scripts/                # Build, checks, lint, dev server, vendoring, host-side runner
│   └── tests/                  # Fixture workspace, lint and check cases, dialect tree, browser QA
├── Taskfile.yml
└── README.md
```

## Tasks

```bash
task serve             # Dev server on http://127.0.0.1:${SITE_PORT:-1313}/, live reload
task build             # Lint, build and check the site into site/public/ (no network)
task preview           # Serve the built site/public/ on SITE_PORT
task lint:sources      # Lint the six source repos' docs/site pages
task test:site         # Prove every check fails when it should (fixtures only)
task shots             # Build, then screenshot every figure page and the extras into site/.shots/
task qa                # shots, the axe accessibility and the search smoke tests
task ci                # check, image, build, test:site
task check             # Go fmt, vet and test, and openspec validate
task image             # Build the site's image if its tag is missing
task qa:image          # Build the QA image if its tag is missing
task versions:prepare  # Host-side version preparation (nothing to do for one version)
task clean             # Remove generated files
task build:docgen      # Build the docgen tool
task generate          # Generate the schema JSON and the CLI reference
```

## Implementation Status

- [x] Hugo + Hextra site, built and served in Docker with no network
- [x] Pages assembled from six source repositories, in one page dialect, with a source lint
- [x] Build checks: drift guard, lint, front matter, links, page set, stray files, reserved sections, planning comments, supply chain, redirects, git dates
- [x] Per-version Pagefind search in Hextra's palette; `/latest/` and root redirects
- [x] Browser QA: screenshots in six variants, WCAG 2.1 A and AA smoke test, search smoke test
- [ ] Figures other than "From module to running objects" (they show a "Figure pending" note)
- [ ] `docgen schema` and `docgen cli` implementations, and pages generated from their output
- [ ] Versions built from release tags
- [ ] CI and deployment

## Contributing

### Preview

Run `task serve` and open http://127.0.0.1:1313/. It reads every source repository's `docs/site/` in place, so an edit to a page shows without a restart. Before a pull request, run `task build` (every check) and, when anything visual changes, `task qa`, and look at the screenshots in `site/.shots/`.

### Page dialect

Pages in a source repository's `docs/site/` follow the site page rules in the workspace `STYLE.md` ("Site Pages"): front matter with `title`, `description` and, on a leaf page, `type`; a section page is `_index.md` and declares no type; order is `weight`, then title; callouts are GitHub alerts with a bold title line; figures are `{{< opm/<name> >}}` shortcodes; internal links are `/docs/<section>/<page>/`. `task lint:sources` checks every page and names the file and line of each problem. The lint (`site/scripts/lint-sources.sh`) is byte-identical to the workspace dialect contract: fix the page, never the lint.

The site-owned pages in `site/content/` are not linted, but the build checks their front matter too.

### Adding a figure

A figure is inline SVG drawn by hand in the site engine.

1. Draw the SVG body in `site/layouts/_partials/opm/figures/<name>.html` on its viewBox grid, with the `opm-fig` classes in `site/assets/css/opm/figures.css`. Reference the arrowhead as `marker-end="url(#<id>-arrow)"`.
2. In `site/layouts/_shortcodes/opm/<name>.html`, render it through `partial "opm/figure.html"` with `id`, `title`, `claim` (the caption, which is also the SVG's accessible label), `width`, `height` and `body`.
3. Pages use it as `{{< opm/<name> >}}` on a line of its own. The six figure names are part of the page dialect: a new name is a change to the workspace dialect contract and the lint first.
4. Run `task shots` and read the PNGs: light, dark, both theme and OS mismatches, and phone width. The run fails when any figure text drops below 9 px on a phone.

See the main [OPM documentation](https://github.com/open-platform-model) for general contribution guidelines.

## Page design

Rules for page authors and for anyone changing the site's layouts or styles.

- **The description is shown three times.** A page's front-matter `description` is its lead paragraph under the title, its card text on its section's index page, and its sub-line in search results. Write it as one plain sentence that stands alone: no Markdown, no link, and nothing that only makes sense after the title or next to the body.

## License

Apache 2.0
