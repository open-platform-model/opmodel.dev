## Context

Every figure is a shortcode (frame call with `id`, `title`, `claim`, `width`, `height`) and a body partial of SVG elements drawn with the `opm-fig` classes in `site/assets/css/opm/figures.css`. Dialect figures are listed in `site/scripts/lint-sources.sh` (`FIGURES`) and `site/layouts/_partials/opm/figure-titles.html`; the landing's `opm/landing-overview` is site-owned and outside the dialect. `task shots` fails a figure whose text renders under 9 px at phone width.

Files under `site/` this change touches: `layouts/_shortcodes/opm/{landing-overview,module-to-cluster,helm-and-opm,one-trait-any-provider}.html`, `layouts/_partials/opm/figures/` (the same four names), `scripts/lint-sources.sh`, `layouts/_partials/opm/figure-titles.html`. Outside `site/`: `README.md`.

## Goals / Non-Goals

**Goals:**

- The landing's cluster row shows a watcher for every object it draws.
- "From module to running objects" reads as the landing's drawing with explanations.
- What OPM is shows the role mapping with Helm and, in a second figure, why well-known traits matter.
- Every claim is accurate to shipped behaviour and states exactly what is drawn.

**Non-Goals:**

- New CSS classes or tokens; every shape uses an existing class.
- Editing `what-is-opm.md` (owned by `opm`) or the workspace `STYLE.md` from here.
- Naming a published backup provider: none exists.

## Decisions

### 1. Built-in controllers and Backup controller on one row

```text
[             Kubernetes objects              ]
        | watched by                 | watched by
[ Built-in controllers ]       [ Backup controller ]
     x=13..223, arrow x=127          x=231..359, arrow x=304
```

The arrows keep their chip columns (over the Deployment and Service gap, and under Backup), so each watcher sits under the objects it acts on. The row is balanced, not mirrored: two equal 110-wide boxes cannot hold "Built-in controllers". Neither is called "provider": in core the provider is the catalog behind the Backup chip, and in the operator it is the provider module's ModuleInstance.

### 2. module-to-cluster is the landing's layout at 360

Same rows, chips, rail, objects bar and watchers, rescaled to the dialect's 360 grid (12 margin, chips 100 wide at 24/130/236). Kinds are named once, on the chips. The ModuleInstance record sits in the cluster's top row beside where the "applied and recorded" arrow enters, because the applier writes it, not a transformer. The module's component carries the backup trait and the platform says the Backup transformer comes from a provider catalog, which is why the render uses it.

### 3. Two figures for the Helm comparison

`helm-and-opm` keeps the mapping (chart~module, release~instance, Secret~ModuleInstance) and gains only the typed-values line. The capability story is a new dialect figure, `one-trait-any-provider`, so neither figure carries both:

```text
HELM                          OPM
web chart   backup.enabled    web module   [backup] ─┐
db chart    k8up.schedule     db module    [backup] ─┤ checked against
media chart snapshots.cron    media module [backup] ─┘
(Helm defines no backup        [OPM CATALOG TRAIT backup@v1alpha1 schedule! retention!]
 values)                                    | fulfilled by
                               [PLATFORM TEAM Platform: Backup transformer,
                                provider: k8up (example), none or two: refused]
[Schedule x3 k8up.io/v1]       [Schedule x3 k8up.io/v1]
new engine: re-release         Velero platform (example): velero.io/v1,
each chart                     same modules, no edit
```

Velero is a second platform, not a swap arrow: on the operator path the registration removal guard makes replacing a provider an outage, so the figure claims only that the modules do not change.

## Research & Decisions

### Which backup claims hold

**Context**: The new figure's point rests on how the backup trait and providers behave.
**Explored**: `catalog_opm/opm/traits/v1alpha1/backup.cue` (required `schedule` and `retention`, `fulfilment: "provider"`, `optional` false by default, applies to volumes), `core/SPEC.md` (one provider per provider-fulfilled contract), the 0015 experiment `01-provider-trait-across-catalogs` rerun with the current CLI (the same module renders a k8up Schedule on one platform and a Velero Schedule on another; a missing schedule, no provider and two providers each exit 2; a component without a volume fails even with a provider), and the operator's registration removal guard.
**Decision**: Draw volumes on every module; claim "no module edit", "none or two: refused" and "a missing schedule stops the render before any object is applied"; never claim the swap is seamless; mark k8up and Velero as examples.
**Rationale**: Each claim was reproduced or read from source; the experiment's providers are unpublished, so naming them without "example" would overstate what ships.

### Fairness to Helm

**Context**: The owner wants OPM shown as more capable than Helm without false statements about Helm.
**Explored**: Helm's optional `values.schema.json`, library and umbrella charts, release storage drivers.
**Decision**: "values schema: optional"; the claim says a library chart can share templates but each chart still opts in and is re-released for a new engine; "a Secret by default".
**Rationale**: Each phrasing survives the objection a Helm maintainer would raise.

## Risks / Trade-offs

- [The otp claim is long for a caption] -> It must describe everything drawn (0018:D14); the drawing carries the point at a glance.
- [k8up and Velero providers are examples, rendered against a stand-in contract in the experiment] -> Both are labelled "example" in the drawing and the claim.
- [The source lint accepts the new name before any page uses it] -> Harmless; the opm follow-up adds the page use.

## Durable decisions

- **The page dialect has seven figures, including `one-trait-any-provider`.** Lands in `README.md` (the feature list) and `figure-titles.html` here, and in the workspace `STYLE.md` ("Site Pages") in the workspace repo.
- **The in-cluster boxes are controllers, never "provider".** Stays in the comments of `landing-overview.html` and `module-to-cluster.html`.
