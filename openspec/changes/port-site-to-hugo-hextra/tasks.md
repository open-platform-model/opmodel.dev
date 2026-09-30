Paths and names used below:
- `<wt>` is `/var/home/emil/dev/open-platform-model/opmodel.dev/.claude/worktrees/port-site-to-hugo-hextra`, on branch `feat/port-site-to-hugo-hextra`, created as `orchestration.md` section 7 step 2 says.
- P is the workspace path `research/docs-site-stacks/hugo-themes/hextra-prototype`. It is read only.
- `SITE_PORT` is 1313.
- Until section 5, never run the bare `image`, `build`, `serve`, `preview`, `shots` or `shots:image` tasks: they belong to Astro.

## 1. Spike on fixtures, then the theme

- [x] 1.1 Add `site/Dockerfile.hugo` from P `Dockerfile` with the same pins (Alpine 3.24.2 by digest, Hugo 0.167.0, Pagefind 1.5.2, git, every download SHA-256-checked). Add a `hugo:image` task that builds it with no context (`docker build -t <tag> - < site/Dockerfile.hugo`) as `opmodel-dev-hugo:<first 12 hex of sha256 of the file>`, only when that tag is missing. Verify: `docker image inspect` finds the tag, and `docker run --rm --network none <tag> version` prints `v0.167.0`.
- [x] 1.2 Write `site/scripts/vendor-hextra.sh` (design decision 2) and run it for v0.13.0. Verify: `site/themes/hextra.COMMIT` names `adf732f8d97cb8e149d4aba232a449d41cd9e38c`. `ls -A site/themes/hextra` lists only `assets data hugo.toml i18n layouts LICENSE static theme.toml`. `find site/themes/hextra \( -name CLAUDE.md -o -name AGENTS.md -o -name 'package*.json' -o -name go.mod \)` prints nothing.
- [x] 1.3 Write the host side (design decision 5): `site/scripts/run-in-image.sh`, plus the tasks `hugo:versions:prepare` (a no-op), `hugo:build`, `hugo:serve` and `hugo:lint:sources`. The tasks resolve `OPM_WS`, `OPM_SRC_<REPO>`, `OPM_SRC_WORKTREE`, `SITE_PORT`, `OPM_REQUIRE_DATES` and `OPM_BUILD_REFS`, with the environment winning over the defaults. `run-in-image.sh` passes `OPM_VERSIONS` into the container only when the caller set it (the internal seam in `orchestration.md` section 6, which B feeds); otherwise it leaves it unset, and `build-all.sh` falls back to `v1.0=/src`. Before any `docker run`, they check every source root. Containers mount `<wt>` at `/work/repo` and each root read-only at `/src/<repo>`, never with `:z`. They run `--rm --init --user <uid>:<gid>` with no `--name`, and `--network none` except `hugo:serve`, which publishes only `127.0.0.1:${SITE_PORT:-1313}`. Verify: `OPM_WS=/nonexistent task -d <wt> hugo:build` and `task -d <wt> hugo:build OPM_WS=/nonexistent` both fail naming `OPM_SRC_OPM` before any container starts, and `/nonexistent` still does not exist afterwards.
- [x] 1.4 Add `site/scripts/lint-sources.sh` as the lint in `orchestration.md` section 4.1, written byte for byte. Verify: `sha256sum site/scripts/lint-sources.sh` prints `dae9717af0c43fc3bdc29a9e730fd171fe7541dab35a9625a35efb1682973c6b`.
- [x] 1.5 Port P `scripts/{build-all,gen-mounts,gen-lastmod,check-pages,check-overrides,serve}.sh` into `site/scripts/`, per design decisions 3, 7 and 12:
  - paths are `/work/repo/site` and `/src`, and the versions come from `OPM_VERSIONS` (default `v1.0=/src`);
  - the site directory is `SITE_DIR` (default `/work/repo/site`), and every script writes only below it, so `test-site.sh` can run the pipeline on a copy (design decision 15);
  - `site/content` is mounted once;
  - there is no MDX conversion, no `index.md` exclusion or remap, and no `.mdx` or `OPM_GEN` branch;
  - the drift guard and then the lint run before Hugo;
  - `check-overrides.sh --update` re-pins the paths already listed in `site/overrides.sha256`, not P's fixed list (design decision 3);
  - A1 covers `x.md` against `x/_index.md`;
  - `check-pages.sh post` writes `site/.check/<v>/nav-order.txt`;
  - Hugo runs as `hugo build --gc --cleanDestinationDir --panicOnWarning --logLevel warn`, never `--quiet`.
