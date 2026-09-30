## Context

A (`port-site-to-hugo-hextra`) ships the figure frame and one ported figure, and leaves five stubs (see proposal.md). This change starts on A's merged `main`. Four facts shape the approach:

- **The Astro sources are gone from `main`.** A's cutover deletes `site/src/components/diagrams/`. The port reads them from git history, at commit `2207ba1` ("feat(site): add the Helm and OPM figure"), the last commit that touched that directory:
  `git -C <wt> show 2207ba1:site/src/components/diagrams/<File>`, for `Figure.astro`, `figure.css`, `HelmAndOpm.astro`, `RolesAndArtifacts.astro`, `WhereThingsLive.astro`, `ComponentToObjects.astro` and `ThreeWaysToDeploy.astro`.
- **A fixes the frame.** `site/layouts/_partials/opm/figure.html` takes a dict with `id`, `title`, `claim`, `width`, `height` and `body`. It renders `<figure class="opm-fig">`, an `<svg viewBox role="img" aria-label=claim>` with `<title>`, and the arrowhead marker `<id>-arrow`, followed by `<figcaption>claim</figcaption>`. `module-to-cluster.html` is the worked example: a shortcode that calls the frame, with the SVG body in `_partials/opm/figures/`.
- **A owns the colours.** `site/assets/css/opm/figures.css` holds the `--opm-fig-*` tokens, set on `:root` and again under `html.dark`, plus the `.opm-fig` rules. The interface assigns this file to C.
- **Every source page already calls the shortcodes.** After S1, opm's `docs/site/start/_index.md` calls `module-to-cluster`, `roles-and-artifacts`, `component-to-objects`, `where-things-live` and `three-ways-to-deploy`, in that order. `docs/site/start/what-is-opm.md` calls `helm-and-opm`, `module-to-cluster` and `component-to-objects`. Nothing outside opmodel.dev changes.

Files under `site/` this change touches:

| File | Change |
|---|---|
| `site/layouts/_shortcodes/opm/helm-and-opm.html` | stub replaced by a frame call |
| `site/layouts/_shortcodes/opm/roles-and-artifacts.html` | stub replaced by a frame call |
| `site/layouts/_shortcodes/opm/where-things-live.html` | stub replaced by a frame call |
| `site/layouts/_shortcodes/opm/component-to-objects.html` | stub replaced by a frame call |
| `site/layouts/_shortcodes/opm/three-ways-to-deploy.html` | stub replaced by a frame call |
| `site/layouts/_partials/opm/figures/{helm-and-opm,roles-and-artifacts,where-things-live,component-to-objects,three-ways-to-deploy}.html` | new SVG bodies |
| `site/assets/css/opm/figures.css` | only the rules these five use that A did not carry |
| the stub's own leftovers, if A made any: a stub-only partial, i18n key or CSS rule | deleted with their last caller (Decision 6) |

Outside `site/`, section 3 rewrites the part "Adding a figure" of `README.md` `## Contributing`, which A's design.md names as the home of the figure recipe.

The build gains no input and loses none: no mount, source repo, vendored file or pinned tool. No Hextra file is copied, so the override set and `site/overrides.sha256` stay as they are. No published URL moves, and the version set stays `v1.0`.

## Goals / Non-Goals

**Goals:**
- The five figures render on `/v1.0/docs/start/` and `/v1.0/docs/start/what-is-opm/` element for element as Astro drew them at `2207ba1`, in the Hextra palette, following the site toggle.
- Each keeps 0018:D14: a caption that is also its accessible label, the role colours, and text that stays at 9 px or more at a 390 px viewport.
- `README.md` (`## Contributing`, "Adding a figure") tells the next figure author how to add a figure.

**Non-Goals:**
- New figures, redrawn figures, or new wording in claims or labels.
- The landing's figure (D, `polish-docs-page-design`, reuses the `module-to-cluster` shortcode).
- Any change to `module-to-cluster.html` (either file) or to the frame `opm/figure.html`.
- A build check for figures (Decision 5).

## Decisions

### 1. One body partial per figure; the shortcode is the frame call

Same shape as A's `module-to-cluster`. The shortcode holds what the frame needs, and the partial holds the drawing:

