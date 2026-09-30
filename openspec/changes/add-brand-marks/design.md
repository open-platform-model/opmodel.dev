## Context

This change starts on `main` after A (`port-site-to-hugo-hextra`) has merged. The Hugo site then renders on Hextra v0.13.0 (neutral skin), vendored in `site/themes/hextra/`. The proposal says why the marks are needed. Only the state that shapes the approach is recorded here.

- **Favicons.** Hextra's `head.html` calls `partialCached "favicons.html"`. That partial links `favicon.ico`, `favicon.svg`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png` and `site.webmanifest`, each through `relURL`. The theme's `static/` holds those files, plus the `android-chrome-192x192.png` and `-512x512.png` its manifest names (`"name": "Hextra"`). These were read at the prototype's pin, 275e2ad; section 1 re-reads them at v0.13.0.
- **Dark favicon.** Hextra's `assets/js/core/favicon.js` swaps `favicon.svg` for `favicon-dark.svg`, following the OS `prefers-color-scheme`, but only when `static/favicon-dark.svg` exists.
- **Navbar.** A's override `site/layouts/_partials/navbar-title.html` is owned by B. It keeps upstream's `params.navbar.displayTitle` and `displayLogo` switches, the `params.navbar.logo.{path,dark,width,height}` keys and the logo `alt` text (orchestration.md section 6). It shows the light logo with `hx:block hx:dark:hidden` and the dark logo with `hx:hidden hx:dark:block`, so the logo follows the site toggle (`html.dark`), not the OS.
- **Open Graph.** Hextra's `opengraph.html` takes `index site.Params.images 0` when a page sets no `images`. It strips a leading `/`, applies `relURL`, then `absURL`.
- **Twitter card.** Hextra's `head.html` calls `twitter_cards.html`, and Hextra ships no copy, so Hugo's embedded template renders it. That template reads the same `site.Params.images` through `_funcs/get-page-images` but applies `absURL` to the path as written, leading `/` kept. So `twitter:image` can resolve differently from `og:image`, and each is checked on its own.
- **Navbar logo URL.** `navbar-title.html` writes each logo `src` as the param path through `relURL`. Static files publish once at the root (trap 9), so a version-prefixed `src` would name no file.
- **CSS.** Every `site/assets/css/opm/*.css` file is concatenated in the head hook, so adding `brand.css` edits no list (orchestration.md section 6, "CSS").
- **QA image.** It is `site/tests/browser/Dockerfile` (Playwright python 1.63.0 by digest), built as `opmodel-dev-qa:<12 hex>` for `task qa`. It holds Chromium and Python 3. The build image holds no rasteriser.
- **Prototype placeholders** (`research/docs-site-stacks/hugo-themes/hextra-prototype/`, read-only).
  - `site/static/favicon.svg` and `site/static/images/opm-mark{,-dark}.svg`: a stacked-layers glyph with strokes at 70% and 45% opacity.
  - `site/static/images/og-default.png`.
  - `tools/og-card.{py,html}`: blue and orange radial gradients (the dropped default skin); paths under `/proto`.
  - `params.images` and `[params.navbar.logo]` in its `hugo.toml`.
  - A's plan does not say whether it ports these. Section 1 records what `main` holds.

Files under `site/` this change touches:

| File | Action |
|---|---|
| `site/static/favicon.svg` | drawn (replaces the placeholder, or added) |
| `site/static/{favicon.ico,favicon-16x16.png,favicon-32x32.png,apple-touch-icon.png,android-chrome-192x192.png,android-chrome-512x512.png}` | generated, new in `site/static/` (they shadow the theme's) |
| `site/static/site.webmanifest` | hand-written, new (shadows the theme's) |
| `site/static/images/opm-mark.svg`, `opm-mark-dark.svg` | drawn (replace the placeholders, or added) |
| `site/static/images/og-default.png` | generated (replaces the placeholder, or added) |
| `site/tools/og-card.py`, `og-card.html` | adapted from the prototype, or edited if A ported them |
| `site/tools/favicons.py` | new |
| `site/config/_default/hugo.toml` | `[params.navbar]` logo keys; `params.images`; `params.description` only if missing |
| `site/assets/css/opm/brand.css` | new |

**Build inputs.** The build gains static files only. It gains no mount, no source repo, no vendored file and no pinned tool. The override set (`site/overrides.sha256`) is unchanged, and so is the version set. Published URLs: the same root-level favicon and manifest names Hextra publishes today, now with OPM content, plus `/images/opm-mark.svg`, `/images/opm-mark-dark.svg` and `/images/og-default.png`.

## Goals / Non-Goals

**Goals:**
- An original mark, legible from 16 px to 512 px, in the neutral skin's two inks.
- A wordmark that stays text.
- Every favicon a browser, iOS or Android requests is OPM's, and the web manifest names OPM.
- A 1200x630 monochrome card for shared links.
- Every generated file can be regenerated with one task, offline, in an image the repo already pins.

**Non-Goals:**
- Per-page OG images, landing copy or a landing hero mark (D owns the landing).
- Any theme override, and any edit to `navbar-title.html` or `banner.html` (owned by B).
- A new build check. A permanent check that head asset URLs resolve belongs in `site/scripts/check-pages.sh`, which A owns and B edits (see Open Questions).
- A brand guide beyond the README heading.

## Decisions

### 1. Replace the theme's static files by name; override no theme file

Hugo publishes the project's `static/` over the theme's `static/` for the same path. The site therefore ships `site/static/favicon.ico` and the rest under Hextra's exact names, and `favicons.html` keeps linking them.

- Why: no theme copy, no `overrides.sha256` line, and a Hextra re-pin cannot silently drop our files.
- Alternative rejected: an override of `favicons.html` that points at other names. It adds a hash-guarded copy (trap 14) for no gain.
- Section 1 proves the precedence under A's generated mounts (assumption A2 below).

### 2. One tiled favicon for every tab strip; no `favicon-dark.svg`

`favicon.svg` is the mark in `#fafafa` on a `#0a0a0a` rounded tile. It MUST NOT depend on the page's theme or the OS theme.

- Why:
  - the PNG, ICO, apple-touch and Android icons cannot switch themes, so one tiled design is the only thing consistent across all formats;
  - a tab strip belongs to the browser chrome, not to the page, so following the site toggle would be wrong there anyway;
  - with no `static/favicon-dark.svg`, Hextra's `favicon.js` stays inert.
- Alternatives rejected:
  - a `prefers-color-scheme` rule inside `favicon.svg`: browsers differ in whether they honour it in a favicon, and the rasters cannot follow it;
  - Hextra's `favicon-dark.svg` swap: a second file and a JS path, for a tab icon that already reads on both strips because the tile carries its own contrast.

```text
favicon.svg                  viewBox 0 0 24 24; rounded tile #0a0a0a; the mark in #fafafa, inset to about 70%
favicon-16x16.png, -32x32    rendered from favicon.svg; transparent outside the tile
favicon.ico                  PNG frames of 16, 32 and 48 px, rendered from favicon.svg
apple-touch-icon.png (180)   full-bleed #0a0a0a square, the mark at about 60%, centred; opaque
android-chrome-192/512       same composition as apple-touch; opaque
```

Opaque squares: iOS fills transparent pixels with black and applies its own mask, so these icons carry no rounded corners and no alpha.

### 3. The mark: one path set, two inks, shown through params

`opm-mark.svg` (`#0a0a0a`) and `opm-mark-dark.svg` (`#fafafa`) carry identical path data. An `<img>` SVG cannot inherit `currentColor` from the page, so Hextra's logo contract needs two files.

```toml
[params.navbar]
  displayLogo = true
  displayTitle = true
  [params.navbar.logo]
    path = 'images/opm-mark.svg'
    dark = 'images/opm-mark-dark.svg'
    width = 24
    height = 24
```

**Mark brief** (what the drawing MUST follow):
- **Original.** Drawn from simple geometry for OPM, not traced or adapted from an icon set. The prototype's placeholder is a generic stacked-layers glyph of the kind icon sets ship; the mark replaces it, not refines it. Hextra's hexagon, the Kubernetes wheel and the CUE logo are out too.
- **One ink at full opacity.** Shapes are separated by gaps, not by tints or opacity, so the mark survives 16 px and reverses cleanly onto the tile.
- **Grid.** `viewBox="0 0 24 24"`, square. No stroke, gap or feature narrower than 2.5 units. Filled shapes are preferred over strokes.
- **Legible** at 16 px (inside the favicon tile), 24 px (navbar), 64 px and 512 px, in both inks and reversed on the tile.
- **Hygiene.** Only `<svg>`, `<path>`, `<rect>`, `<circle>`, `<polygon>` and `<g>`; a single `xmlns="http://www.w3.org/2000/svg"`. No `<text>`, `<style>`, `<script>`, `href`, comments, `xlink` or editor namespaces. Under 1 KB. The supply-chain and planning-comment checks scan text outputs, so a published SVG stays free of both.
- **Candidates.** Up to three are drawn and compared on a contact sheet. The committed one is the worker's recommendation, and the others travel only in the report for the owner.

### 4. The wordmark is live text, typeset in `brand.css`

The wordmark is `.Site.Title` ("Open Platform Model"), set in Geist, with "OPM" at phone width wherever A's override provides a short title.

- Why:
  - it stays sharp at every size and follows the theme toggle with no second file;
  - screen readers read it once;
  - the OG card sets the same words in the same font.
- Alternative rejected: an outlined SVG wordmark. That means two more files, text that goes stale when the title changes, and an image that duplicates the title for screen readers.

`brand.css` rules:
- It MUST select only the class hooks A's `navbar-title.html` emits, recorded in section 1. The prototype's are `.opm-brand`, `.opm-title-long` and `.opm-title-short`.
- It MUST NOT select Hextra's `hx:` utility classes. They are not a contract and change with Hextra releases.
- It is unlayered, so it beats Hextra's `@layer utilities` without `!important` (trap 12).
- It MUST NOT restyle the version switch (B's `versions.css`).

Starting values, for the owner's review:

```css
.opm-brand .opm-title-long,
.opm-brand .opm-title-short { font-weight: 600; letter-spacing: -0.01em; }
```

### 5. Rasters are generated in the QA image, offline, and committed

`site/tools/favicons.py` and `site/tools/og-card.py` run in the QA image through `task brand:favicons` and `task brand:og`.

- Docker flags: `--rm --init --network none --user <uid>:<gid>`, with the worktree at `/work/repo`. No `--name`, no published port and no `:z`. They mirror A's `qa` invocation, including its `HOME` handling, and build the QA image the way `task qa` does.
- Why the QA image: rasterising SVG needs a browser engine, and that image already pins Chromium by digest. There is no new image, pin or network fetch.
- Why commit the output: the build image has no rasteriser, and the site build must not depend on Chromium. The tools run on demand. CI never runs them, and no gate compares their bytes, because Chromium output can differ between runs.
- `favicon.ico` is packed with Python's `struct` from PNG frames. It relies on no Pillow, because the image runs offline and nothing may be installed at run time.
- Why a second tool, beyond the plan's `og-card`: the PNG and ICO set must come from the mark reproducibly. A hand export cannot be reviewed or repeated after a redraw.

### 6. The Open Graph card

`og-card.html` is a template that `og-card.py` fills, then screenshots at 1200x630 into `site/static/images/og-default.png`.

- **Text.** The title and description come from `site/config/_default/hugo.toml` (`title`, `params.description`), read with Python's `tomllib`, so the card cannot drift from the site's own text.
- **Mark.** Inlined from `site/static/images/opm-mark-dark.svg`.
- **Fonts.** Geist and Geist Mono from `/work/repo/site/static/fonts/`.
- **Colours.** The neutral skin's: background `#0a0a0a`, text `#fafafa`, secondary text `#a3a3a3`, footer `#737373`. No gradients.
- **Layout.** The mark and "Documentation" at top left, the title, the description, and `opmodel.dev` in Geist Mono at the foot.
- **No version label.** One image serves every version and would go stale.

```toml
[params]
  images = ['/images/og-default.png']   # root-relative; see assumption A3
```

If section 1 shows that the root-relative form does not resolve to the file for `og:image` or for `twitter:image`, write `https://opmodel.dev/images/og-default.png` instead. Both templates pass an absolute URL through unchanged. Record the choice here.

### 7. The web manifest

```json
{
  "name": "Open Platform Model",
  "short_name": "OPM",
  "start_url": "/",
  "display": "browser",
  "icons": [
    { "src": "android-chrome-192x192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "android-chrome-512x512.png", "sizes": "512x512", "type": "image/png" }
  ],
  "theme_color": "#0a0a0a",
  "background_color": "#0a0a0a"
}
```

- `display: browser`: a docs site has no reason to install as an app. The icons still serve home-screen shortcuts.
- `start_url: "/"` follows the root redirect to `/latest/`.

### 8. The owner reviews the marks once, in the final report

The migration plan sends section 1's shots to the owner. They reach the owner in the final report, not in a stop after section 1.

- The contact sheet (task 1.4), the QA shots and the review sheet (task 2.8) travel together in the final report under `questions:` ("owner review of the marks").
- The worker does not report or stop after section 1.
- Why:
  - orchestration.md section 7 gives only A an interim report;
  - the merge already waits on the owner's approval (orchestration.md section 2);
  - a redraw is cheap: three SVGs, two tasks and one commit (Risks). A stop after section 1 would idle the worker and save only a rerun of the two tasks.
- Alternative rejected: an interim report with `sections: 1/2` after section 1, the way A reports.

### Assumptions section 1 verifies (spike)

| # | Assumption | Check | If it fails |
|---|---|---|---|
| A1 | What A shipped: placeholder files, `params.images`, `params.description`, `[params.navbar.logo]`, `site/tools/og-card.*`, the class hooks in `navbar-title.html`, the Geist files in `site/static/fonts/`, the QA image task and its `docker run` flags | Read the files on `main` | Missing hooks: stop and report (B owns the file). Anything else: adapt, and record it here |
| A2 | `site/static/` wins over `site/themes/hextra/static/` under A's generated mounts | A throwaway `site/static/favicon.svg`, built; `cmp` it against `site/public/favicon.svg` | Stop and report: the fix would add a theme override or touch A's mounts |
| A3 | Head and navbar asset URLs resolve at the root under the versions dimension | In `site/public/v1.0/index.html` and one deep docs page, every `<link rel="icon">`, `rel="apple-touch-icon"`, `rel="manifest"` href, both navbar logo `<img src>` values, and the `og:image` and `twitter:image` URLs map (host stripped) to a file under `site/public/` | Favicons, manifest or logo: stop and report (an A or B defect; a fix needs an override or B's file). `og:image` or `twitter:image`: use the absolute URL (Decision 6) |
| A4 | Hextra v0.13.0's `favicons.html`, `favicon.js` and `static/` match the set read at 275e2ad | Read the vendored files | Follow v0.13.0's set; record it here |
| A5 | The QA image runs a Playwright script with `--network none --user <uid>:<gid>`, the worktree root as its only mount, and writes into the gitignored `site/.shots/brand/` | Render the contact sheet this way | Mirror A's `qa` flags; if it still fails, stop and report |

## Research & Decisions

### How Hextra chooses the favicon files
**Context**: The favicons must become OPM's without adding to the override set.
**Explored**: The prototype's vendored Hextra (275e2ad): `layouts/_partials/favicons.html`, `layouts/_partials/head.html`, `assets/js/core/favicon.js`, `static/`; plan-final section 5 ("Favicon file set").
**Decision**: Same-named files in `site/static/`, a tiled `favicon.svg`, no `favicon-dark.svg` (Decisions 1 and 2).
**Rationale**: The partial links fixed names through `relURL`. Project static wins over theme static, so the replacement needs no template, and the dark swap is opt-in by file.

### Where `og:image` comes from
**Context**: The card must reach every page of every version.
**Explored**: Hextra's `layouts/_partials/opengraph.html` (page `images`, else `site.Params.images` index 0, then `relURL` and `absURL`); Hextra's `head.html`, which calls `twitter_cards.html` with no theme copy, so Hugo's embedded template (`absURL` of the path as written) renders `twitter:image`; the prototype's `hugo.toml` (`images = ['/images/og-default.png']`); orchestration.md trap 9 (static files publish once at the root).
**Decision**: `params.images` names one root file. Section 1 checks both rendered URLs, and the absolute URL is the fallback for both (Decision 6).
**Rationale**: No page sets `images` (source pages carry no images under 0018:D14), so the site parameter is the only path. Whether `relURL` or `absURL` adds the version prefix is unverified, and the two templates differ, hence A3.

### The prototype's placeholders
**Context**: The plan calls the prototype's marks placeholders, and O8 asks for drawn marks.
**Explored**: `site/static/{favicon.svg,images/opm-mark*.svg,images/og-default.png}` and `tools/og-card.{py,html}` in the prototype.
**Decision**: Redraw rather than refine. Keep the file names and the `og-card` layout idea; drop the gradients, the opacity layers and the `/proto` paths.
**Rationale**: Opacity layers vanish at 16 px and break the one-ink rule. The gradients belong to the dropped default skin. The file names are already the keys in `hugo.toml`.

## Surface (orchestration.md section 6)

- **Adds.** `site/assets/css/opm/brand.css` (M's file in the CSS table); the tasks `brand:favicons` and `brand:og`; `site/tools/`; the static brand files listed in Context.
- **Relies on.**
  - `_partials/navbar-title.html` (owned by B) honouring `params.navbar.{displayLogo,displayTitle}` and `params.navbar.logo.{path,dark,width,height}`, and its class hooks (A1). B MUST keep the hooks that `brand.css` names.
  - The head hook concatenating `site/assets/css/opm/*.css`.
  - `task check`, `task ci`, `task qa` and `task shots`; the QA image `opmodel-dev-qa:<12 hex>`.
  - `OPM_SRC_WORKTREE=site-src`; `SITE_PORT=1317` only if serving; the container path `/work/repo`.
  - The outputs `site/public/` and `site/.shots/`; checks 7 (stray files), 10 (planning comments) and 11 (supply chain).
- **Changes.** Nothing.

## Risks / Trade-offs

- [The owner rejects the mark] -> The report carries up to three candidates on a contact sheet. A redraw edits three SVGs, reruns their checks and the two tasks, and updates Decision 3. It lands as one more commit on the branch (`fix(site): redraw the opm mark`), and verify runs again before the next report; the squash merge folds the commit in.
- [B, D and E edit the same files] -> `[params]` in `hugo.toml` (D may add params; M adds the navbar logo keys and `params.images`), `Taskfile.yml` (B's `versions:*`, E's `ci:*`, M's `brand:*`) and AGENTS.md's command list (B and E add tasks there too). The hunks are small and separate; when told, the worker merges `origin/main` (orchestration.md section 7, step 7). `brand:favicons`, `params.images` and the AGENTS.md lines go beyond the migration plan's overlap table for M and are flagged for the supervisor to accept.
- [B renames the navbar hooks] -> `brand.css` stops applying and the title falls back to Hextra's extrabold: degraded, not broken. This design and the README name the hooks. The supervisor tells B's worker.
- [A Hextra re-pin adds or renames a favicon file] -> The drift guard pins only upstream files behind an override copy. This change copies none, so a changed favicon set is not caught, and a new theme file would publish beside ours. The README lists the set against `favicons.html`; whoever re-pins checks it. Pinning `favicons.html` in `site/overrides.sha256` would catch it; that is outside this change's Touches (Open Questions).
- [No build check reads `<link rel="icon">`, the logo `src`, `og:image` or `twitter:image`] -> A regression would be silent. This change checks them in sections 1 and 2; a permanent check is an Open Question.
- [A tool run without `--user` leaves root-owned files in the worktree] -> Mirror A's `qa` flags. After each run, `ls -l` shows the files owned by the host user.
- [A bind mount of a missing host path creates a root-owned directory (trap 22)] -> Mount only the worktree root, which exists. Throwaway renders (the contact sheet, the review sheet and their scripts) go to the gitignored `site/.shots/brand/`, and each sheet is copied to the worker's scratch directory at once, because a later `task qa` may rewrite `site/.shots/`.
- [Chromium rasters differ between runs] -> Outputs are committed and never regenerated in CI. No gate compares bytes.
- [The OG card's text drifts from the site] -> It is read from `hugo.toml` at generation. The README says to rerun `task brand:og` when `title` or `params.description` changes.
- [`og:image` on the preview host names `opmodel.dev`] -> `absURL` follows `baseURL`. The preview host sends `noindex` until go-live, so this is accepted.
- [The logo `alt` text is upstream's "Logo" / "Dark Logo" beside a visible title] -> This is redundant for screen readers but not an axe failure. The file is B's, so it is a follow-up, not a change here.

## Durable decisions

All of these land in a `## Brand marks` heading in `README.md` (section 2):
- The drawn sources are `site/static/images/opm-mark.svg`, `opm-mark-dark.svg` and `site/static/favicon.svg`. Every PNG, the ICO and `og-default.png` are generated by `task brand:favicons` and `task brand:og` and never hand-edited.
- The mark brief: original, one ink at full opacity, a 24-unit grid with no feature under 2.5 units, and the SVG hygiene list.
- Theme favicons are replaced by same-named files in `site/static/`, never by overriding `favicons.html`, and there is deliberately no `favicon-dark.svg`.
- The wordmark is live text styled in `site/assets/css/opm/brand.css`, keyed on the navbar hooks it names.
- Rerun `task brand:og` when `title` or `params.description` changes.

`AGENTS.md` gains two things (section 2), because agents learn tasks and the "regenerate, never hand-edit" rule there:
- `task brand:favicons` and `task brand:og` under Build And Dev Commands, each naming the files it regenerates and saying they are never hand-edited;
- `site/tools/` in the Repository Layout tree, if that tree lists `site/` subdirectories (AGENTS.md asks for the tree to be updated when a directory is added).

`CONSTITUTION.md` gains nothing: no rule here binds page authors or the pipeline.

## Open Questions

- A permanent check that every head asset URL (`rel="icon"`, `rel="apple-touch-icon"`, `rel="manifest"`, the navbar logo `src`, `og:image`, `twitter:image`) resolves to a file in `site/public/` belongs in `site/scripts/check-pages.sh`, which A owns and B edits. It is proposed as a follow-up for the supervisor and does not change this change's approach.
- Whether `site/overrides.sha256` should also pin the vendored `favicons.html` and `static/site.webmanifest`, so that a re-pin that changes the favicon set fails the drift guard. That file is append-only and outside this change's Touches, so this is a follow-up too.
