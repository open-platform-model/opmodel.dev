## Why

opmodel.dev moves from Astro, Starlight and the Black theme to Hugo and Hextra v0.13.0 with the neutral skin. The prototype in the workspace `research/docs-site-stacks/hugo-themes/hextra-prototype` already builds every source page, with Pagefind search in Hextra's own palette, in a 131 MB image with no Node. This change moves that pipeline into `site/`, adapts it to this repo and deletes the Astro site.

It is the foundation of the change set in `orchestration.md`. Every later change (CI, versions, figures, design fixes, brand marks, deploy) codes against the tasks, paths, hooks and checks it fixes (`orchestration.md` section 6). It is also urgent: the source repos rewrite their `docs/site` pages to the Hugo dialect (S1-S6) and merge first. After that, the Astro build on `main` renders degraded or fails. The owner accepted this because the site is not live.

## What Changes

- **Build image.** A slim image with Hugo 0.167.0, Pagefind 1.5.2 and git on Alpine 3.24.2, each pinned by digest or SHA-256. It is tagged by the hash of its Dockerfile (`opmodel-dev-hugo:<12 hex>`). It is built beside the Astro image as `site/Dockerfile.hugo` and becomes `site/Dockerfile` at cutover.
- **Theme.** Hextra v0.13.0 (`adf732f8d97cb8e149d4aba232a449d41cd9e38c`) is vendored as files, runtime tree only, with `site/themes/hextra.COMMIT` and a re-runnable `site/scripts/vendor-hextra.sh`. Every theme file an override copies is pinned in `site/overrides.sha256`, and the build fails when upstream changes one.
- **Pipeline.** `site/scripts/build-all.sh` runs, in the image with no network: the drift guard, the source lint, git dates, generated mounts, the build stamp, `hugo build --panicOnWarning`, the page-set and output checks, and Pagefind per version. Each source repo is mounted read-only at `/src/<repo>`. The mounts are generated at build time into gitignored config.
- **Source lint.** `site/scripts/lint-sources.sh` is the dialect lint from `orchestration.md` section 4.1, byte for byte. It runs before every build and fails naming file and line. **BREAKING** for source pages: `.mdx`, `:::` asides, `import` lines, `sidebar:`, `index.md` and the other forms section 4 forbids fail the build. S1-S6 remove them before this change merges.
- **No compatibility layer.** No MDX converter, no aside passthrough, no `sidebar.order` fallback and no `index.md` remap. The sidebar, the child lists and the pager order by `weight`, then title.
- **Front-matter validation** inside Hugo (`errorf`) for every page with a content file, site-owned ones included: title and description required, one of four types on a leaf, no type on an overview.
- **Checks** that fail the build: the thirteen in `orchestration.md` section 6. `task hugo:test:site` (later `task test:site`) proves each one fails on a fixture.
- **Versions** (owner decision, 2026-09-30). One version, `v1.0`, labelled "v1.0 (beta)" and built from each source repo's `main`, with the six SHAs in a build stamp. **BREAKING** URLs: pages publish under `/v1.0/`, `/latest/` points at `v1.0`, and `/` points at `/latest/`. The Astro demo versions `v0.1` and `v0.2` are dropped; they were never published.
- **Site-owned pages.** The landing becomes `site/content/_index.md` (hextra-home). The nine section files become `_index.md` with `weight` and a `description`, and no type. The hand links in `reference/index.md` give way to a generated child list.
- **Figures.** All six `{{< opm/<name> >}}` shortcodes exist. `module-to-cluster` is ported. The other five, `helm-and-opm` included, render a "Figure pending" stub until the figures change ports them.
- **Planning comments** (`<!-- ... -->` briefs) stay out of every published output: HTML, `llms.txt`, the Markdown outputs, XML and JSON.
- **Browser QA.** A Playwright image (python 1.63.0 by digest, axe-core 4.10.3 from a checked tarball). It takes screenshots of every figure page in six variants with a 9 px text floor, and runs accessibility and search smoke tests.
- **Taskfile.** The Hugo tasks run as `hugo:*` beside the Astro tasks until the cutover. Then they take the final names: `image`, `versions:prepare`, `build`, `serve` (port `SITE_PORT`, default 1313), `preview`, `lint:sources`, `test:site`, `shots`, `qa`, `ci`, `clean`, plus `qa:image`, which builds the QA image.
- **Cutover.** **BREAKING** for contributors: the Astro app, its Node image, its npm lockfile, the `site/shots/` tool and port 4321 are removed. `README.md`, `AGENTS.md`, `CONSTITUTION.md`, `TODO.md` and the docgen wording describe the Hugo site. `AGENTS.md` gains a "Durable decisions" section that records the stack. The temporary gate paragraph in `openspec/config.yaml` is deleted.