```go-html-template
{{- /* Figure: Helm and OPM side by side (What OPM is, "In Kubernetes terms").
       Two columns on shared rows, so each Helm step sits beside its OPM
       counterpart. The SVG body is _partials/opm/figures/helm-and-opm.html. */ -}}
{{- $claim := `Helm and OPM both end in a Deployment and a Service, but a different role decides them. In Helm, the chart author writes templates that name every object. In OPM, the module names components, and the platform team’s transformers decide which objects each one becomes. Helm records a release in a Secret. OPM records an instance in a ModuleInstance.` -}}
{{- partial "opm/figure.html" (dict "id" "hao" "title" "Helm and OPM" "claim" $claim "width" 360 "height" 586 "body" (partial "opm/figures/helm-and-opm.html" .)) -}}
```

| Shortcode | id | title | viewBox |
|---|---|---|---|
| `helm-and-opm` | `hao` | Helm and OPM | 360 x 586 |
| `roles-and-artifacts` | `raa` | Three roles, three artifacts | 360 x 420 |
| `where-things-live` | `wtl` | Where things live | 360 x 492 |
| `component-to-objects` | `cto` | How a component becomes objects | 360 x 496 |
| `three-ways-to-deploy` | `ttd` | Three ways to deploy | 360 x 232 |

- The ids and titles are Astro's. The bodies reference `url(#<id>-arrow)`, so the id MUST NOT change.
- Each claim MUST be one raw string equal to Astro's concatenation, curly apostrophes (`’`) included.
- If A's merged `module-to-cluster.html` differs from this sketch (for example, a different dict key), the five new shortcodes follow A's file, not this one.
- Rejected: the body inline in the shortcode (one file fewer, but it breaks the pattern A set, and a frame call buried under 100 lines of SVG is hard to read). Also rejected: rows in a data file under `site/data/`. That directory holds generated build data, and Astro kept the rows beside the drawing.

### 2. Static bodies are copied verbatim

The SVG between `<Figure ...>` and `</Figure>` is copied unchanged from `2207ba1`. Two edits are allowed, and no others:
- Every HTML comment becomes a Go template comment: the component's header comment becomes the partial's header, and each `<!-- ... -->` in the body becomes `{{/* ... */}}`. That covers the `<!-- Row ... -->` comments and the ones that do not start with "Row": six in WhereThingsLive (such as `<!-- The registry -->`) and two in ComponentToObjects (`<!-- The component and what it has -->`, `<!-- The platform's transformers, one row each -->`).
  - Why: consistency, not check 10. Go's `html/template` already drops HTML comments that appear in template text. A's prototype keeps `<!-- Row ... -->` in its ModuleToCluster partial and publishes none of them. Template comments make every partial look the same, and they show the next author that the comment is for the source only.
- One space may be written `&#160;`, and only on the branch Decision 8 names. That is the one named exception to "verbatim", and the worker reports it under `deviations`.

### 3. Data-driven bodies are a `range` over a slice of dicts

The static part stays verbatim. The row data moves from Astro's frontmatter into the partial. `ComponentToObjects`:

```go-html-template
{{- /* One row per transformer: its name, its second requirement (all four
       also require the container), whether web meets it, and what the row emits. */ -}}
{{- $rows := slice
  (dict "name" "Deployment transformer" "req" "workload-type: stateless" "met" true "out" "Deployment" "kind" "obj")
  (dict "name" "Service transformer" "req" "expose" "met" true "out" "Service" "kind" "obj")
  (dict "name" "HPA transformer" "req" "scaling" "met" true "out" "nothing" "kind" "none")
  (dict "name" "StatefulSet transformer" "req" "workload-type: stateful" "met" false "out" "no match" "kind" "nomatch") -}}
{{- $charWidth := 6 }}{{/* Geist Mono at 10px, per character */}}
{{- range $i, $row := $rows }}
  {{- $y := add 228 (mul $i 64) }}
  {{- $reqWidth := add (mul (add (len $row.req) 2) $charWidth) 12 }}
  <g>
    <rect class="chip" x="24" y="{{ $y }}" width="312" height="56" rx="6"></rect>
    <text class="chip-text" x="36" y="{{ add $y 20 }}">{{ $row.name }}</text>
    {{- if ne $row.kind "nomatch" }}
    <text class="label" x="230" y="{{ add $y 22 }}" text-anchor="end">emits</text>
    {{- end }}
    <g class="{{ $row.kind }}">
      <rect x="236" y="{{ add $y 7 }}" width="88" height="22" rx="5"></rect>
      <text x="280" y="{{ add $y 22 }}" text-anchor="middle">{{ $row.out }}</text>
    </g>
    <g class="req">
      <rect x="36" y="{{ add $y 32 }}" width="80" height="16" rx="4"></rect>
      <text x="76" y="{{ add $y 44 }}" text-anchor="middle">container ✓</text>
    </g>
    <g class="{{ cond $row.met "req" "req miss" }}">
      <rect x="122" y="{{ add $y 32 }}" width="{{ $reqWidth }}" height="16" rx="4"></rect>
      <text x="{{ add 122 (div $reqWidth 2) }}" y="{{ add $y 44 }}" text-anchor="middle">{{ $row.req }} {{ cond $row.met "✓" "✗" }}</text>
    </g>
  </g>
{{- end }}
```

