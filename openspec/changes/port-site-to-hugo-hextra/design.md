## Context

The site in `site/` is an Astro 7 app with Starlight and the Black theme, built in a `node:24-slim` image (`site/Dockerfile`, tag `opmodel-dev-site:local`, port 4321). Its version logic, sidebar order, page-count guard and redirects live in `site/scripts/*.mjs`; its six figures are Astro components in `site/src/components/diagrams/`.

The Hugo pipeline to port is the prototype at the workspace path `research/docs-site-stacks/hugo-themes/hextra-prototype` (read only; P below). It builds against Hextra main 275e2ad, with two demo versions, an MDX converter, an aside passthrough and an `index.md` remap. Owner decision O4 removes those compatibility parts: the source repos rewrite their pages to the Hugo dialect first (S1-S6), and this change lints for it.

Constraints this design works inside:
- `orchestration.md` is binding. Section 4 is the page dialect and its lint. Section 6 is the interface this change fixes for every later change. Section 11 lists the traps.
- Docker only: no `hugo`, `npm`, `npx` or `node` on the host. Never touch `opmodel-dev-site:local`, `opmodel-dev-shots:local` or port 4321. Until section 5, never run the bare `image`, `build`, `serve`, `preview`, `shots` or `shots:image` tasks.
- Parallel worktrees share one Docker namespace, so image tags come from content hashes and containers get no fixed names.
- Wave-1 source repos only lint, so section 1 must prove on a fixture that the dialect renders. The S PRs merge on that evidence.

## Goals / Non-Goals

**Goals:**
- Replace the Astro site with the Hugo + Hextra v0.13.0 pipeline, neutral skin only, built and tested in Docker.
- Fix the interface in `orchestration.md` section 6 exactly: task names, environment variables, container paths, outputs, CSS glob, partials and hooks, and the thirteen checks.
- Reject the old dialect in source pages before Hugo runs, naming file and line.
- Publish one version, `v1.0` (beta), under `/v1.0/`, with `/latest/` and `/` redirecting to it and the six source SHAs stamped.
- Leave `main` releasable at every section boundary. Delete Astro only after the Hugo build has passed its checks and the browser QA.

**Non-Goals:**
- Tag-based versions and the manifest (B), the five remaining figures (C), the judges' design fixes (D), CI (E), hosting (F) and brand marks (M).
- Any edit in a source repo (S1-S6).
- The generated reference (GR) and the component archive (V6), beyond the reservations below. docgen behaviour, including its stale `../catalog` default.
- Settling 0021:OQ15. Building `v1.0` from `main` is the owner's day-one choice, not an answer to it.

## Decisions

### 1. Build Hugo beside Astro, delete Astro last

Sections 1-4 add the Hugo site under `hugo:*` task names. The Astro code stays in the tree but is not a gate in any section. It already fails once the S changes merge, and it loses its content in section 1 (decision 6). Section 5 deletes Astro and renames the tasks.

Alternatives: deleting Astro first would leave sections 2-4 with no visual reference and a broken tree. Renaming the Astro tasks to `astro:*` changes nothing: they would still use the protected image and port.

### 2. Theme: Hextra v0.13.0, vendored as runtime files

```text
site/themes/hextra/            layouts/ assets/ static/ i18n/ data/ theme.toml hugo.toml LICENSE
site/themes/hextra.COMMIT      v0.13.0 adf732f8d97cb8e149d4aba232a449d41cd9e38c https://github.com/imfing/hextra
site/scripts/vendor-hextra.sh  host side, git only: shallow clone of the tag into a scratch directory
                               outside the repo, refuse unless HEAD is the pinned SHA, copy the
                               runtime list above, write hextra.COMMIT
```

The theme is never a Hugo module: that needs Go and network in the image. Upstream's `CLAUDE.md` (a symlink to `AGENTS.md`), `AGENTS.md`, `package*.json`, `playwright.config.ts`, `postcss.config.mjs`, `netlify.toml`, `build.sh`, `dev.toml`, `go.mod`, `examples/`, `.devcontainer/`, `.vscode/` and the READMEs are never vendored. The agent files tell agents to run `npm install`, and Claude Code loads a nested `CLAUDE.md`.

### 3. Drift guard

