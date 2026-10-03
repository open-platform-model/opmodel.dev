## Context

Every figure is a shortcode (frame call with `id`, `title`, `claim`, `width`, `height`) and a body partial of SVG elements drawn with the `opm-fig` classes in `site/assets/css/opm/figures.css`. Dialect figures are listed in `site/scripts/lint-sources.sh` (`FIGURES`) and `site/layouts/_partials/opm/figure-titles.html`; the dialect contract in `openspec/changes/deploy-site/orchestration.md` embeds the same lint byte for byte. `task shots` fails a figure whose text renders under 9 px at phone width. The last figure added the same way was `one-trait-any-provider` (archived change `2026-10-01-redraw-overview-figures`).

Files under `site/` this change touches: `layouts/_shortcodes/opm/{what-opm-models,two-models-one-boundary}.html` and `layouts/_partials/opm/figures/` (the same two names, all new), `scripts/lint-sources.sh`, `scripts/test-site.sh`, `layouts/_partials/opm/figure-titles.html`, `tests/fixtures/ws/opm/docs/site/start/_index.md`. Outside `site/`: `README.md`, `openspec/changes/deploy-site/orchestration.md`. The build gains no input.

## Goals / Non-Goals

**Goals:**

- One figure that shows how far OPM models each side today: the application in full, the platform only as far as rendering needs, and what it leaves out.
- One figure whose subject is the missing edge between a module and a platform, so it reads as a different drawing from roles-and-artifacts.
- Every claim is accurate to shipped behaviour and states exactly what is drawn.

**Non-Goals:**

- New CSS classes or tokens; every shape uses an existing class.
- Writing core's concept page or the workspace `STYLE.md` from here.

## Decisions

### 1. what-opm-models: two zones, the catalogs between them

```text
[ APPLICATION MODEL                                   ]
[ [MODULE AUTHOR Module] <-imports- [DEPLOYER Module   ]
[  #config, #components            instance]          ]
        | built from
[ PUBLISHED IN A REGISTRY Catalogs ]
                                   ^ admits
[ PLATFORM, AS FAR AS RENDERING NEEDS                 ]
[ [PLATFORM TEAM Platform: catalogs it admits, their  ]
[  transformers, a contract inventory]                ]
[ NOT MODELLED: cluster settings, controllers and APIs, services offered to teams ]
```

The module and the instance sit side by side, so the "built from" arrow reaches the catalogs without crossing the instance. Every arrow points from the dependent to what it depends on (the instance imports the module, the module is built from catalog parts, the platform admits catalogs), the same direction as two-models-one-boundary on the same page; so both models point at the catalogs, which is the second figure's point. The platform's arrow runs at x=300, right of its zone label. NOT MODELLED is a dashed `none` box with a zone-label title. 360 x 580.

### 2. two-models-one-boundary: the missing edge is the subject

```text
[ PUBLISHED IN A REGISTRY  Catalog contracts  [container] [expose] [backup] ]
      ^ names contracts         :          admits catalogs ^
[MODULE AUTHOR Module]          :        [PLATFORM TEAM Platform]
[ releases 1.0 -> 1.1 ]         :        [ adds backup provider ]
      |                    NO IMPORT                |
      |                    EITHER WAY               |
[ WHERE THEY MEET  Render: an instance imports the module and is rendered against the platform ]
```

Both arrows point up, from each model to the contracts; nothing connects the two cards, and a dashed zone line runs down the 32-wide gap between them into the label NO IMPORT EITHER WAY. The two cards meet only in the neutral Render box. roles-and-artifacts draws the artifact flow downward (catalogs into module and platform, both into the instance); this one draws dependency upward and makes the gap the focus. The cards are 156 wide, so the platform's change line is "adds backup provider" (20 mono characters); "adds a backup provider" needs 139 of the 132 the card leaves. 360 x 420.

## Research & Decisions

### Which contract names to draw

**Context**: The contracts card names example contracts; they should be real.
**Explored**: `catalog_opm/src/resources/v1beta1/container.cue` (`name: "container"`), `traits/v1beta1/expose.cue` (`name: "expose"`), `traits/v1alpha1/backup.cue` (`name: "backup"`, `fulfilment: "provider"`, and the catalog ships no transformer for it).
**Decision**: Tags `container`, `expose`, `backup`, introduced by "resources and traits, such as".
**Rationale**: A module names them by these names, and backup being provider-fulfilled with no transformer in the opm catalog is why "adds backup provider" is a platform change no module release needs.

### What the platform models

**Context**: The first figure says the platform is modelled only as far as rendering needs.
**Explored**: core's `#Platform` (the catalogs it admits, one build each, their transformers) and its contract inventory (`#ContractInventory`, the `#contracts` fold), which reports and never refuses.
**Decision**: The platform card lists the admitted catalogs, their transformers and a contract inventory; the claim says the platform "reports which contracts those catalogs define and serve".
**Rationale**: Those are the parts a render reads; nothing in core models cluster settings, controllers or offered services, so they go in NOT MODELLED.

### Text widths

**Context**: Geist widths differ from estimates, and the 360 grid renders at 0.95 on a 390 px phone.
**Explored**: The fixture build, measured in the QA image with each `<text>`'s `getBBox()` at 1280 and 390 px, checked against every rect edge, line and other text.
**Decision**: The layouts above; no text crosses a box edge or an arrow, the smallest text renders at 9.5 px on a phone.
**Rationale**: Measured, not guessed.

## Risks / Trade-offs

- [The source lint accepts the new names before any page uses them] -> Harmless; core's page uses them after this merges.
- [The wom claim is long for a caption] -> It must describe everything drawn; the drawing carries the point at a glance.

## Durable decisions

- **The page dialect has nine figures, including `what-opm-models` and `two-models-one-boundary`.** Lands in `README.md` (the feature list), `figure-titles.html` and the dialect contract (`deploy-site/orchestration.md`) here, and in the workspace `STYLE.md` ("Site Pages") in the workspace repo. The fixture and `test-site.sh` guard the new titles.
- **Arrows in these two figures point from the dependent to its dependency.** Stays in the comments of both body partials.