`ThreeWaysToDeploy` has the same shape. Each row is a dict whose `start`, `by` and `rec` values are slices of strings. Per row, `$y := add 30 (mul $i 68)` and `$mid := add $y 29`. Astro's `row.start.slice(1).map((line, j) => ...)` becomes `range $j, $line := after 1 $row.start`, at `y = add (add $y 37) (mul $j 14)`. The tool's second line takes `class="{{ cond (eq $i 0) "sub mono" "sub" }}"`.

- `len` counts bytes. Every `req` string is ASCII, so it equals Astro's `.length`. A future non-ASCII label MUST be sized by hand.
- `div` on integers truncates. Here `$reqWidth` is `6n + 24`, always even, so `div $reqWidth 2` is exact and matches the JS.
- `add` is written with two arguments at a time, nested, so the template does not depend on variadic `add`.
- Actions may span lines (Go 1.16 and later), so the multi-line `slice` is valid.

### 4. CSS: carry only what is missing, on `--opm-fig-*` tokens

A's `figures.css` is expected to hold the prototype's full figure block, which covers every rule of `figure.css` at `2207ba1`. Section 1 checks this. It lists the class names the five bodies use and compares them with the `.opm-fig` selectors in `figures.css`. The static names are `author`, `body`, `card`, `change`, `chip`, `chip-text`, `cmd`, `deployer`, `flow`, `label`, `mono`, `neutral`, `note`, `obj`, `req`, `role`, `rule`, `small`, `tag`, `team`, `title`, `tool`, `zone` and `zone-label`. The computed ones are `obj`, `none`, `nomatch`, `req miss` and `sub mono`. Any missing rule is ported from `figure.css` at `2207ba1` with this mapping, the one the prototype used:

| Starlight token (`figure.css`) | `figures.css` token |
|---|---|
| `--sl-color-text` | `--opm-fig-text` |
| `--sl-color-gray-2` | `--opm-fig-strong` |
| `--sl-color-gray-3` | `--opm-fig-muted` |
| `--sl-color-gray-4` | `--opm-fig-line-2` |
| `--sl-color-gray-5` | `--opm-fig-line` |
| `--sl-color-gray-7` | `--opm-fig-subtle` |
| `--sl-color-bg` | `--opm-fig-bg` |
| `--sl-color-{blue,green,orange}-low`, `-{blue,green,orange}`, `-{blue,green,orange}-high` | `--opm-fig-{blue,green,orange}-low`, `--opm-fig-{blue,green,orange}`, `--opm-fig-{blue,green,orange}-high` |
| `--sl-color-red`, `--sl-color-red-high` | `--opm-fig-red`, `--opm-fig-red-high` |
| `--sl-font`, `--sl-font-mono` | the sans and mono families A's `figures.css` uses (the prototype: `--hx-font-sans`, `--hx-font-mono`) |

- Every colour in a `.opm-fig` rule MUST be one of: a `--opm-fig-*` token, a `--role-*` variable set from one, a `color-mix` of those, `currentColor` or `none`. No `.opm-fig` rule may use `prefers-color-scheme`, `--sl-*`, `--hx-color-*` or a raw value (`#…`, `rgb(`, `hsl(`, `oklch(`): the tokens are set under `html.dark`, which follows the site toggle.
- Raw values and Hextra colours appear only where the tokens are defined, in the `:root` and `html.dark` blocks. The prototype's blocks hold `#fff`, `oklch(...)` and `var(--hx-color-*)`, and that is expected.
- A token is added (light and `html.dark`, with raw values in those two blocks) only when the table's target is missing.
- Existing rules that `module-to-cluster` uses are not edited.

