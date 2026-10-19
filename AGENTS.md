# opmodel.dev repository guide

## Purpose

The public documentation site for Open Platform Model, at opmodel.dev. A Hugo site on the Hextra theme (neutral skin), built, served and tested only in Docker. Most pages live in six source repositories (opm, core, catalog_opm, cli, library, opm-controller), each in its `docs/site/`; each publishes them in its signed docs bundle, and the build assembles the bundles. The build reads no git repository except its own. This repo owns the pipeline, the theme overrides and the site-owned pages (the landing and the section overviews).

## Repository rules

- `CONSTITUTION.md` defines the design principles; this repo follows it.
- **Docker only.** The site builds, serves and is tested only in the images the Taskfile defines. Never run `hugo`, `npm`, `npx` or `node` on the host. Builds, tests and QA run with no network; only the image builds and the bundle pull use it. Never fix an image tag or a container name: parallel worktrees would replace each other's image.
- **The page dialect is the docs-kit one.** `opm-docs lint` enforces it in each producer's `Docs` workflow and again at the pull. When it fails, fix the page in its source repository. A rule change is a change to the dialect, made in docs-kit first with its conformance case there. The site has no lint of its own.
- **Docs bundles are signed and pinned.** `opm-docs` is pinned by version and archive SHA-256 in `site/Dockerfile`, and the site bumps it before any producer does, because an older `opm-docs` refuses a field it does not know. The trust policy is `site/bundles.cue`; a change to the policy is a change to that file. The lock is never committed. Recover from a bad bundle with a committed frozen lock, never by loosening a check.
- **The version list is `site/bundles.cue`.** Nothing globs `v*/` or "every top-level directory".
- **Hash-guarded overrides.** Hextra is vendored as files, never a Hugo module and never fetched at build time. `site/overrides.sha256` pins the upstream file behind every override copy, and a drift guard fails the build when upstream changes one. Diff upstream and merge the hunk before re-pinning; never run the update flag only to turn a build green. A new override copy appends its line by hand. Prefer Hextra's built-ins and hooks over an override copy.
- **Vendored files are pinned.** A third-party file served as it came (Mermaid, under `site/assets/lib/`) is pinned by SHA-256 in `site/vendored.sha256`, with its version, source and licence in the comment above its line. Never edit it or re-pin what is on disk: re-vendor from the source the comment names and verify it there. Mermaid draws only in the Enhancements section; a mermaid fence elsewhere fails the build.
- **Checks fail the build.** Every check in `site/scripts/` has a failing case under `site/tests/` that `task test:site` runs; a new check brings its case.
- **Pages live where their source lives.** Fix a page in the repository whose change would make it wrong. Never edit a generated reference page, here or there: regenerate it with that repo's task. Nothing generated is committed here. Site-owned pages are in every version, so their links must resolve in every version.
- **Skill files.** After `openspec update` with the pinned CLI, no `openspec-*` skill file under `.claude/skills/` keeps a local patch; the repo rules live in `openspec/config.yaml`, which `openspec update` does not overwrite.

## Layout

```text
openspec/              OpenSpec workspace (docs-site-change schema, no specs)
references/            detail files, one topic each
.tasks/                the durable-decisions check and its test
site/                  the site; its root holds the build image, the trust policy and the version list
site/config/           Hugo config per environment
site/content/          site-owned pages: landing and section overviews
site/layouts/          overrides, OPM partials and figure shortcodes
site/assets/           one CSS file per owner under css/opm/, Pagefind adapter, vendored Mermaid
site/enhancements/     content adapter, unversioned Enhancements section
site/catalogs/         content adapter, unversioned Catalogs section
site/themes/hextra/    vendored Hextra
site/scripts/          runner, build, checks, generators
site/static/           fonts, favicons and images
site/tools/            brand raster generators
site/tests/            fixtures, check cases, subpath, versions and browser QA
site/data/             build data, generated and gitignored
```

## Commands

| Command | What it does | When |
| --- | --- | --- |
| `task bundles:pull` | Resolve, verify, lint and unpack the docs bundles (network) | Before a build, and after a release |
| `task build` | Dates, generated inputs, Hugo, every check and Pagefind, no network, into `site/public/` | Every change; fails without a current pull |
| `task serve` | Dev server on `SITE_PORT` (default 1313) with live reload | Editing site-owned pages, layouts, styles |
| `task preview` | Serve the built `site/public/` | After a build |
| `task build:edge` | Every repository's `main` together, CI only, never published | Check a branch against all other `main` |
| `task test:site` | Prove every check fails on its fixture, then the two-version test | Changing a check or a script |
| `task shots` / `task qa` | Screenshots in six variants; then axe and search smoke tests | Visual changes; read the PNGs first |
| `task ci` | `check`, `image`, `build`, `test:site` | Before a PR |
| `task check` | OpenSpec validation and the durable-decisions check | Before a PR |
| `task ci:lint` | Lint the workflows with actionlint | Changing a workflow |
| `task image`, `task qa:image` | Build an image whose hash tag is missing (network) | First run, or a Dockerfile change |
| `task brand:favicons`, `task brand:og` | Regenerate the committed brand rasters | Changing the marks or the site title |
| `task cite-lint` | The enhancement comment rule (network, host Go) | Not in `check` or `ci`; run on request |
| `task clean` | Remove generated files | Stale output |

## Style

- Box-drawing tables and ASCII art use monospace-safe symbols: `[x]` and `[ ]`, `OK` and `FAIL`. Never `✓` or `✗`: their width varies by font and breaks alignment.
- One CSS file per owner under `site/assets/css/opm/`, concatenated in file-name order; add a file, there is no list to edit. Use Hextra's CSS variables and key dark mode on `html.dark`.
- Sidebar, section lists and pager order by `weight`, then title.
- Link OPM terms to the canonical glossary in the `opm` repository; do not define them here.
- Update the layout above when you add a directory.
- Write for four readers: Module Author (CUE definitions, reference docs), Platform Operator (deployment guides, CLI reference), End-user (getting started, concepts), Contributor (architecture, design).

@CONTEXT.md
