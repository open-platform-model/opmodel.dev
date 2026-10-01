## Context

The landing (`site/content/_index.md`, Hextra's `hextra-home` layout) puts ModuleToCluster in the hero's right column from 64rem. Every figure goes through one frame, `site/layouts/_partials/opm/figure.html`, which always prints the claim twice: as the SVG's `aria-label` and as a visible `<figcaption>`. `site/assets/css/opm/landing.css` caps the figure's drawing at 36rem high in two columns, so the first feature card starts inside a 900 px window at 1280 px wide (`site/tests/browser/shots.py`, `LANDING_FOLD`), and centres the caption.

The six figures of the page dialect are listed in `site/scripts/lint-sources.sh` (`FIGURES`, byte-identical to the workspace contract) and in `site/layouts/_partials/opm/figure-titles.html` (the Markdown outputs' titles). The home page publishes `html` and `llms` only, no Markdown output.

Files under `site/` this change touches: `content/_index.md`, `layouts/_partials/opm/figure.html`, `layouts/_shortcodes/opm/landing-overview.html` (new), `layouts/_partials/opm/figures/landing-overview.html` (new), `assets/css/opm/landing.css`. Outside `site/`: `README.md`. The build gains and loses no input, and no published URL, version or theme override changes.

## Goals / Non-Goals

**Goals:**

- The landing shows a minimal figure of the module-to-cluster story, with three transformers and a backup provider, with no visible explanation text and no word repeated down a column.
- The figure stays accurate to how OPM renders and applies, in the same visual language as the docs figures (0018:D14), legible at phone width and in both themes.
- Every other page renders byte-for-byte as before.

**Non-Goals:**

- Changing ModuleToCluster or any docs figure.
- Adding the landing figure to the page dialect: no source page needs it.
- Naming a backup engine (k8up, Velero) or drawing the ModuleInstance inventory on the landing; the docs pages carry that detail.

## Decisions

### 1. A site-owned shortcode and body, outside the dialect

```text
site/layouts/_shortcodes/opm/landing-overview.html      the frame call
site/layouts/_partials/opm/figures/landing-overview.html  the SVG body
```

```go-html-template
{{- partial "opm/figure.html" (dict "id" "lov" "title" "From module to cluster" "claim" $claim
      "caption" false "width" 372 "height" 472 "body" (partial "opm/figures/landing-overview.html" .)) -}}
```

The pair follows the figure recipe (shortcode = frame call, partial = body, `opm-fig` classes, Go template comments, marker `lov-arrow`). It is not added to `FIGURES` or `figure-titles.html`: only `site/content/_index.md` calls it, the source lint never sees site-owned pages, and the home page has no Markdown output to title it in.

**Alternative:** edit ModuleToCluster. Rejected: the docs need its full detail (both appliers, the inventory) and its caption.

### 2. `caption: false` on the frame

```go-html-template
  {{- if ne .caption false }}
  <figcaption>{{ .claim }}</figcaption>
  {{- end }}
```

A missing `caption` key is `nil`, which `ne` keeps distinct from `false`, so every existing call renders the caption exactly as before. The claim stays the SVG's `aria-label`, so a screen reader still gets the figure's point. Page-dialect figures never pass it.

**Alternative:** hide the caption in `landing.css`. Rejected: the page would still ship text no reader sees, which the search index can still pick up; leaving it out of the markup is simpler and keeps figure rules out of the landing CSS.

### 3. The drawing (v3, owner-approved 2026-10-01)

A 372 x 472 viewBox, top to bottom:

```text
[MODULE AUTHOR  Module]      [DEPLOYER  Values]
        | imported                   | set
       [DEPLOYER  Module instance          ]
        | rendered against
[PLATFORM TEAM  Platform              transformers]
[ Deployment ]   [ Service ]   [ Backup ]
      |______emitted___|____________|          (one rail, no arrowheads)
                       | applied
- - CLUSTER - - - - - - - - - - - - - - - - - -
[             Kubernetes objects              ]
                                   | watched by
CLUSTER                     [ Backup provider ]
```

- Each noun appears once. Kinds are named only on the transformer chips; the objects are drawn once, as one neutral bar inside the cluster.
- The three chip lines join one rail at y=323, square, without arrowheads, and one arrow labelled "applied" leaves the rail's centre.
- The "watched by" arrow drops at x=304, straight on from the Backup chip's line, so the watch reads as belonging to the backup's object, not the whole set.
- Outer shapes span x=1 to 371 from y=1, so the drawing's edges meet the page grid. 372 units (not the recipe's 360) keep the 10 px labels at about 9.2 px on a 342 px phone column, above the 9 px floor `task shots` enforces.
- Role colours: author blue, deployer green, platform team orange, objects neutral, the backup provider a `tool` box (the class three-ways-to-deploy uses for the opm CLI and the operator). No new CSS class or token.

### 4. Landing CSS: the drawing fills its column

Without a caption, the 372 x 472 drawing at the 26rem (416 px) column width is about 528 px high, and the first feature card starts near y=680 at 1280 x 900. The 36rem height cap and the centred-caption rule are removed; the comment states the new measurement and that `shots.py` checks the fold.

## Research & Decisions

### Is one rail and one "applied" arrow accurate?

**Context**: v2 drew three "emits" arrows into three object boxes, then three "applied" arrows into three cluster boxes, repeating each kind three times down a column. The owner rejected the repetition.
**Explored**: How a render produces objects (`opm/docs/site/start/what-is-opm.md`: "OPM renders an instance in one CUE evaluation"; every matching transformer runs, each emitting its own objects) and how they are applied ("The CLI or the operator applies the result": `opm instance apply` applies the whole render with server-side apply and records it in the ModuleInstance's `status.inventory`; the operator does the same per reconcile). Scratch notes: the v3 research files (`research-model.md`, `research-figures.md`).
**Decision**: The three transformer outputs join one rail labelled "emitted", and a single "applied" arrow carries the set into the cluster's "Kubernetes objects" bar.
**Rationale**: A render is one evaluation that produces one object set, and that set is applied once, by one applier, as one inventory. Three parallel pipelines would suggest three independent applies. The rail draws the real topology: many transformers, one set, one apply. A rail without arrowheads reads as a bus, not three flows.

### Why only the Backup provider is drawn in the cluster

**Context**: The owner asked for "Backup provider" in the cluster box; drawing a consumer for every object would bring back the repetition.
**Explored**: `catalog_opm/opm/traits/v1alpha1/backup.cue` declares the backup trait with `fulfilment: "provider"` and ships no transformer for it; a platform supplies the transformer through a provider catalog, and a render on a platform with no provider refuses, naming the contract. The provider's object (an engine's schedule, for example) is consumed by a backup engine running in the cluster. The Deployment and the Service are acted on by Kubernetes' own controllers.
**Decision**: Draw one in-cluster actor, "Backup provider", watching the objects at the Backup chip's column. Name no engine, and do not mark backup as future or optional.
**Rationale**: The provider is the one in-cluster component the platform team installs for this figure's story; Kubernetes' built-in controllers are not OPM's to draw. The name follows the owner's wording; in core's terms the provider is the catalog behind the Backup chip, and the box is the engine that catalog targets.

## Risks / Trade-offs

- [The landing figure has no visible caption, so a sighted reader gets no one-line statement of its point (a departure from 0018:D14's caption clause)] -> The owner asked for no explanation text; the claim stays the accessible label, and the hero links to Start here, whose ModuleToCluster keeps its caption.
- [`caption: false` could spread to docs figures] -> The frame's comment and README say page-dialect figures never pass it.
- [The "Kubernetes objects" bar hides which kinds land] -> The chips name the kinds one row up; the docs figures show them per object.
- [A future hero change could push the feature cards below the fold] -> `shots.py` `LANDING_FOLD` fails the QA run when they start below 900 px at 1280 or 1440 wide, and the 9 px text floor covers the phone.

## Durable decisions

- **The landing's figure is site-owned and outside the page dialect.** `opm/landing-overview` is called only by `site/content/_index.md`, is 372 wide (not 360) and passes `caption: false`, so it shows no visible caption; its claim stays the accessible label. Page-dialect figures always show their caption and never pass `caption`. Lands in `README.md`, `## Contributing`, "Adding a figure".
- **The drawing's geometry and the CSS measurement** (outer edges on the page grid, the rail, the watch column, the 528 px height). Stays with the change and in the comments of `site/layouts/_partials/opm/figures/landing-overview.html` and `site/assets/css/opm/landing.css`.