### 5. No new build check

- Caption and label come from one `claim` value in the frame, so they cannot diverge.
- The 9 px floor is already a failing check (`task shots`, inside `task qa`).
- Fidelity to Astro is a one-time port question. After the port, the Hugo body is the source, and a golden copy of the SVG would only detect changes (Principle II asks for checks that guard behaviour).

The fidelity comparison therefore runs as a scratch script and is not committed.

### 6. Stub removal waits for the last stub

Sections 1 and 2 replace three of the five stubs. Section 3 replaces the last two and deletes whatever the stub leaves behind, if A made it: a stub-only partial, a stub-only i18n key, a stub-only CSS rule. These leftovers are part of removing the stub, so they are in C's Touches. Proof: `grep -rn 'Figure pending' <wt>/site` prints nothing.

A test or check that asserts the stub text (under `site/tests/` or `site/scripts/`) is not C's to edit. It is A's file, and `site/tests/browser/*` is shared with B and D (plan-final 1.5). A's fixture `start/_index.md` calls all six shortcodes, so such a test would fail as early as section 1. Task 1.1 therefore looks for one before any edit. If it finds one, the worker edits nothing, reports it under `deviations`, and waits (orchestration.md section 7, step 5).

### 7. Section order: HelmAndOpm first

HelmAndOpm is the largest drawing and the only one the prototype never ported. It is static, so section 1 exercises the whole method on it without any arithmetic: the class coverage check, the element-level fidelity check, the six-variant screenshot read, and the findings written into this file. Section 2 repeats the method on the two other static figures. Section 3 adds the arithmetic and closes out the stub and the recipe.

### 8. The space before a `<tspan>` must survive the build

Three text nodes end in a space followed by a `<tspan>`:
- HelmAndOpm, line 38: `<text class="body" x="198" y="90">component <tspan class="mono">web</tspan></text>`;
- ComponentToObjects, line 32: `<text class="title" x="24" y="50">Component <tspan class="mono">web</tspan></text>`;
- A's ModuleToCluster, line 21 at `2207ba1`: the same as HelmAndOpm, at `x="24" y="70"`.