## Before / After

**Before**

```text
site/
  Dockerfile  .dockerignore  package.json  package-lock.json  tsconfig.json
  astro.config.mjs  versions.config.mjs          v0.2 (latest) and v0.1 (demo)
  content/index.mdx                              Starlight splash
  content/docs/**/index.md                       9 sections, sidebar.order
  scripts/{build-versions,prepare-versions,serve,sources,stage-version}.mjs
  src/{content.config.ts,versions.ts,components/*.astro,components/diagrams/*}
  shots/{Dockerfile,shoot.py}
Taskfile.yml   image serve build preview shots:image shots   (opmodel-dev-site:local, port 4321)
URLs           /v0.2/... /v0.1/... /latest/* -> /v0.2/
```

**After**

```text
site/
  Dockerfile                      alpine@digest, hugo 0.167.0, pagefind 1.5.2, git (sha256-checked)
  NOTICE
  overrides.sha256
  config/_default/hugo.toml       defaultContentVersion 'v1.0', defaultContentVersionInSubdir true
  content/_index.md               landing (every version)
  content/docs/**/_index.md       9 site-owned overviews: weight + description, no type
  layouts/  assets/css/opm/*.css  static/fonts/
  themes/hextra/  themes/hextra.COMMIT
  scripts/{build-all,gen-mounts,gen-lastmod,lint-sources,check-pages,check-overrides,serve,test-site,run-in-image,vendor-hextra}.sh
  tests/{checks,lint,dialect,fixtures,browser}/
  (gitignored) public/ resources/ data/opm/ config/{production,development}/ .gen/ .versions/ .check/ .shots/
Taskfile.yml   image versions:prepare build serve preview lint:sources test:site shots qa:image qa ci clean
               (opmodel-dev-hugo:<12 hex>, opmodel-dev-qa:<12 hex>, port ${SITE_PORT:-1313})
URLs           /v1.0/...   /latest/* -> /v1.0/:splat   / -> /latest/   /reference-archive/ reserved
```

## Impact

- **Depends on:** section 1 starts when W0 `bootstrap-openspec-workspace` is on `main` (done 2026-09-30). Section 2 starts when S1-S6 `adopt-hugo-page-dialect` (opm, core, catalog_opm, cli, library, opm-operator) are merged and the supervisor's `site-src` worktrees exist. The change merges when its verify is green, after S1-S6. The owner merges it.
- **Hands off:** the S PRs merge only after this change's section 1 is green: its fixture build is the evidence that the dialect renders. After the owner merges this change, E, B, C, D, M and I1b start (`orchestration.md` section 2).
- **Touches:** everything under `site/`; `Taskfile.yml`, `.gitignore`, `README.md`, `AGENTS.md`, `CONSTITUTION.md`, `TODO.md`, `openspec/config.yaml`; `internal/cobradoc/generator.go` and `cmd/docgen/main.go` (comments and help text only).
- **Build inputs:** gains the vendored theme, the pinned Hugo image and the read-only source mounts `/src/<repo>`. Loses Node, npm and the Astro packages.
- **Source repos:** no edit here (Principle I). S1-S6 carry the dialect rewrite. After this change, a page in the old dialect fails the site build, naming file and line; the fix belongs in that repo. In-flight changes that add pages (library `refuse-colliding-contracts`, core `fold-colliding-contract-keys`) must write the new dialect; the supervisor tells their owners.
- **URLs and versions:** everything moves under `/v1.0/`. Nothing is published yet, so no reader loses a link. How versions map to component releases stays 0021:OQ15, an open question; `v1.0` on `main` does not settle it.
- **Contributors:** `task serve` moves from port 4321 to 1313. Builds read the source repos through `OPM_WS` and `OPM_SRC_<REPO>` (or `OPM_SRC_WORKTREE`).
- **Docker on the shared host:** image tags come from Dockerfile hashes, and no container gets a fixed name. The Astro image `opmodel-dev-site:local` and the owner's live container on port 4321 are never touched.

## Enhancement

Related 0018 decisions, named here only. By the supervisor's ruling for this change set (`orchestration.md` section 1), this change carries no `enhancement.yaml` and logs no delivery:

- 0018:D7 and 0018:D7:R1: every page declares a type, a title and a one-line description. The Hugo `errorf` validation and the lint enforce it; an overview declares no type.
- 0018:D8: a page lives in the repo whose change would make it wrong, and the site assembles the pages at build time. The read-only `/src/<repo>` mounts implement the assembly.
- 0018:D14: figures are inline SVG drawn in the site engine. Enhancement 0018 is made engine-neutral separately (I2).