- [x] 1.6 Add `site/config/_default/hugo.toml` with only what the fixture needs:
  - `baseURL = 'https://opmodel.dev/'`, `theme = 'hextra'`, and `v1.0` with `defaultContentVersionInSubdir = true` plus the label param (design decision 11);
  - outputs: home html and llms, page and section html and markdown;
  - `refLinksErrorLevel = 'error'` and `enableGitInfo = false`;
  - no passthrough extension, and every CDN-loaded feature off.
- [x] 1.7 Add the first overrides, each with its `site/overrides.sha256` line:
  - `layouts/_markup/render-link.html`, with the v0.13.0 hunk (#1037/#1039) merged;
  - `layouts/_partials/sidebar.html`, ordered by `weight` then title, with unweighted pages last and `sidebar.exclude` kept;
  - `layouts/_partials/opm/docs-main.html` with `layouts/{tutorial,how-to,explanation,reference}/all.html`;
  - `layouts/{page,section}.markdown.md`;
  - the six `layouts/_shortcodes/opm/<name>.html`, as "Figure pending" stubs.

  Verify: the drift guard first fails on `render-link.html` against v0.13.0. After the hunk is merged and the file re-pinned, it passes. Write that diff's gist into design.md decision 3.
- [x] 1.8 Move the site-owned pages to Hugo form (design decision 6):
  - `git mv` the nine `site/content/docs/**/index.md` to `_index.md`;
  - each gets `weight` equal to its old `sidebar.order`, and `reference`, `reference/cli` and `reference/definitions` get a `description`;
  - remove every `sidebar:` block and every `type:`, and the four hand links in `reference/_index.md`;
  - replace `site/content/index.mdx` with `site/content/_index.md` (hextra-home, today's landing text, from P `site/content/_index.md`).

  Verify: `find site/content -name 'index.md*'` prints nothing, and `grep -rn 'sidebar:\|type:' site/content` prints nothing.
- [x] 1.9 In `site/.gitignore`, ignore `public/`, `resources/`, `.hugo_build.lock`, `data/opm/`, `config/production/`, `config/development/`, `.gen/` and `.check/`. `.versions/` and `.shots/` are already listed. Add the same paths to `task clean`. Verify: after a fixture build, `git -C <wt> status --short` shows no generated file.
- [x] 1.10 Add the fixture workspace `site/tests/fixtures/ws/{opm,core,catalog_opm,cli,library,opm-operator}/docs/site/`, in the dialect (design decision 15). It holds:
  - `opm`: the docs home `_index.md`; `start/_index.md` with the six `{{< opm/<name> >}}` lines and an escaped `{{</* opm/helm-and-opm */>}}` in a `text` fence; `start/zeta-first.md` (weight 1) and `start/alpha-second.md` (weight 2); `start/quickstart.md` (tutorial);
  - `start/quickstart.md` carries a `> [!TIP]` alert with a bold title line, a two-paragraph `> [!NOTE]` alert, an inline link `/docs/concepts/fixture-concept/#why`, a reference-style link, and a CUE block with `""`;
  - `core`: `concepts/fixture-concept.md`, plus `concepts/brief-only.md`, whose body is only a planning comment containing `>=` and `->`;
  - one page in each other repo, so that the four page types all occur.

  Verify: `sh <wt>/site/scripts/lint-sources.sh` over the six fixture `docs/site` trees prints `opm-dialect-lint: OK`.
- [x] 1.11 Keep planning comments out of the output with mechanism (b) (design decision 10): set `[minify] minifyOutput = true` and `disableSVG = true` in `site/config/_default/hugo.toml` (the build command in 1.5 has no `--minify`), keep P's comment stripping in `page.markdown.md` and `section.markdown.md`, and add the hash-guarded `layouts/llms.txt` override that prints `.Description`. Switch to (a) only if (b) leaves comment text in some output. Add check 10. Verify on the fixture build: no `*.html`, `*.txt`, `*.md`, `*.xml` or `*.json` under `site/public/` contains `<!--` or any word unique to the fixture brief, `/v1.0/llms.txt` included. Also verify the ModuleToCluster figure keeps the space before its `<tspan>`: the built HTML contains `component <tspan` (not `component<tspan`). Record the mechanism in design.md decision 10.
- [x] 1.12 Add a minimal `hugo:test:site` (`site/scripts/test-site.sh`, in the image, no network). It runs each case on a copy of the site under `site/.check/tests/<case>/` with `SITE_DIR` set to that copy, so in the worktree it writes only under `site/.check/tests/` (design decision 15).
  - Lint cases: one failing tree per O4 rule under `site/tests/lint/`: `.mdx`, a `:::` line, `import ... from`, `sidebar:`, `index.md`, a missing `title`, a missing `description`, a missing `type`, an invalid `type`, a `type` on an `_index.md`, an unknown `opm/` shortcode. Each must fail naming file and line.
  - Fixture-build assertions:
    - both alerts in `quickstart` render as Hextra alerts with the bold title, and no literal `[!` is left;
    - the six shortcodes render and no literal `{{<` is left outside the escaped example;
    - `nav-order.txt` puts `zeta-first` before `alpha-second`, and the site-owned sections in `weight` order;
    - the link renders as `/v1.0/docs/concepts/fixture-concept/#why`;
    - a page linking `/docs/concepts/nope/` fails the build with `broken internal link`. That page sits in its own failing tree under `site/tests/checks/`, which `test-site.sh` builds on top of the fixture workspace and expects to fail. It never goes into `site/tests/fixtures/ws`, which must build green for the 1.14 gate;
    - `llms.txt` is clean.

  Verify: `task -d <wt> hugo:test:site` prints `ok` for every case.
- [x] 1.13 Run the spike items 1-8 in design.md "Unverified assumptions" and write each answer there. For item 6:
  - start `OPM_WS=<wt>/site/tests/fixtures/ws task -d <wt> hugo:serve </dev/null` in its own process group (`setsid`);
  - wait until `curl -sf http://127.0.0.1:1313/v1.0/docs/` answers;
  - send one SIGINT to that process group, as a terminal's Ctrl+C does;
  - verify it exits within 10 s, and `docker ps --filter ancestor=<hugo tag>` lists no container.
- [x] 1.14 Run `task -d <wt> check`, `OPM_WS=<wt>/site/tests/fixtures/ws task -d <wt> hugo:build` and `task -d <wt> hugo:test:site`; all must be green. Then commit `build(site): vendor hextra v0.13.0 and prove the hugo pipeline on fixtures`, with a body line saying that the site-owned pages move to Hugo form here (design decision 6).

**Stop after section 1.** Report to the supervisor with the block in `orchestration.md` section 7 step 6, with `sections: 1/5`. Its `deviations` line names the move of the site-owned content into section 1: the change-set plan put it in section 2, and design decision 6 gives the reason. Add the spike answers and the dialect evidence from 1.12: bold-title alerts, parameterless shortcodes, a source `_index.md` ordered by `weight`, and root-absolute links through the hook. Then wait. The S PRs merge on this report. Section 2 starts only when the supervisor releases it.

## 2. The Hugo pipeline on the real sources

Starts when S1-S6 are merged and the six `site-src` worktrees exist (`orchestration.md` section 5). Every build here runs as `OPM_SRC_WORKTREE=site-src task -d <wt> hugo:build`. The Astro code stays in the tree, and it is not a gate. This section has no visual gate; browser QA lands in section 4.

- [x] 2.1 Complete `site/config/_default/hugo.toml` from P `site/config/_default/hugo.toml` (design decisions 11 and 13):
  - neutral skin only, with no skin switch;
  - `params.search.type = 'pagefind'`;
  - navbar logo params with `displayTitle`;
  - `editURL` off and code copy on;
  - the `params.opm` github and repos keys;
  - the menus Docs, Reference, Search, GitHub and Theme;
  - Mermaid, KaTeX, MathJax, asciinema, PhotoSwipe and medium-zoom explicitly off.
- [x] 2.2 Port the remaining P overrides, each copy with its `site/overrides.sha256` line:
  - `layouts/_partials/navbar-title.html`. It keeps upstream's `params.navbar.displayTitle` switch and the logo `alt` text (`cond $displayTitle ...`) and adds the version label. It keeps P's class hooks `opm-brand` (the wrapper), `opm-title-long` and `opm-title-short` (the two title spans), which the brand-marks change's `brand.css` selects.
  - `layouts/_partials/banner.html`;
  - `layouts/_partials/components/last-updated.html`. It links "Edit" to `edit/main` and shows the git date. "View source" appears only when `viewURL` is set.
  - `layouts/_partials/scripts/search.html` with `assets/js/opm-pagefind.js`, and no FlexSearch;
  - `layouts/404.html`;
  - `layouts/_markup/render-codeblock-cue.html`, which pins `render-codeblock.html`;
  - `layouts/robots.txt`, `layouts/sitemap.xml` and `layouts/_partials/custom/content-begin.html`.

  Verify: the build's drift-guard line reports every pinned file unchanged. `grep -rniE 'flexsearch|passthrough|skin-default|opm.skin' <wt>/site/config <wt>/site/layouts <wt>/site/assets` prints nothing.
- [x] 2.3 Add the OPM partials (design decisions 8, 9 and 11):
  - `opm/source.html` maps a source file by its `<repo>/docs/site/` path segment (`/src/<repo>/docs/site/` in a normal build), and any other content file to `opmodel.dev` `site/content/` (design decisions 11 and 15);
  - `opm/version-links.html`;
  - `opm/version-switch.html` shows a plain "v1.0 (beta)" label with one version;
  - `opm/section-children.html`, called from `opm/docs-main.html` on section pages, orders by `weight` then title;
  - `opm/build-stamp.html`, through `layouts/_partials/custom/footer.html`;
  - `opm/check-front-matter.html`, through `custom/head-end.html`, only for pages backed by a content file (`with .File`) of kind `page`, `section` or `home`. The 404 page, taxonomy and term pages, and a section with no `_index.md` also render `head-end` but have no front matter to check.

  Verify on the build: the header shows "v1.0 (beta)". The build is green with `site/public/v1.0/404.html` present. `/v1.0/docs/reference/` lists its child pages. A cli page's "Edit this page" link is `https://github.com/open-platform-model/cli/edit/main/docs/site/<path>`.
- [x] 2.4 Split P `site/assets/css/custom.css` and `skin-neutral.css` into `site/assets/css/opm/*.css` (design decision 13). `custom/head-end.html` concatenates them in lexical order, minifies and fingerprints them, and keeps only the font preload and the `/latest/` stubs from P. It no longer publishes `_redirects`: P's version writes `/ <home RelPermalink> 302`, which comes out as `/ /v1.0/ 302`, and `build-all.sh` owns that file (2.6). Add `site/static/fonts/` (Geist 1.4.2 and `GEIST-LICENSE.txt`), P's placeholder `site/static/favicon.svg` and `site/static/images/{opm-mark.svg,opm-mark-dark.svg,og-default.png}`, and `site/NOTICE`. Verify: the built HTML links exactly one fingerprinted stylesheet from `css/opm`, and Geist Mono ligatures are off for `code` and `pre` in the built CSS.
- [x] 2.5 Port the figure: `layouts/_partials/opm/figure.html`, `layouts/_partials/opm/figures/module-to-cluster.html`, and the `--opm-fig-*` tokens in `assets/css/opm/figures.css`, following `html.dark`. The `module-to-cluster` shortcode renders it; the other five stay stubs. Verify: `/v1.0/docs/start/` holds a `figure` with `svg[role=img]` whose `aria-label` equals its caption, and one "Figure pending" stub per other figure that the page uses.
- [x] 2.6 Publish the root files and version outputs from the version list (design decision 11): `_redirects` (`/ /latest/ 302`, `/latest/* /v1.0/:splat 302`), a root `index.html` refresh to `/latest/`, the `/latest/` stubs, a root `404.html`, `robots.txt`, and Pagefind once per version name, with no `v*/` glob. Verify:
  - `site/public/{_redirects,index.html,404.html,robots.txt}` and `site/public/v1.0/pagefind/` exist;
  - `site/public/_redirects` holds exactly the two lines `/ /latest/ 302` and `/latest/* /v1.0/:splat 302`, and no `/ /v1.0/` line;
  - the root `site/public/index.html` refreshes to `/latest/`;
  - `site/public/latest/docs/index.html` refreshes to `/v1.0/docs/`.
- [x] 2.7 Build stamp: the host resolves `OPM_BUILD_REFS`, and `build-all.sh` writes `site/data/opm/build.json` and `site/public/build-stamp.json`. Verify: the six SHAs in `build-stamp.json` equal `git -C /var/home/emil/dev/open-platform-model/<repo>/.claude/worktrees/site-src rev-parse HEAD` for each repo, and the footer shows their short forms.
- [x] 2.8 Complete the checks and the rest (design decision 12):
  - checks 3, 7, 8, 9, 11, 12 and 13;
  - the build summary with the page count per version and the total file count;
  - the per-version `site/.gen/<v>/` mount when present;
  - a `hugo:preview` task, which serves `site/public/` on `SITE_PORT` and publishes nothing on 4321.

  Verify: `curl -sf http://127.0.0.1:1313/v1.0/docs/` answers during `task -d <wt> hugo:preview`.
- [x] 2.9 Check the build against the real sources:
  - the lint reports no finding, and `check-pages` reports OK;
  - the `v1.0` page count equals the `.md` files in the six `site-src` `docs/site` trees plus the 10 site-owned pages. Count both at build time; the source repos keep adding pages, so no fixed number is the target;
  - `/v1.0/llms.txt` and every text output hold no planning comment;
  - `task -d <wt> hugo:test:site` is still green.
- [x] 2.10 Run `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> hugo:build` and `task -d <wt> hugo:test:site`; all must be green. Then commit `feat(site): build the docs with hugo and hextra beside astro`.

## 3. Checks and their regression tests

- [x] 3.1 Add a failing tree under `site/tests/lint/` for each rule beyond O4's list, plus one clean tree that passes:
  - front-matter keys `aliases`, `draft` and `slug`;
  - relative, `.md`, version-prefixed and slashless `/docs/` links, inline and as reference definitions;
  - raw `href=` and `src=`;
  - `![...]` and `<img>`;
  - a non-`.md` file, and a symlink created at test time;
  - a non-kebab-case name;
  - `weight: 0` and a non-integer weight;
  - `> [!NOTE] Title` and `> [!NOTE]-`;
  - an untagged fence;
  - a component tag;
  - `import ... from` and `:::` inside a fence.

  Verify: each failing tree prints its file and line, and exits 1.
- [x] 3.2 Add one failing case per build check under `site/tests/checks/`:
  - (1) a scratch copy of the theme with one pinned file changed;
  - (3) a site-owned test page with a missing description, a leaf with an invalid type, and an `_index.md` with a type;
  - (4) a broken link;
  - (5) `x.md` against `x/_index.md`;
  - (6) a missing page and an unexpected page;
  - (7) a stray file in a site-owned test mount, with a non-page extension;
  - (8) `reference/cli/foo.md` in a fixture source repo;
  - (9) a raw `:::` in the output;
  - (10) a planning comment reaching an output;
  - (11) a CDN URL;
  - (12) a missing redirect file;
  - (13) a page with no git date under `OPM_REQUIRE_DATES=1`.
- [x] 3.3 Add `site/tests/dialect/`. It checks that alerts with a bold title line render as Hextra alerts, and that the line after a CUE `""` is tokenised as a name, not swallowed by a string (`render-codeblock-cue.html`).
- [x] 3.4 Complete `site/scripts/test-site.sh` (design decision 15). It reads no input from `/proto` or the host's `/tmp`, and only fixtures under `site/tests/`: never `site-src` or a main checkout. The container's own `/tmp`, which the lint's `mktemp` uses, is fine. It runs every case on its own copy under `site/.check/tests/<case>/`, so in the worktree it writes only under `site/.check/tests/`. It builds its own prerequisites, prints `ok` or `FAIL` per case, and exits non-zero on any unexpected result. Add `hugo:ci`: `check`, `hugo:image`, `hugo:build`, `hugo:test:site`. Verify: after `task -d <wt> clean`, `task -d <wt> hugo:test:site` is green and prints `ok` for every case in 1.12 and 3.1-3.3, and `git -C <wt> status --short --ignored site` then lists no generated path outside `site/.check/`.
- [x] 3.5 Run `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> hugo:build` and `task -d <wt> hugo:test:site`; all must be green. Then commit `test(site): prove each build check fails when it should`.

## 4. Browser QA

- [x] 4.1 Add `site/tests/browser/Dockerfile`: Playwright python 1.63.0 by digest, and axe-core 4.10.3 from its npm registry tarball, checked by SHA-256, with no npm and no committed copy. Add a `hugo:qa:image` task that tags it `opmodel-dev-qa:<first 12 hex of sha256 of the file>` and builds it only when that tag is missing (design decision 4). Verify: `docker image inspect` finds the tag, and a second `task -d <wt> hugo:qa:image` builds nothing.
- [x] 4.2 Add `site/tests/browser/shots.py`, ported from `site/shots/shoot.py` and P `scripts/shots.py`:
  - it serves `site/public/` inside the container and publishes no port;
  - it reads the default version from the build output, not a glob;
  - it sets the theme with Hextra's `color-theme` key;
  - it shoots every page with a figure, plus the landing, one docs page, the 404 page and the open search palette;
  - each in six variants (light, dark, switch-dark-os-light, switch-light-os-dark, phone-light, phone-dark), into `site/.shots/<page>/<n>-<variant>.png`, where `<n>` numbers only drawn figures (`figure:has(svg[role="img"])`, as `shoot.py` selects them) in page order, so a "Figure pending" stub takes no number;
  - it fails when any SVG text is under 9 px at 390 px.
- [x] 4.3 Add `site/tests/browser/a11y.py` and `site/tests/browser/search.py`. `a11y.py` runs axe on key pages for WCAG 2.1 A and AA, light and dark, and fails on any violation. `search.py` runs a query in `v1.0` and fails when the expected page is not among the first results.
- [x] 4.4 Add `hugo:shots` (`hugo:qa:image` and a build first, then `shots.py`) and `hugo:qa` (shots, a11y and search), run with `--network none`, `--user <uid>:<gid>` and no published port. Verify: during `task -d <wt> hugo:qa`, `docker ps` shows no port mapping for the QA container.
- [x] 4.5 Run `OPM_SRC_WORKTREE=site-src task -d <wt> hugo:qa` and read the PNGs: light, dark, both theme/OS mismatches and phone, for the landing, `/docs/start/`, one docs page and the 404 page. Fix what they show, in this change's own files only.
- [x] 4.6 Run `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> hugo:build`, `task -d <wt> hugo:test:site` and `OPM_SRC_WORKTREE=site-src task -d <wt> hugo:qa` (PNGs read); all must be green. Then commit `test(site): screenshot and smoke-test the hugo build`.

## 5. Cutover

- [x] 5.1 Delete the Astro site:
  - `site/astro.config.mjs`, `site/package.json`, `site/package-lock.json`, `site/tsconfig.json`, `site/.dockerignore` and `site/versions.config.mjs`;
  - the Astro `site/Dockerfile`;
  - `site/src/`;
  - `site/scripts/{build-versions,prepare-versions,serve,sources,stage-version}.mjs`;
  - `site/shots/`.

  Then `git mv site/Dockerfile.hugo site/Dockerfile`. Verify: `git -C <wt> ls-files site | grep -E '\.(mjs|astro|ts)$|package(-lock)?\.json$|tsconfig\.json$|^site/(src|shots)/|^site/\.dockerignore$'` prints nothing.
- [x] 5.2 In `Taskfile.yml`:
  - remove `IMAGE`, `SHOTS_IMAGE` and `SITE_RUN`, and the Astro tasks `image`, `serve`, `build`, `preview`, `shots:image` and `shots`;
  - rename every `hugo:<name>` to `<name>`;
  - make `clean` remove generated paths only;
  - keep `deps`, `build:docgen`, `generate*`, `fmt`, `vet`, `test`, `openspec:check` and `check` as they are.

  Rename any `hugo:` task reference in `site/scripts` and `site/tests` too. Verify:
  - `grep -nE 'opmodel-dev-site|opmodel-dev-shots|4321|SITE_RUN|hugo:' <wt>/Taskfile.yml` prints nothing;
  - `grep -rn 'task hugo:' <wt>/site/scripts <wt>/site/tests` prints nothing;
  - `task -d <wt> image` finds the section-4 tag already present and builds nothing, and `task -d <wt> qa:image` does the same for the QA image.
- [x] 5.3 Rewrite `site/.gitignore` for the Hugo site only: drop `node_modules/`, `dist/`, `.astro/`, `src/content/docs/` and `src/generated/`. Verify: after a build, `git -C <wt> status --short` shows no generated file.
- [x] 5.4 Rewrite `README.md` for the Hugo site (design decision 16):
  - the stack, the architecture and the prerequisites;
  - a quick start with `task serve` on http://127.0.0.1:1313/ and the `site/public/` output;
  - the tree and the task list, with `OPM_SRC_WORKTREE`;
  - a `## Contributing` section with three parts: Preview; Page dialect (the workspace `STYLE.md` "Site Pages", `task lint:sources`, and "fix the page, never the lint"; order by `weight` then title; an overview declares no type); and Adding a figure (the recipe).
- [x] 5.5 Rewrite `AGENTS.md`: Purpose, Repository Rules, Repository Layout (drop the stale `adr/`, `getting-started/` and `guides/`), Environment Notes, Build And Dev Commands, Technology stack and Patterns. Keep the attribution, bare-`@name` and 250-word PR rules word for word. Land these durable decisions from design.md:
  - `## Durable decisions`: the stack ("Hugo + Hextra v0.13.0, neutral skin, chosen 2026-09-30; see the workspace `research/docs-site-stacks/hugo-themes/`"), the URL layout, and the reserved `docs/reference/{cli,definitions}/` sections;
  - Repository Rules: the lint bytes, the vendored theme and drift guard, and Docker only (hash tags, no fixed names, `SITE_PORT`, no network in builds);
  - Patterns: one CSS file per owner under `assets/css/opm/`.
- [x] 5.6 Update `CONSTITUTION.md` lines 5, 30, 53 and 153 to the Hugo site. Change line 102 to "Theme built-ins over overrides; every override copy is hash-guarded".
- [x] 5.7 Update `TODO.md`:
  - the line 5 banner and the "Astro Site" block;
  - 1.2 (Hugo front matter), 1.3 (a Hugo content adapter, `_content.gotmpl`), 1.4 (the stack and its date) and 1.5 (`site/public/`, port 1313);
  - 2.2 (Hugo partials and shortcodes instead of `.astro` components), 3.1 (`site/public/`) and 3.4 (one `v1.0` from `main`; tag-based versions are change `version-site-from-tags`);
  - the Future items the site now has: search, dark mode, mobile layouts, the WCAG 2.1 AA smoke test and the link check;
  - the Astro and Starlight references, and Next Immediate Steps item 2.

  Leave 3.2 (hosting) to the deploy change.
- [x] 5.8 docgen wording: "Starlight front matter" becomes "Hugo front matter" in `internal/cobradoc/generator.go` (lines 2, 9 and 13) and `cmd/docgen/main.go` (line 38). On line 13, "(title, description, sidebar order)" also becomes "(title, description, weight)". Comments and help text only. Verify: `grep -rn 'sidebar' <wt>/cmd <wt>/internal` prints nothing.
- [x] 5.9 In `openspec/config.yaml`, delete the paragraph that starts "Until `port-site-to-hugo-hextra` lands its cutover section" (lines 108-112) and the clause "the Astro site that came before it is being replaced" (lines 10-11). Verify: `grep -n 'Until .port-site-to-hugo-hextra\|Astro' <wt>/openspec/config.yaml` prints nothing, and `cd <wt> && openspec validate --all --strict --no-interactive` is green.
- [x] 5.10 Sweep for leftovers: `grep -rniE 'astro|starlight|site/dist|4321' <wt>/README.md <wt>/AGENTS.md <wt>/CONSTITUTION.md <wt>/TODO.md <wt>/Taskfile.yml <wt>/cmd <wt>/internal <wt>/site/scripts <wt>/site/tests <wt>/site/config <wt>/site/layouts`. Verify: every hit is read, and every remaining hit names the retired stack on purpose. Then run `grep -rniE 'sidebar[ .]order' <wt>/README.md <wt>/AGENTS.md <wt>/CONSTITUTION.md <wt>/TODO.md <wt>/cmd <wt>/internal`: every hit is read, and every remaining one names the retired field on purpose. A bare `sidebar` is not swept: `sidebar.html`, `sidebar.exclude` and Hextra's sidebar classes are live Hugo names.
- [x] 5.11 Run `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci` and `OPM_SRC_WORKTREE=site-src task -d <wt> qa` (PNGs read); all must be green. Then commit `feat(site)!: retire the astro site`.

## After section 5

No checkboxes here: these steps follow `orchestration.md` section 7.
- **Verify.** Read `<wt>/.claude/skills/openspec-verify-change/SKILL.md` and follow it for `port-site-to-hugo-hextra`, running every `openspec` command as `cd <wt> && openspec ...`. Report with the block in step 6, with `sections: 5/5`. Its `deviations` line names the `qa:image` task and its network use (design decision 4), and the refinements that design.md "Interface" lists (`SITE_DIR`, the navbar class hooks, the shot numbering). Then stop and wait.
- **Then.** Everything past the verify follows `orchestration.md` section 7, steps 7 and 8, and only on the supervisor's word.