When A's build minifies HTML, Hugo sends each inline `<svg>` through tdewolff's SVG minifier. HTML minification (`[minify] minifyOutput = true` in `site/config/_default/hugo.toml`; A's build command carries no `--minify`) is A's decision 10, default mechanism (b). The SVG minifier trims whitespace at both ends of every text node, so the figure reads "componentweb". A `&#160;` survives.

- **Task 1.2 picks the branch.** On A's untouched baseline build, ModuleToCluster's output in `site/public/v1.0/docs/start/index.html` reads either `component <tspan` (kept) or `component<tspan` (trimmed).
- **Kept:** HelmAndOpm and ComponentToObjects are copied verbatim.
- **Trimmed:**
  - In HelmAndOpm and ComponentToObjects only, that one space is written `&#160;`, for example `component&#160;<tspan class="mono">web</tspan>`.
  - This is the one named exception to Decision 2, and the worker reports it under `deviations`.
  - ModuleToCluster is not edited (Non-Goals). Its lost space is reported under `follow-ups`, with both remedies: the same entity in its partial, or `disableSVG = true` under `[minify]` in A's `hugo.toml`. With no SVG minifier registered, tdewolff's HTML minifier writes inline SVG through untouched. That was checked against tdewolff directly. That Hugo's `disableSVG` leaves the SVG minifier unregistered was not tested.
- **Rejected:**
  - `xml:space="preserve"`: the minifier drops it and trims anyway.
  - `dx` on the `<tspan>`: it survives, but it adds a coordinate Astro did not draw.
  - C setting `disableSVG` itself: `hugo.toml` is A's file and outside C's Touches (orchestration.md section 7, step 5).

A non-breaking space renders as a space, so the published figure looks the same as Astro's. The fidelity check compares text byte-exactly (tasks.md Conventions), so on the trimmed branch it expects U+00A0 in these two nodes and nowhere else.

### Interface (orchestration.md section 6)

- **Adds:** nothing. No task, environment variable, partial name, output or check is added or renamed.
- **Edits, within C's allowance:** `_partials/opm/figures/<name>.html` and `_shortcodes/opm/<name>.html` for the five names, and `assets/css/opm/figures.css`.
- **Relies on:**
  - the tasks `task check`, `task ci`, `task qa` and `task shots` (inside `qa`);
  - `OPM_SRC_WORKTREE=site-src`;
  - the frame `_partials/opm/figure.html` (dict `id`, `title`, `claim`, `width`, `height`, `body`; `--opm-fig-*` tokens following `html.dark`);
  - the CSS glob in `_partials/custom/head-end.html`;
  - A's comment mechanism and minify setting (`[minify] minifyOutput = true` in `site/config/_default/hugo.toml`; the build command has no `--minify` flag), which C reads and never edits (Decision 8);
  - the outputs `site/public/v1.0/...` and `site/.shots/<page>/<n>-<variant>.png`;
  - checks 10 (planning comments in output) and 11 (supply chain).
- `SITE_PORT=1315` is needed only if the worker runs `task serve` or `task preview`.

## Research & Decisions

### HelmAndOpm, analysed at planning time

**Context**: plan-final says of HelmAndOpm that "nobody has analysed it". It was added after the prototype snapshot, so A carries only its stub.
**Explored**: `git show 2207ba1` (the commit adds `HelmAndOpm.astro`, 114 lines, and changes one comment line each in `ComponentToObjects.astro` and `ModuleToCluster.astro`; it does not touch `figure.css`); the component source; the Astro-built page described in the next topic.
**Decision**: Port it as a static body. It has no data array and no computed value, and it needs no CSS that `figure.css` did not already have before it: `zone-label`, the three role cards, `role`, `title`, `body`, `mono` (on a `text` and a `tspan`), `tag`, `flow`, `label`, `cmd`, `chip`, `chip-text`, `zone`, `obj`, `note` and `body small`. It draws 65 elements (`rect`, `line`, `text`, `tspan`) on a 360 x 586 viewBox, in two 166-unit columns. Its smallest text is 10 px (`role`, `zone-label`). Its mono text is `templates/`, `web`, the tag labels, and the commands `helm upgrade`, `--install` and `opm instance apply`.
**Rationale**: For a static drawing the port is a copy. What remains unverified is the new environment (A's CSS, the build's HTML handling, Hugo's fonts), which section 1 tests (see "Spike findings"). One effect of the HTML handling is already known, the space before `<tspan>` (Decision 8).

### A rendered reference for every figure

**Context**: A deletes the Astro sources, and no one can run Astro (no npm on the host), so the port needs a fixed picture of what Astro drew.
**Explored**: The owner's main checkout holds untracked Astro output from 2026-09-29 15:12: `WS/opmodel.dev/site/dist/v0.2/docs/start/index.html` (five figures), `WS/opmodel.dev/site/dist/v0.2/docs/start/what-is-opm/index.html` (three figures), and six PNG variants per figure in `WS/opmodel.dev/site/.shots/v0.2_docs_start/` and `.../v0.2_docs_start_what-is-opm/`. The element lists were compared with the `2207ba1` sources, with `data-astro-*` attributes dropped and attributes sorted. RolesAndArtifacts is 33 of 33 identical, WhereThingsLive 45 of 45, HelmAndOpm 65 of 65. In all eight placements the `aria-label` equals the `figcaption`. Drawn-element counts in that output: ModuleToCluster 49, RolesAndArtifacts 33, ComponentToObjects 53, WhereThingsLive 45, ThreeWaysToDeploy 37, HelmAndOpm 65.
**Decision**: The oracle for a static figure is its `2207ba1` body. The oracle for a data-driven figure is the coordinate table below, which matches the Astro output. The untracked Astro output and PNGs are an extra reference only: copied read-only into scratch if they still exist, and never required.
**Rationale**: The untracked files can disappear before C starts. The git history and this table cannot.

### Coordinates the data-driven figures must reproduce

**Context**: Only these two figures compute anything, so they are where a port can go wrong without looking wrong.
**Explored**: The Astro formulas evaluated by hand and checked against the Astro output (the requirement label positions `x = 206, 152, 155, 203` appear there as integers).
**Decision**: Section 3 checks the Hugo output against this table:

| Figure | Row | y | Other values |
|---|---|---|---|
| `cto` | 0 Deployment | 228 | kind `obj`, req `workload-type: stateless`, width 168, label x 206, met |
| `cto` | 1 Service | 292 | kind `obj`, req `expose`, width 60, label x 152, met |
| `cto` | 2 HPA | 356 | kind `none`, req `scaling`, width 66, label x 155, met |
| `cto` | 3 StatefulSet | 420 | kind `nomatch`, no "emits" label, req `workload-type: stateful`, width 162, label x 203, `req miss`, `✗` |
| `ttd` | 0 Instance package | 30 | arrows at y 59 (x 132 to 142, 236 to 246); one start line at 67; tool line class `sub mono` |
| `ttd` | 1 ModuleInstance | 98 | arrows at y 127; one start line at 135; class `sub` |
| `ttd` | 2 ModulePackage | 166 | arrows at y 195; start lines at 203 and 217; class `sub` |

Totals: `cto` draws 53 elements and `ttd` draws 37.
**Rationale**: The table is exact and needs nothing from the owner's checkout.

### The 9 px text floor at 390 px

**Context**: 0018:D14 requires figures that stay readable at phone width. `task shots` fails when any SVG text renders under 9 px at a 390 px viewport.
**Explored**: The font sizes in `figure.css` at `2207ba1`. The smallest is 10 px (`.role`, `.zone-label`, `.req text`, `.obj text.note.small`), and every figure is 360 units wide.
**Decision**: No size changes are planned. Rendered size is the font size times the rendered width divided by 360. All six figures share that ratio, so ModuleToCluster, which passes the check in A, predicts the other five. `task shots` still measures every figure.
**Rationale**: This removes one assumption from the spike without skipping the measurement.

### Spike findings (section 1 fills this in)

**Context**: Four assumptions can only be checked on A's merged build:
- A1: A's `figures.css` covers every class the five bodies use.
- A2: The build's HTML handling leaves each drawn element's tag, attributes and text intact, edge whitespace included. That handling is Go's `html/template` plus whatever A chose for stripping comments (HTML minification through `[minify] minifyOutput = true`, or goldmark `unsafe = false`).
  - Already known to fail in one place under HTML minification: the space before `<tspan>` in HelmAndOpm, ComponentToObjects and A's ModuleToCluster is trimmed (Decision 8). Task 1.2 finds out which branch A's build is on. On the trimmed branch, fixing it is expected, not a surprise.
  - Checked at planning time, read-only in scratch: tdewolff/minify v2.24.8's HTML and SVG minifiers, from the local Go module cache, over the four static bodies at `2207ba1` (HelmAndOpm, RolesAndArtifacts, WhereThingsLive, ModuleToCluster). Across every `rect`, `line`, `text` and `tspan`, the only change was that trailing space, in HelmAndOpm and ModuleToCluster.
  - The version Hugo 0.167.0 bundles was not checked. Section 1 still observes the real build.
- A3: The smallest rendered text stays at 9 px or more at 390 px. This is predicted above; `task shots` measures it.
- A4: No label outgrows its box in the Hugo site's fonts.

**Explored**: Section 1 ported HelmAndOpm on A's branch head (2d70215), built it with `OPM_SRC_WORKTREE=site-src`, and ran `task ci` and `task qa`:
- A1: every class the five bodies use, static and computed (`author` ... `zone-label`, `obj`, `none`, `nomatch`, `req miss`, `sub mono`), already has a `.opm-fig` rule in A's `figures.css`. A carries every rule of `figure.css` at `2207ba1`, plus `.tool text.mono` and `.pill`. Every colour in a `.opm-fig` rule is a `--opm-fig-*` token, a `--role-*` variable, a `color-mix` of those, `currentColor` or `none`; `figures.css` has no `prefers-color-scheme`, `--sl-*` or raw colour outside the `:root` and `html.dark` blocks.
- A2: the built `Helm and OPM` figure on `/v1.0/docs/start/what-is-opm/` has the same 65 drawn elements as the `2207ba1` body and as the Astro-built page (tag, attributes and text chunks, compared byte-exactly). Its claim equals Astro's, `aria-label` equals the `figcaption`, the marker is `hao-arrow`, and no `<!--` is inside the figure. Decision 8: A's `hugo.toml` sets `disableSVG = true` under `[minify]`, and the baseline build reads `component <tspan`: the kept branch. HelmAndOpm reads `component <tspan class="mono">web</tspan>` with an ASCII space; no `&#160;` is used, and ModuleToCluster keeps its space too.
- A3: `task shots` reports 9.5 px as the smallest text at a 390 px viewport, for HelmAndOpm and ModuleToCluster alike.
- A4: in all six variants no label crosses its box (`stateless workload`, `Deployment transformer`, `helm upgrade`, `--install`). Two font effects, neither a defect: at phone width the two hyphens of `--install` touch, because Geist Mono's hyphen is wide at about 10 px (at desktop width they stand apart, so it is not a ligature), and Geist's word space makes `component web` tighter than Astro's font did, as in ModuleToCluster.
- ModuleToCluster on `/v1.0/docs/start/` is byte-identical to the baseline. On What OPM is it moved from `1-*` to `2-*` and differs only by a one-pixel vertical offset.

**Decision**: The method holds as planned. No CSS rule or token is added, no geometry changes, and no `&#160;` is written: the other four figures are copied (or computed) as design.md describes, on the kept branch.
**Rationale**: The measured build matches the oracle element for element, and the screenshots show the Astro drawing in the Hextra palette, following the site toggle.

### Deviations after section 3 (supervisor ruling, 2026-09-30)

**Context**: Section 3's verify found four things outside the planned Touches. The Markdown outputs (Copy page) named `component-to-objects` "Component to Kubernetes objects", the section 4 display name in A's `_partials/opm/figure-titles.html`, while the page draws it as "How a component becomes objects" (Decision 1). The README status list still said the figures "show a 'Figure pending' note". Two comments in A's test files still described stubs. And two labels sit tight in Geist Mono.
**Explored**: The fixture's start page calls all six shortcodes once. Its drawn `<title>`s and its `.md` output's `_Figure: ..._` lines differed only for `component-to-objects`; the other five entries already matched their shortcodes' `title`.
**Decision**: The supervisor approved these edits outside C's Touches:
- `README.md`, "Implementation Status": the unchecked figures line becomes checked ("All six figures of the page dialect ...").
- `site/layouts/_partials/opm/figure-titles.html` (A's): every entry equals the title its shortcode draws; `component-to-objects` becomes "How a component becomes objects".
- `site/scripts/test-site.sh` (A's): a `markdown/figure-titles` assertion compares the fixture start page's drawn figure titles with its `.md` output's `_Figure:` lines, in page order, and requires six. It failed on the old entry before the fix. The comment above `dialect/shortcodes` no longer describes stubs (comment only; the count still takes an alert in a figure's place as one of the six).
- `site/tests/browser/a11y.py` (A's): the `/docs/start/` comment says "five figures" (comment only).

Two notes, with no change (supervisor ruling):
- Geist Mono is wider than the Astro site's mono. `instance apply` (the `sub mono` line of the first three-ways-to-deploy row) clears its tool box's stroke by 1 px at desktop width (Astro: 5 px), and at phone width the two hyphens of `--install` touch. Neither crosses its box, and neither is a ligature.
- `.opm-fig .tool text.mono { font-size: 11px }` in `figures.css` has no effect today: `.tool text.sub`, later in the file, sets the one `sub mono` line to 10.5 px. If that line lost its `sub` class, it would render at 11 px and overflow its 92-unit box (92.4 units).
**Rationale**: A reader who copies a page as Markdown should meet the figure under the name the page shows, and the assertion keeps the two lists from drifting again. The rest keeps prose and comments true now that no stub is left.

## Risks / Trade-offs

- [The Astro sources are gone from `main` after A] → Read them with `git -C <wt> show 2207ba1:<path>`, never from the owner's main checkout, which is not kept current (orchestration.md trap 25).
- [The untracked Astro output and PNGs disappear] → The static bodies come from `2207ba1`, and the coordinate table above covers the data-driven ones.
- [A's `figures.css` lacks a rule, so a card renders unfilled or a label unstyled] → The class coverage check in section 1 (A1) runs before any figure is judged by eye.
- [The build's minifier trims the space before a `<tspan>`, so HelmAndOpm and ComponentToObjects read "componentweb"] → Decision 8. Task 1.2 checks ModuleToCluster's baseline output and picks the branch. On the trimmed branch, `&#160;` goes into those two nodes and is reported under `deviations`, and ModuleToCluster's loss goes under `follow-ups`. The fidelity check compares text byte-exactly. Tasks 1.6 and 3.3 assert the two strings, and 1.7 and 3.6 read the space in the PNGs, so a whitespace-normalising script cannot pass a broken render.
- [A label outgrows its box in the Hugo site's fonts] → Read every PNG. If one overflows, make the smallest geometry change that fixes it (widen one rect), record it in "Spike findings", and name it under `deviations`. Never shrink text below 10 px.
- [Geist Mono ligatures apply inside the SVG] → Trap 17: A turns ligatures off for `code` and `pre` only, and figure mono text is neither. `--install` and `~/.opm, or pulled` are the candidates. If a PNG shows a ligature, add `font-variant-ligatures: none` to the mono rules in `figures.css`.
- [A figure follows the OS theme instead of the site toggle] → Only `--opm-fig-*` tokens are used. The two switch variants (site dark on a light OS, site light on a dark OS) are read in every section.
- [More figure text in the search index for two pages] → Pagefind indexes `main#content > .content` (trap 11). The search smoke test in `task qa` must stay green. See Open Questions.
- [A build mounts a missing path and Docker creates a root-owned directory] → Task 1.1 checks that the six `site-src` worktrees exist before the first build (trap 22).
- [Parallel wave-2 changes] → Only C edits `figures.css` and the figure files. B, D and M write other CSS files and their own README or AGENTS headings (plan-final 1.5). The branch is updated by merging `origin/main`, never by a history rewrite (orchestration.md section 7, step 7).
- [Docker only] → The site builds, serves and is shot only through `task`. Never run `hugo`, `npm` or `node` on the host (orchestration.md section 1, "Host", and trap 18).
- [A seventh figure later] → The shortcode list is part of the source dialect (the `FIGURES` list in `site/scripts/lint-sources.sh`, and the six names in the workspace `STYLE.md` "Site Pages"). The recipe says so.

## Durable decisions

- **The figure recipe** lands in `README.md`, section `## Contributing`, part "Adding a figure". A's design.md names that place ("the recipe C updates"), and A's section 5 writes it. It says:
  - a figure is a shortcode `site/layouts/_shortcodes/opm/<name>.html` that calls `opm/figure.html` with `id` (three letters, unique among figures), `title`, `claim`, `width` 360 and `height`, and a body partial `site/layouts/_partials/opm/figures/<name>.html`;
  - a static body is SVG elements with the classes in `figures.css`, and its comments are Go template comments;
  - only if section 1 found the trimmed branch (Decision 8): a space at the end of an SVG text node, such as before a `<tspan>`, is written `&#160;`, because the build's minifier trims text-node edges inside inline SVG;
  - a data-driven body is a `range` over a `slice` of `dict`, with arithmetic in `add`, `mul` and `div`, where `len` counts bytes;
  - colours come only from `--opm-fig-*` tokens, one colour per role (blue module author, green deployer, orange platform team, neutral for published and Kubernetes things), and the tokens follow `html.dark`;
  - the grid is 360 units wide, and no text is under 10 px, so it stays at 9 px or more at 390 px (`task shots` fails below that);
  - the claim states the figure's one point, and the frame prints it as both the caption and the accessible label;
  - a page shows a figure at most once, because the arrow marker id is per figure;
  - a new figure name is a change to the source dialect: it goes into `FIGURES` in `site/scripts/lint-sources.sh` and into the six-name list in the workspace `STYLE.md`;
  - to check a figure, run `task qa` and read the six variants.
- **The Starlight-to-`--opm-fig-*` mapping and the fidelity method** stay with the change. They matter only while porting from Astro.

## Open Questions

- Pagefind indexes the SVG text of a figure (role labels such as `DEPLOYER`, object names) as page text, as it already does for ModuleToCluster in A. Marking the `<svg>` `data-pagefind-ignore` in the frame would keep the caption searchable and drop the labels. This does not change this change's approach. If the search smoke test or a reader shows noise, it belongs with the search work in D (`polish-docs-page-design`) or a follow-up, not here.