`site/overrides.sha256` pins the upstream file behind every override copy. `site/scripts/check-overrides.sh` checks it first in every build; `--update` re-pins every path already listed in `site/overrides.sha256`, never a fixed list in the script (P's does, so a later `--update` would drop a line another change appended). A new override copy adds its line by hand (`orchestration.md` section 6). The file lists paths relative to `site/themes/hextra/`:

```text
layouts/_partials/sidebar.html              layouts/_markup/render-link.html
layouts/_partials/navbar-title.html         layouts/_markup/render-codeblock.html   (behind render-codeblock-cue.html)
layouts/_partials/banner.html               layouts/docs/single.html                (behind opm/docs-main.html)
layouts/_partials/components/last-updated.html  layouts/docs/list.html
layouts/_partials/scripts/search.html       layouts/404.html
layouts/page.markdown.md                    layouts/section.markdown.md
layouts/llms.txt                            (only if decision 10 picks option b)
```

The prototype's `render-passthrough.html` and `assets/js/flexsearch.js` lines are dropped with those overrides. The first check against v0.13.0 fails on `render-link.html` (upstream #1037/#1039: the `<a ...>` tag on one line with explicit spaces). Merge that hunk into the override, then re-pin. Never run `--update` only to turn a build green; diff upstream first.

### 4. Build image and tags

`site/Dockerfile.hugo` is P `Dockerfile` unchanged in substance: Alpine 3.24.2 by digest, Hugo 0.167.0 (static, amd64) and Pagefind 1.5.2 (musl), each SHA-256-checked, plus git with `safe.directory '*'`. It COPYs nothing and is built with no context (`docker build -t <tag> - < site/Dockerfile.hugo`), so the Astro allow-list `.dockerignore` does not matter. The tag is `opmodel-dev-hugo:<first 12 hex of sha256(file)>`, built only when missing. Section 5 runs `git mv site/Dockerfile.hugo site/Dockerfile`; the content hash, and so the tag, stays the same.

Every container runs `--rm --init --user <uid>:<gid>` with no `--name`. Build, lint, test and QA containers also run `--network none`. `serve` and `preview` cannot: a container with no network cannot publish a port. They publish only `127.0.0.1:${SITE_PORT:-1313}` and fetch nothing. Only the two image builds need the network: `task image`, and `task qa:image` (`hugo:qa:image` until section 5), which builds `site/tests/browser/Dockerfile` as `opmodel-dev-qa:<12 hex>` when the tag is missing. `shots` and `qa` run `qa:image` first, as the Astro `shots` runs `shots:image` today, so they reach the network only through it and only when the tag is missing.

`qa:image` is a task name that `orchestration.md` section 6 does not list, and trap 18 names only `task image` as needing the network. The final report names both under `deviations`.

### 5. Host side: workspace, sources and refs

```text
OPM_WS                 default: parent of the main checkout, from
                       git rev-parse --path-format=absolute --git-common-dir (right inside a worktree)
OPM_SRC_<REPO>         OPM_SRC_OPM OPM_SRC_CORE OPM_SRC_CATALOG_OPM OPM_SRC_CLI OPM_SRC_LIBRARY OPM_SRC_OPM_OPERATOR
                       default: $OPM_WS/<repo>/.claude/worktrees/$OPM_SRC_WORKTREE if set, else $OPM_WS/<repo>
OPM_BUILD_REFS         repo=sha ..., from git -C <root> rev-parse HEAD on the host; "none" when <root>
                       is not its own git top level (the fixture workspace)
docker run ... -v <wt>:/work/repo -v <root>:/src/<repo>:ro (x6), no :z
```

- Before any `docker run`, every source root is checked: it exists and holds `docs/site`. A miss fails naming the variable. Otherwise Docker would create a root-owned empty directory at the missing path.
- Each variable reads the environment first. A Taskfile global var declared with `sh:` shadows an environment variable of the same name; this was checked with Task 3.52.0 on 2026-09-30. Both `OPM_SRC_WORKTREE=site-src task build` and `task build OPM_WS=<path>` must work. The resolution SHOULD live in one host script, `site/scripts/run-in-image.sh`, that the Taskfile calls, rather than in template expressions.
- SHAs are resolved on the host. Inside the container, a worktree's `.git` file points at a host path that is not mounted.
- `OPM_VERSIONS` is not resolved on the host. `run-in-image.sh` passes it into the container only when the caller set it, and otherwise leaves it unset so `build-all.sh` uses its default `v1.0=/src`. B relies on this seam: an explicit `OPM_VERSIONS` from the caller reaches `build-all.sh` and `serve.sh` without B editing A's script.

### 6. Site-owned content moves to Hugo form in section 1

The build mounts `site/content` once. Astro's `index.mdx` would publish as a stray raw file, and its nine `docs/**/index.md` are leaf bundles in Hugo. Section 1 therefore:
- runs `git mv` on the nine section files to `_index.md`, with `weight: N` taken from `sidebar.order`;
- writes a `description` for `reference`, `reference/cli` and `reference/definitions`, and removes their `type:` and every `sidebar:` block;
- drops the four hand links in `reference/_index.md`, which the child list replaces in section 2;
- replaces `site/content/index.mdx` with `site/content/_index.md` (hextra-home, today's text, from P `site/content/_index.md`).

The change-set plan placed this in section 2. It moves to section 1 because the fixture build must mount the site content (the "counted once" proof), and the alternative, excluding Astro's files from the mount, is the kind of compatibility mount O4 forbids. Astro is not a gate in any section, so nothing that is checked breaks. Section 1's fixed commit subject does not mention the move, so its commit body does, and the section 1 report names it under `deviations` for the supervisor to accept.

### 7. Content assembly

`site/scripts/gen-mounts.sh` writes `site/config/{production,development}/module.toml` (gitignored) from `OPM_VERSIONS` (`name=root ...`, default `v1.0=/src`; each root holds `<repo>/docs/site`):

```toml
[[mounts]]                       # site-owned, once, every version
  source = "content"
  target = "content"
[[mounts]]                       # one per repo and version
  source = "/src/cli/docs/site"
  target = "content/docs"
  [mounts.sites.matrix]
    versions = ["v1.0"]          # exact names: in version globs * does not cross "."
```

There is no `files` exclusion, no `index.md` remap and no `ported/` mount. `site/.gen/<v>/` is mounted per version when it exists; nothing creates it yet (GR).

### 8. Source lint and front-matter validation

- `site/scripts/lint-sources.sh` is `orchestration.md` section 4.1 byte for byte (`sha256sum` `dae9717af0c43fc3bdc29a9e730fd171fe7541dab35a9625a35efb1682973c6b`). `build-all.sh` runs it on every mounted source root before Hugo starts, and `task lint:sources` runs it alone. It never reads `site/content`. A change to it is a contract change (`orchestration.md` section 9), never a local fix.
- The page-order helper from section 4.1 is never committed: it reads `sidebar.order`.
- Hugo checks front matter with `errorf` in `layouts/_partials/opm/check-front-matter.html`, called from `custom/head-end.html`. It checks only pages backed by a content file (`with .File`) of kind `page`, `section` or `home`. Hextra's `baseof.html` renders `head-end` for the 404 page, taxonomy and term pages, and a section with no `_index.md` too; they have no front matter, so checking them would fail every build. `title` and `description` are required. A leaf declares tutorial, how-to, explanation or reference (0018:D7:R1). An `_index.md` and the home declare no type (0018:D7). This covers site-owned pages, which the lint does not read. Without it, Hugo silently picks another layout for a bad `type`.

The rules the lint adds beyond O4's list hold by the supervisor's ruling of 2026-09-30. Their bases:

| Rule | Basis |
|---|---|
| Front-matter keys only `title`, `description`, `type`, `weight` (no `aliases`, `draft`, `slug`) | 0018:D7 (nothing else is required), 0018:D7:R3 (no page declares its address). A draft is a silently dropped page |
| Links root-absolute `/docs/.../` with a trailing slash; no relative, `.md` or versioned links; reference definitions and raw `href=`/`src=` checked | The link hook resolves `/docs/...` per version; other forms break under the versions dimension |
| No images, no non-`.md` files | 0018:D14: figures live in the engine |
| Lower-case kebab-case names | Page paths are URLs |
| `weight` >= 1 | Hugo reads 0 as unset; 0018's `#Page` allows 0, so this narrows it |
| Alert marker alone on its line | github.com and Hextra render only that form the same way |
| Code fences carry a language tag | An untagged fence can emit a line starting `:::` and trip the output guard with no file and line |

### 9. Ordering

Order is `weight`, then title, everywhere. A page without `weight` sorts after the weighted ones. `layouts/_partials/sidebar.html` and `layouts/_partials/opm/section-children.html` sort explicitly. The pager uses Hugo's default page order (weight, date, title); the source pages carry no date. Nothing reads `sidebar.order`. The sidebar keeps `sidebar.exclude` from a site-owned `cascade`, for future generated sections.

### 10. Planning comments

`<!-- ... -->` briefs must not reach any published text. Minifying cleans HTML only. Hextra's `layouts/llms.txt` (lines 13 and 29) prints `.Summary | plainify | truncate 100`. With goldmark `unsafe = true`, a brief-only page's summary is the comment. `plainify` ends a tag at the first `>`, so a brief holding `>=` or `->` leaks its tail into `/v1.0/llms.txt`.

Section 1 picks one mechanism and records the result here:
- **(b), the default:** HTML minification, switched on in `site/config/_default/hugo.toml` with `[minify] minifyOutput = true` (Hugo's HTML minifier drops comments; `keepComments` stays false). The same block sets `disableSVG = true`: the SVG minifier trims the space before a `<tspan>` in inline figure SVG ("component <tspan>web</tspan>" renders as "componentweb", reproduced with tdewolff/minify v2.24.8 by change C's planning), and figures are hand-drawn SVG that must pass through byte for byte (supervisor ruling 2026-09-30). P never minified, and the build command in decision 12 carries no `--minify`, so the config key is the one place it is set, and it covers every build path, `test:site` included. `page.markdown.md` and `section.markdown.md` strip comments (as P does); a hash-guarded `layouts/llms.txt` override prints `.Description` (required on every page) instead of `.Summary`. It keeps the landing's raw HTML.
- **(a), if (b) leaves any comment text in any output:** goldmark `unsafe = false`, which drops comments before `.Content` and `.Summary` exist. The landing's raw `<div>` markup then moves into a layout.

Either way, check 10 scans every `*.html`, `*.txt`, `*.md`, `*.xml` and `*.json` under `public/`. `test:site` carries a brief-only fixture page whose brief contains `>=` and `->`.

### 11. Versions, redirects and the stamp

```toml
defaultContentVersion = 'v1.0'
defaultContentVersionInSubdir = true
[versions.'v1.0']
  weight = 1
[[params.opm.versions]]          # an array, so no param key contains a dot
  name = 'v1.0'
  label = 'v1.0 (beta)'
```

- **Label.** With one version, `opm/version-switch.html` shows "v1.0 (beta)" as a plain label next to the title. The menu appears at two or more versions (B). Hiding the label would drop the beta signal the owner asked for.
- **Root files.** `build-all.sh` writes `public/_redirects` (`/ /latest/ 302`, `/latest/* /v1.0/:splat 302`), a root `index.html` meta refresh to `/latest/`, and a root `404.html` copied from the default version. `custom/head-end.html` publishes the `/latest/<path>/` stubs, as in P, but not P's `_redirects`: P writes it from the home page as `/ <home RelPermalink> 302`, which is `/ /v1.0/ 302`, and that breaks `/` -> `/latest/`. `build-all.sh` is the only writer of `_redirects`, and task 2.6 checks its exact lines. `layouts/robots.txt` ranges `hugo.Sites`; spike item 4 finds out where Hugo writes it, and `build-all.sh` makes sure one sits at the root.
- **Version list.** Pagefind runs once per version name taken from `OPM_VERSIONS`, with `--root-selector 'main#content > .content'`. Nothing globs `v*/` or "every top-level directory". `/reference-archive/` is reserved: nothing publishes there.
- **Stamp.** `build-all.sh` writes `data/opm/build.json` and `public/build-stamp.json` from `OPM_BUILD_REFS`. `layouts/_partials/custom/footer.html` (Hextra calls it from `footer.html`; no theme copy is needed) renders `opm/build-stamp.html`: the version label and the six short SHAs.
- **Edit links.** `opm/source.html` maps a file under `<root>/<repo>/docs/site/<path>` (in a normal build, `/src/<repo>/docs/site/<path>`) to `{repo, path, editURL, viewURL}`, finding the repo from the `<repo>/docs/site/` path segment. Any other content file is site-owned and maps to `opmodel.dev` `site/content/<path>`. It never matches the literal `/work/repo/site/` prefix, so the copies in `test:site` (decision 15) map the same way. "Edit this page" goes to `edit/main`. `viewURL` stays empty: no version maps to a ref on day one, and B fills it. Never use the version name as a git ref.

### 12. Checks

| # | Check | Where |
|---|---|---|
| 1 | Drift guard | `check-overrides.sh`, first |
| 2 | Source lint | `lint-sources.sh`, before Hugo |
| 3 | Front matter | `errorf` inside Hugo |
| 4 | Q1 broken internal link | `layouts/_markup/render-link.html` (`errorf`) |
| 5 | A1 two sources, one URL (`x.md` against `x/_index.md` included) | `check-pages.sh pre` |
| 6 | Q2 expected page missing or unexpected page | `check-pages.sh post` |
| 7 | Stray output files | `check-pages.sh post` |
| 8 | Reserved prefixes: no source page under `docs/reference/cli/` or `docs/reference/definitions/` | `check-pages.sh pre` |
| 9 | Raw `:::` in HTML output | `build-all.sh` |
| 10 | Planning comment in any text output | `build-all.sh` |
| 11 | Supply chain: no third-party or CDN URL | `build-all.sh` |
| 12 | Redirect files present | `build-all.sh` |
| 13 | Git dates, when `OPM_REQUIRE_DATES=1` | `gen-lastmod.sh` |

`check-pages.sh post` also writes `site/.check/<v>/nav-order.txt`: the sidebar's links in document order, read from the version's docs home. The build summary prints the page count per version and `find public -type f | wc -l`. Hugo runs as `hugo build --gc --cleanDestinationDir --panicOnWarning --logLevel warn`, never `--quiet`, which hides the ERROR line.

### 13. Figures and CSS

- **Figures.** Six shortcodes `layouts/_shortcodes/opm/<name>.html`, one per name in `orchestration.md` section 4. `module-to-cluster` renders `opm/figure.html` (dict `id`, `title`, `claim`, `width`, `height`, `body`) with the SVG in `opm/figures/module-to-cluster.html`. The other five render a "Figure pending" stub; `helm-and-opm` is new. Figure tokens `--opm-fig-*` follow the site toggle (`html.dark`). The Astro sources C ports are deleted in section 5; C reads them from history, for example `git show 2207ba1:site/src/components/diagrams/HelmAndOpm.astro`.
- **CSS.** P `custom.css` and `skin-neutral.css` split into `site/assets/css/opm/*.css`. `custom/head-end.html` sorts `resources.Match "css/opm/*.css"` by file name, concatenates the files in that order, then minifies and fingerprints the result. There is no list to edit. Rules later owned by others start in their files, named in `orchestration.md` section 6: `figures.css` (C, including the "Figure pending" stub's rules), `versions.css` (B), `landing.css` (D), and, where A carries such rules, `typography.css`, `toc.css` and `cards.css` (D) and `brand.css` (M). The skin, fonts, sidebar and page chrome go in A's own files, which never take one of those seven names. Geist Mono ligatures stay off for `code` and `pre`. The skin switch and the default skin are dropped.
- **Search.** `layouts/_partials/scripts/search.html` loads only `assets/js/opm-pagefind.js`, which implements `window.hextraSearch`. The FlexSearch fallback, `assets/lib/` and its override are dropped. Mermaid, KaTeX, MathJax, asciinema, PhotoSwipe and medium-zoom stay off: Hextra loads them from jsDelivr.
- **Static.** Geist 1.4.2 (`static/fonts/`, with `GEIST-LICENSE.txt`). P's placeholder `favicon.svg`, `images/opm-mark*.svg` and `images/og-default.png` carry over until M replaces them. `site/NOTICE` lists Hextra (MIT), Tailwind CSS v4.3.0 (MIT, inside Hextra's compiled CSS), Geist (OFL-1.1) and Pagefind (MIT).

### 14. Taskfile

| Sections 1-4 | Section 5 | Runs |
|---|---|---|
| `hugo:image` | `image` | `docker build` of the Hugo image, if the tag is missing |
| `hugo:versions:prepare` | `versions:prepare` | no-op on the host; B fills it |
| `hugo:build` | `build` | prepare, then the image: `build-all.sh` into `site/public/` |
| `hugo:serve` | `serve` | prepare, then `serve.sh`: `exec hugo server` on `127.0.0.1:${SITE_PORT:-1313}`, sources read in place |
| `hugo:preview` | `preview` | a static server in the build image over `site/public/` on `SITE_PORT` |
| `hugo:lint:sources` | `lint:sources` | the lint over the six source roots |
| `hugo:test:site` | `test:site` | `test-site.sh`: every check against its fixture |
| `hugo:qa:image` | `qa:image` | `docker build` of the QA image, if the tag is missing (decision 4) |
| `hugo:shots` | `shots` | `qa:image`, then the QA image: screenshots into `site/.shots/` |
| `hugo:qa` | `qa` | shots, a11y and search smoke tests |
| `hugo:ci` | `ci` | `check`, `image`, `build`, `test:site` |
| `clean` (extended) | `clean` | removes generated paths only |

`serve` keeps `docker run --init` with `TINI_KILL_PROCESS_GROUP=1`, has no `-it`, and runs with no TTY. One SIGINT stops the container. `task check` is unchanged (`fmt`, `vet`, `openspec:check`, `test`).

### 15. Tests

- `site/tests/fixtures/ws/<repo>/docs/site/` holds a small workspace for all six repos, in the dialect. It is the section 1 build target (`OPM_WS=<wt>/site/tests/fixtures/ws`) and the base for every check fixture.
- `site/tests/lint/`: one failing tree per lint rule, plus a clean one. `site/tests/checks/`: one failing case per build check. The stray-file case is a site-owned test mount with a non-page extension, because the lint stops any non-`.md` source before the build. `site/tests/dialect/`: alerts with a bold title line, and the CUE `""` workaround.
- `site/scripts/test-site.sh` runs in the build image with no network and feeds fixture roots through `OPM_VERSIONS`. It never reads `site-src` or a main checkout. It builds its own prerequisites, prints `ok` or `FAIL` per case, and exits non-zero on any unexpected result.
- `site/tests/fixtures/ws` must build green: it is the section 1 gate. Every case that must fail lives in its own tree under `site/tests/lint/` or `site/tests/checks/`, which `test-site.sh` lays over a copy of the fixture workspace.
- **How it writes only under `site/.check/tests/`.** A build writes relative to the site directory: `config/{production,development}/module.toml`, `data/opm/*.json`, `public/`, `.check/`, and Hugo's own `resources/` and `.hugo_build.lock`. So the ported scripts take the site directory as `SITE_DIR` (default `/work/repo/site`) and write only below it. For each case, `test-site.sh` copies `site/`, less its generated paths (`public/`, `resources/`, `.check/`, `.shots/`, `.versions/`, `.gen/`) and `tests/`, to `site/.check/tests/<case>/site/`, and runs the pipeline there with `SITE_DIR` set to the copy. In the mounted worktree, a test run then writes nothing outside `site/.check/tests/`, and it never overwrites `site/public/` or the generated config of a real build. Nothing in a template or check depends on the literal `/work/repo/site/` path; `opm/source.html` takes the repo from the `<repo>/docs/site/` segment of a file's path, so copies and fixture roots map the same way.
- **What "no `/tmp`" means.** No input comes from the host's `/tmp` or from P's `/proto`, and no host `/tmp` is mounted. The container's own scratch space is fine: `mktemp` in the byte-fixed lint, `check-pages.sh` and `check-overrides.sh` writes to the container's `/tmp` (or `TMPDIR`), which `--rm` discards.
- `site/tests/browser/`: `Dockerfile` (Playwright python 1.63.0 by digest; axe-core 4.10.3 from its npm registry tarball, SHA-256-checked, no npm; tag `opmodel-dev-qa:<12 hex>`), `shots.py`, `a11y.py` and `search.py`. They serve `site/public/` inside the container, publish no port, and set the theme through Hextra's `color-theme` key.

### 16. Repo documents at cutover

- `README.md`: stack, architecture, prerequisites, quick start (`task serve` on http://127.0.0.1:1313/, output `site/public/`), tree, tasks. It gains a `## Contributing` section: Preview, Page dialect (points at the workspace `STYLE.md` "Site Pages" and `task lint:sources`) and Adding a figure (the recipe C updates).
- `AGENTS.md`: Purpose, Repository Rules, Layout (also dropping the stale `adr/`, `getting-started/` and `guides/`), Environment Notes, Build And Dev Commands, Technology stack, Patterns, and a new `## Durable decisions`. The attribution, bare-`@name` and 250-word PR rules stay word for word.
- `CONSTITUTION.md` lines 5, 30, 53, 102 and 153. Line 102 becomes "Theme built-ins over overrides; every override copy is hash-guarded". The PR body shows the owner this principle change.
- `TODO.md`: the banner, the Astro block, items 1.2, 1.3 (a Hugo content adapter, `_content.gotmpl`), 1.4, 1.5, 2.2, 3.1 (`site/public/`) and 3.4, the Future items the site now has, the References and Next Immediate Steps. Item 3.2 (hosting) is left to the deploy change.
- docgen wording: `internal/cobradoc/generator.go` lines 2, 9 and 13, and `cmd/docgen/main.go` line 38, say Hugo front matter; line 13's "sidebar order" becomes `weight`. Comments and help text only.
- `openspec/config.yaml`: delete the paragraph "Until `port-site-to-hugo-hextra` lands its cutover section, ..." (lines 108-112), and the clause "the Astro site that came before it is being replaced" (lines 10-11).

### Files under `site/`

- **Added** (P path where ported): `Dockerfile.hugo` (P `Dockerfile`), `NOTICE`, `overrides.sha256`, `config/_default/hugo.toml`, `content/_index.md`, `layouts/**` (P `site/layouts`, less `render-passthrough.html`), `assets/css/opm/*.css`, `assets/js/opm-pagefind.js`, `static/**`, `themes/hextra/**`, `themes/hextra.COMMIT`, `scripts/*.sh` (P `scripts/`, less `convert-mdx.sh`, `make-snapshots.sh`, `metrics.py`, `hugo.sh`, `gen-definitions.js`), `tests/**`.
- **Renamed:** `content/docs/**/index.md` to `_index.md` (9); `Dockerfile.hugo` to `Dockerfile` (section 5).
- **Deleted:** `content/index.mdx` (section 1). In section 5: `astro.config.mjs`, `package.json`, `package-lock.json`, `tsconfig.json`, `.dockerignore`, the Astro `Dockerfile`, `versions.config.mjs`, `src/**`, `scripts/*.mjs`, `shots/**`.
- **Build inputs:** gained: the vendored theme, the Hugo image, `/src/<repo>` read-only mounts, fonts. Lost: Node, npm packages, the Astro image, `OPM_DOCS_WORKSPACE` and the `..:/work/workspace` mount.
- **Theme override set:** new (it did not exist in this repo). Published URLs change from `/v0.2/` and `/v0.1/` to `/v1.0/`. The version set becomes `v1.0` only.

## Research & Decisions

### Unverified assumptions (section 1 is the spike that answers them)

**Context**: P was built against Hextra 275e2ad, in its own mount layout with `:z`, from snapshots. Several behaviours change here.
**Explored**: P, its README and its vendored theme; the change-set planning of 2026-09-30; `orchestration.md` section 11.
**Decision**: section 1 proves each item on the fixture and writes the answer under this heading before its commit:
1. Mounts without `:z` are readable on this host (Fedora, where SELinux may deny container reads). The Astro Taskfile already mounts without `:z`, so this is expected. If it fails: stop and report; `:z` on workspace mounts stays forbidden.
2. gen-lastmod on a worktree root. The build mounts this change's worktree at `/work/repo`, and its `.git` file points at a host path. The site-owned pages then get no date and the build stays green. With `OPM_REQUIRE_DATES=1`, the build fails naming a page.
3. Site content is counted once: Q2 lists each site-owned URL once, and the `content` mount reaches `v1.0`. If `versions = ["**"]` does not match `v1.0`, list the version names from `OPM_VERSIONS`.
4. Whether Hugo itself writes a root `index.html`, `robots.txt` or `404.html` under `defaultContentVersionInSubdir`. `build-all.sh` publishes its own root files either way.
5. Planning comments: (b) or (a), per decision 10, proven by check 10 and the `llms.txt` fixture.
6. `hugo:serve` with no TTY (`</dev/null`) starts, answers on `127.0.0.1:1313`, and stops on one SIGINT, leaving no container of that image in `docker ps`.
7. The dialect renders: GitHub alerts with a bold title line become Hextra alerts; parameterless `{{< opm/... >}}` render; an escaped `{{</* ... */>}}` shows as text; a source `_index.md` and its pages order by `weight`; root-absolute `/docs/.../` links resolve to `/v1.0/docs/.../` through the link hook, and a broken one fails the build.
8. `OPM_WS` resolves to the workspace from inside the worktree, and the environment and CLI overrides both win over the default.
**Rationale**: the S PRs merge on items 5 and 7, and items 2, 4 and 6 change scripts that every later change calls.

### Pins

**Context**: the prototype pinned Hugo 0.167.0, Pagefind 1.5.2 and an untagged Hextra.
**Explored**: the releases and commits of Hugo, Hextra, Pagefind, Chroma and Geist on GitHub (`gh api`, 2026-09-30).
**Decision**: Hugo 0.167.0 and Pagefind 1.5.2 (both still latest), Alpine 3.24.2 by digest, Hextra v0.13.0 (released 2026-09-29, tag adf732f, 5 commits after 275e2ad), Geist 1.4.2. Playwright python 1.63.0 and axe-core 4.10.3 in the QA image.
**Rationale**: the tag removes the "unreleased SHA" cost. Among the overrides, only `render-link.html` changed upstream between 275e2ad and the tag. Geist 1.7.2 is cosmetic and deferred. Chroma 2.27.0, bundled in every Hugo release, still mis-lexes `""` in CUE, so `render-codeblock-cue.html` and its test stay.

### Task variables and the environment

**Context**: the interface promises `OPM_SRC_WORKTREE=site-src task build`.
**Explored**: a scratch Taskfile under Task 3.52.0. A global var `FOO: {sh: echo x}` printed `x` even with `FOO=fromenv` exported. `BAR: '{{.BAR | default "d"}}'` printed the environment value. A CLI `task FOO=y` beat both.
**Decision**: no interface variable is a global `sh:` var. They resolve in the host script, or with `{{.X | default ...}}`.
**Rationale**: otherwise the documented environment form silently does nothing.

## Interface (orchestration.md section 6)

**Adds** (every later change codes against these as they land on `main`):
- Tasks `image`, `versions:prepare`, `build`, `serve`, `preview`, `lint:sources`, `test:site`, `shots`, `qa`, `ci`, `clean`, and `check` unchanged. They are named `hugo:*` until section 5. Also `qa:image`, which section 6 does not list (decision 4; reported under `deviations`).
- Environment `OPM_WS`, `OPM_SRC_OPM`, `OPM_SRC_CORE`, `OPM_SRC_CATALOG_OPM`, `OPM_SRC_CLI`, `OPM_SRC_LIBRARY`, `OPM_SRC_OPM_OPERATOR`, `OPM_SRC_WORKTREE`, `SITE_PORT`, `OPM_REQUIRE_DATES`, `OPM_BUILD_REFS` and the internal seam `OPM_VERSIONS`.
- Container paths `/work/repo` (read-write) and `/src/<repo>` (read-only).
- Outputs `site/public/` (`v1.0/` with `pagefind/`, `sitemap.xml`, `llms.txt`, `404.html`; `latest/` stubs; `_redirects`; root `index.html`, `404.html`, `robots.txt`; `build-stamp.json`), `site/.check/<v>/nav-order.txt` and `site/.shots/`. Gitignored inputs `site/config/{production,development}/module.toml`, `site/data/opm/{lastmod,build}.json`, `site/.gen/<v>/` and `site/.versions/<v>/`.
- CSS glob `site/assets/css/opm/*.css`.
- Partials and hooks `opm/figure.html`, `opm/figures/<name>.html`, `_shortcodes/opm/<name>.html`, `opm/section-children.html`, `opm/source.html`, `opm/build-stamp.html` with `custom/footer.html`, `opm/version-switch.html`, `opm/version-links.html`, `navbar-title.html`, `banner.html`, `opm/docs-main.html`, `custom/content-begin.html`, `sidebar.html`, `components/last-updated.html`, `_markup/render-link.html` and `_markup/render-codeblock-cue.html`.
- Theme `site/themes/hextra` with `site/themes/hextra.COMMIT` and `site/overrides.sha256`. Checks 1-13.
- Refinements section 6 does not list, reported under `deviations`: the container-internal `SITE_DIR` (decision 15; default `/work/repo/site`, set only by `test-site.sh`; B's edits to the ported scripts keep it), the class hooks `opm-brand`, `opm-title-long` and `opm-title-short` in `navbar-title.html` (M's `brand.css` selects them; B keeps them), and the shot numbering in `site/.shots/<page>/<n>-<variant>.png` (drawn figures only, in page order; C relies on it).

**Relies on:**
- W0's workspace: the `docs-site-change` schema, `task openspec:check` inside `task check`, and `.claude/worktrees/` ignored.
- The section 4 dialect in all six repos (S1-S6), from section 2 on.
- The supervisor's `site-src` worktrees (`OPM_SRC_WORKTREE=site-src`), from section 2 on.
- The lint bytes in `orchestration.md` section 4.1.

Names refined during implementation are reported under `deviations` and need the supervisor's OK (`orchestration.md` section 6).

## Risks / Trade-offs

- [The first v0.13.0 build fails the drift guard on `render-link.html`] -> Expected. Merge the upstream hunk, then re-pin; never `--update` blind.
- [`index.md` in any source or site-owned tree swallows its siblings, silently] -> The lint rejects it in sources. Every site-owned section file is `_index.md`. Q2 catches a missing page.
- [A bad `type:` silently picks another layout] -> The lint and `errorf` (decision 8).
- [`--quiet` hides a failed build's ERROR line; `.Site.Data` fails under `--panicOnWarning`] -> Never `--quiet`; use `hugo.Data`.
- [Hugo 0.166 globs: `**/x` does not match `x`, and `*` does not cross `.`] -> Exact version names in mount matrices; `{**/,}x` where a glob must match the root.
- [A symlinked mount root is dropped; the default `baseURL` is `https://example.org/`; `eq 1 1.0` is true] -> Real directory mounts; `baseURL` set explicitly; version names compared as strings.
- [Static files, CSS and JS publish once at the root; pages, `llms.txt`, sitemaps and 404 per version] -> The root-file checks and the redirect check assume exactly that split.
- [Hextra loads Mermaid, KaTeX, MathJax, PhotoSwipe and more from jsDelivr when enabled] -> All off; `--network none`; check 11.
- [Pagefind indexes only `main#content > .content`; `window.hextraSearch` and the `.hextra-sidebar-*` / `li.open` classes are internal Hextra contracts] -> Hash guard on the copies; the search smoke test; no Hextra v0.14 or #1006 sidebar rewrite in this set.
- [Planning comments leak into `llms.txt`] -> Decision 10 and check 10.
- [Worktree dates go missing silently, as do shallow clones and git's dubious-ownership refusal] -> gen-lastmod counts misses; `OPM_REQUIRE_DATES=1` in CI (E) makes them fatal; CI checks out with full history.
- [A bind mount of a missing path creates a root-owned directory] -> The host check in decision 5. The stray root-owned `site/` at the workspace root stays untouched.
- [A shared Docker namespace across parallel worktrees] -> Hash tags, no `--name`, per-worker `SITE_PORT` (A uses 1313); never `opmodel-dev-site:local`, `opmodel-dev-shots:local` or `opm-hextra-build`.
- [The bare Astro tasks retag protected images or bind 4321 until section 5] -> Never run them. Section 5 removes them in the same commit that gives the Hugo tasks their names.
- [The Astro build on `main` degrades once S1-S6 merge, and this change stops it working in section 1] -> Accepted by the owner. Astro is not a gate here.
- [Section 2 waits on six merges in other repos] -> Section 1 runs beside S1-S6. After it, stop, report and wait (`orchestration.md` section 7).
- [Disk: every Dockerfile change makes a new hash-tagged image; the Playwright image is about 3.5 GB] -> Stale tags are pruned only after the set completes, with the owner's OK. Never prune in this change.
- [Sections 1 to 3 have no visual gate, and section 2 is the first to build the real site] -> Deliberate: the QA image lands in section 4, before section 5 deletes anything. Nothing reaches `main` before the whole change merges.

## Durable decisions

| Decision | Lands in (section 5) |
|---|---|
| Stack: Hugo + Hextra v0.13.0, neutral skin, chosen 2026-09-30; evidence in the workspace `research/docs-site-stacks/hugo-themes/` | `AGENTS.md` `## Durable decisions` |
| URL layout: every version under `/<version>/`; `/latest/` is the default version; `/` goes to `/latest/`; `/reference-archive/` reserved; nothing globs `v*/` | `AGENTS.md` `## Durable decisions` |
| `docs/reference/cli/` and `docs/reference/definitions/` are site-owned; generated content goes to `site/.gen/<v>/` | `AGENTS.md` `## Durable decisions` |
| The source lint is byte-identical to the workspace dialect contract; fix the page, never the lint | `AGENTS.md` Repository Rules; `README.md` Contributing |
| Theme vendored as files via `vendor-hextra.sh`; every override copy is hash-guarded; never re-pin only to turn a build green | `AGENTS.md` Repository Rules |
| Theme built-ins over overrides | `CONSTITUTION.md` line 102 |
| Docker only; image tags from Dockerfile hashes; no fixed container names; `SITE_PORT`; builds run with no network | `AGENTS.md` Repository Rules and Build And Dev Commands |
| One CSS file per owner under `assets/css/opm/`, concatenated in lexical order | `AGENTS.md` Patterns |
| Order is `weight`, then title; an overview declares no type; figures are `{{< opm/<name> >}}` | `README.md` Contributing (page rules: workspace `STYLE.md` "Site Pages") |
| The figure recipe | `README.md` Contributing |
| Build against the `site-src` worktrees, never the owner's main checkouts | stays with the change set (`orchestration.md` section 5) |
| The Chroma CUE workaround goes when a Hugo release bundles a fixed Chroma | the header comment of `render-codeblock-cue.html` |

## Open Questions

None for the owner. Settled while implementing, recorded here, and reported only if they touch the interface:
- The static server behind `preview`. Prefer one already in the build image. If none exists, add a pinned package to the Dockerfile.
- The file names of A's own CSS files. The owners' files (`figures.css`, `versions.css`, `typography.css`, `toc.css`, `cards.css`, `landing.css`, `brand.css`) are fixed by the interface, and A's own files take none of those names.
