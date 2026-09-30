## Conventions

`WS` is `/var/home/emil/dev/open-platform-model`. `<wt>` is `WS/opmodel.dev/.claude/worktrees/port-remaining-figures`, on branch `feat/port-remaining-figures` (orchestration.md section 7, step 2). `<scratch>` is your scratch directory. `<cd>` is `openspec/changes/port-remaining-figures`, this change's directory inside `<wt>`.

Every build-bearing command carries `OPM_SRC_WORKTREE=site-src`, so the build reads the supervisor's source worktrees (orchestration.md section 5). "The gates" means these two commands, both green:
- `OPM_SRC_WORKTREE=site-src task -d <wt> ci` (it runs `task check`, `image`, `build` and `test:site`);
- `OPM_SRC_WORKTREE=site-src task -d <wt> qa`.

Read the PNGs named in the section.

"Fidelity" means the scratch comparison from design.md. Extract a figure's drawn elements (`rect`, `line`, `text`, `tspan`: tag, attributes, text) from `<wt>/site/public/v1.0/...` and compare them with the oracle.
- Tolerate formatting differences only: quoting, attribute order, self-closed tags.
- Compare each element's text byte-exactly, edge whitespace included. Never normalise whitespace.
- The only tolerated text difference is design.md Decision 8's U+00A0, in the two nodes it names, on the trimmed branch.
- Keep that script in `<scratch>` and never commit it.

Screenshot numbering: `task shots` numbers only drawn figures (`figure:has(svg[role="img"])`), in page order. A stub takes no number. So `<n>` in `site/.shots/<page>/<n>-<variant>.png` shifts as stubs become figures. Each `task qa` overwrites `site/.shots`, so the baseline and each section's shots are copied to `<scratch>`.

## 1. Spike: the port method on HelmAndOpm

- [ ] 1.1 Preconditions. Check that A is merged in `<wt>`: `site/layouts/_partials/opm/figure.html`, `site/layouts/_partials/opm/figures/module-to-cluster.html`, the six `site/layouts/_shortcodes/opm/*.html` and `site/assets/css/opm/figures.css` all exist.
  - `grep -rln 'Figure pending' <wt>/site` lists the five stub shortcodes, plus any stub-only partial, i18n file or CSS file (design.md Decision 6). If it lists a file under `site/tests/` or `site/scripts/`, a test or check asserts the stub. That file is A's and outside C's Touches, so treat it as a miss.
  - The six `WS/<repo>/.claude/worktrees/site-src` directories exist.
  - `WS/opm/.claude/worktrees/site-src/docs/site/start/what-is-opm.md` contains `{{< opm/helm-and-opm >}}`.
  - `site/tests/browser/shots.py` numbers only drawn figures (`figure:has(svg[role="img"])`) in page order, as A's tasks 4.2 require. The `<n>` values below assume it.
  - On any miss, edit nothing, report it under `deviations`, and wait.
- [ ] 1.2 Baseline. On the untouched branch, the gates are green. A failure here is A's: report it and wait.
  - Copy `<wt>/site/.shots` to `<scratch>/shots-baseline`. HelmAndOpm and ComponentToObjects are stubs there, so on What OPM is, ModuleToCluster is figure `1-*`.
  - Pick design.md Decision 8's branch. `grep -o 'component.\{0,1\}<tspan' <wt>/site/public/v1.0/docs/start/index.html` shows ModuleToCluster's text as `component <tspan` (kept) or `component<tspan` (trimmed).
  - On the trimmed branch, note ModuleToCluster's lost space for `follow-ups`. Do not edit it.
- [ ] 1.3 References. Write `git -C <wt> show 2207ba1:site/src/components/diagrams/<File>` into `<scratch>/astro/` for `Figure.astro`, `figure.css`, `HelmAndOpm.astro`, `RolesAndArtifacts.astro`, `WhereThingsLive.astro`, `ComponentToObjects.astro` and `ThreeWaysToDeploy.astro`.
  - If they still exist, copy these into `<scratch>/astro/` (read-only): `WS/opmodel.dev/site/dist/v0.2/docs/start/index.html`, `WS/opmodel.dev/site/dist/v0.2/docs/start/what-is-opm/index.html`, `WS/opmodel.dev/site/.shots/v0.2_docs_start/` and `WS/opmodel.dev/site/.shots/v0.2_docs_start_what-is-opm/`.
  - Never modify the owner's checkout. If they are gone, go on without them.
- [ ] 1.4 Class coverage (assumption A1). Compare the class names the five components use, static and computed (design.md Decision 4), with the `.opm-fig` selectors in `site/assets/css/opm/figures.css`.
  - Port each missing `figure.css` rule from `2207ba1` onto `--opm-fig-*` tokens with the design.md mapping.
  - Add a token (light and `html.dark`) only if its target is missing.
  - Verify: every class has a rule.
  - Verify: every colour in a `.opm-fig` rule is a `--opm-fig-*` token, a `--role-*` variable set from one, a `color-mix` of those, `currentColor` or `none`.
  - Verify: no `.opm-fig` rule names `--sl-`, `--hx-color-`, `prefers-color-scheme` or a raw colour (`#`, `rgb(`, `hsl(`, `oklch(`). Raw values appear only in the `:root` and `html.dark` token definitions.
- [ ] 1.5 Port HelmAndOpm (design.md Decisions 1, 2 and 8):
  - Add `site/layouts/_partials/opm/figures/helm-and-opm.html` with the `2207ba1` SVG body copied verbatim. Every HTML comment becomes a Go template comment: the header comment and the four `<!-- Row ... -->`.
  - On the trimmed branch only, write line 38's space as `component&#160;<tspan class="mono">web</tspan>`, and note it for `deviations`.
  - Replace the stub in `site/layouts/_shortcodes/opm/helm-and-opm.html` with the frame call: id `hao`, title `Helm and OPM`, 360 x 586, and the claim as one raw string equal to Astro's concatenation.
- [ ] 1.6 Fidelity (A2). Run the gates' build. From `<wt>/site/public/v1.0/docs/start/what-is-opm/index.html`, the figure titled `Helm and OPM` must have:
  - the same 65 drawn elements as the `2207ba1` body, and as the Astro page if it was copied, text compared byte-exactly (Conventions);
  - a `<text>` holding `<tspan class="mono">web</tspan>` whose text content is `component web`, with U+00A0 as the space on the trimmed branch, never `componentweb`;
  - `aria-label` equal to its `figcaption`;
  - marker `hao-arrow`;
  - no `<!--` inside the figure.
- [ ] 1.7 Screenshots (A3, A4). Run `OPM_SRC_WORKTREE=site-src task -d <wt> qa`, then read the six PNGs of HelmAndOpm, figure `1-*` in the `site/.shots/` directory for the What OPM is page. Check:
  - blue author cards, green deployer cards, the orange platform card and neutral cluster objects, filled in light and dark;
  - both switch variants follow the site toggle, not the OS;
  - the phone variants are legible, and `task shots` passed the 9 px floor;
  - no label crosses its box (`stateless workload`, `Deployment transformer`, `helm upgrade`, `--install`), and no mono ligature;
  - the space in `component web` in the module author card;
  - compared with the Astro PNG (if copied), the drawing matches, bar the palette.

  Also compare ModuleToCluster with the baseline: it is `2-*` on that page now and `1-*` in `<scratch>/shots-baseline`. It must be unchanged.
- [ ] 1.8 Write the results for A1 to A4 into design.md, "Spike findings":
  - the missing rules, or "none";
  - the fidelity result;
  - Decision 8's branch, and whether the entity was used;
  - the smallest text size `task shots` reported;
  - any geometry fix, with its reason (none expected).
- [ ] 1.9 The gates green, PNGs read, then commit `feat(site): port the helm-and-opm figure`.
  - Stage `site/layouts/_partials/opm/figures/helm-and-opm.html`, `site/layouts/_shortcodes/opm/helm-and-opm.html`, `site/assets/css/opm/figures.css` if it changed, `<cd>/design.md` and `<cd>/tasks.md`.
  - Then copy `<wt>/site/.shots` to `<scratch>/shots-s1`.

## 2. The static figures: roles-and-artifacts and where-things-live

- [ ] 2.1 Port RolesAndArtifacts:
  - add `site/layouts/_partials/opm/figures/roles-and-artifacts.html`: the `2207ba1` body, verbatim, with every HTML comment as a Go template comment, as in 1.5;
  - replace the stub in `site/layouts/_shortcodes/opm/roles-and-artifacts.html` with the frame call (id `raa`, title `Three roles, three artifacts`, 360 x 420).
- [ ] 2.2 Port WhereThingsLive the same way:
  - `site/layouts/_partials/opm/figures/where-things-live.html`: its six comments, such as `<!-- The registry -->`, none starting with "Row", become Go template comments too;
  - `site/layouts/_shortcodes/opm/where-things-live.html` (id `wtl`, title `Where things live`, 360 x 492).
- [ ] 2.3 Fidelity on `<wt>/site/public/v1.0/docs/start/index.html`:
  - `Three roles, three artifacts` has 33 drawn elements and `Where things live` has 45, identical to the `2207ba1` bodies;
  - each `aria-label` equals its `figcaption`;
  - the markers are `raa-arrow` and `wtl-arrow`;
  - the page has no duplicate `id`.
- [ ] 2.4 Screenshots. On the Start here page, read the six PNGs each of figures `2-*` (RolesAndArtifacts) and `3-*` (WhereThingsLive). ComponentToObjects, between them on the page, is still a stub and takes no number. Check:
  - the neutral Catalogs card and the three role cards;
  - the `→` in each change line;
  - the dashed zones;
  - the operator arrow at the right edge (x 346), not clipped at phone width;
  - the up arrows (`module publish`, `platform pull`, `rendered against`) point the right way;
  - both switch variants follow the site toggle;
  - no label crosses its box (`~/.opm, or pulled`, `ModuleInstance`), and no ligature.

  Also check that figure `1-*` (ModuleToCluster) is unchanged against the baseline.
- [ ] 2.5 The gates green, PNGs read, then commit `feat(site): port the roles and where-things-live figures`.
  - Stage `site/layouts/_partials/opm/figures/roles-and-artifacts.html`, `site/layouts/_partials/opm/figures/where-things-live.html`, `site/layouts/_shortcodes/opm/roles-and-artifacts.html`, `site/layouts/_shortcodes/opm/where-things-live.html`, `site/assets/css/opm/figures.css` if it changed, `<cd>/tasks.md`, and `<cd>/design.md` if it changed.
  - Then copy `<wt>/site/.shots` to `<scratch>/shots-s2`.

## 3. The data-driven figures, the stub removed, and the recipe

- [ ] 3.1 Port ComponentToObjects (design.md Decisions 3 and 8):
  - `site/layouts/_partials/opm/figures/component-to-objects.html` has the static part verbatim, its two comments as Go template comments, and the four rows as a `slice` of `dict` in a `range`, with the arithmetic from design.md;
  - on the trimmed branch only, line 32's space is written `Component&#160;<tspan class="mono">web</tspan>`, noted for `deviations`;
  - replace the stub in `site/layouts/_shortcodes/opm/component-to-objects.html` with the frame call (id `cto`, title `How a component becomes objects`, 360 x 496).
- [ ] 3.2 Port ThreeWaysToDeploy the same way:
  - `site/layouts/_partials/opm/figures/three-ways-to-deploy.html` has three rows of `start`, `by` and `rec` slices, and a nested `range $j, $line := after 1 $row.start`;
  - replace the stub in `site/layouts/_shortcodes/opm/three-ways-to-deploy.html` with the frame call (id `ttd`, title `Three ways to deploy`, 360 x 232).
- [ ] 3.3 Fidelity against the design.md coordinate table, and against the Astro pages if they were copied:
  - `How a component becomes objects` draws 53 elements, on `/v1.0/docs/start/` and on `/v1.0/docs/start/what-is-opm/`;
  - its title `<text>`, the one holding `<tspan class="mono">web</tspan>`, has the text content `Component web`, with U+00A0 as the space on the trimmed branch, never `Componentweb`;
  - `Three ways to deploy` draws 37;
  - rows, widths, label positions, classes (`obj`, `none`, `nomatch`, `req miss`, `sub mono`) and the `✓` or `✗` all match the table;
  - text compared byte-exactly (Conventions);
  - no coordinate carries a decimal point;
  - each `aria-label` equals its `figcaption`.
- [ ] 3.4 Remove the stub (design.md Decision 6):
  - delete the stub's own leftovers, if A made any: a stub-only partial, a stub-only i18n key, a stub-only CSS rule;
  - verify that `grep -rn 'Figure pending' <wt>/site` prints nothing;
  - if a file under `site/tests/` or `site/scripts/` still names the stub, 1.1 missed it: edit nothing, report it under `deviations`, and wait.
- [ ] 3.5 Land the durable decision. In `<wt>/README.md`, rewrite the part "Adding a figure" of `## Contributing` with every point of design.md "Durable decisions". Write the `&#160;` point only on the trimmed branch.
  - If A put the part elsewhere, find it with `grep -rln -i -e 'Adding a figure' -e 'figure recipe' -e 'opm/figure.html' <wt> --include=*.md --exclude-dir=openspec --exclude-dir=themes`, and name the file under `deviations`.
  - Verify: the part names both body kinds, the token rule, the 10 px minimum, one figure per page, and the dialect step for a new name.
  - A repo doc shows a shortcode plainly. Only a page that Hugo renders needs the escaped form `{{</* opm/<name> */>}}` (trap 13).
- [ ] 3.6 Screenshots. Read the six PNGs each of Start here figures `3-*` (ComponentToObjects) and `5-*` (ThreeWaysToDeploy), and What OPM is figure `3-*` (ComponentToObjects). Check:
  - the red `no match` text and the red `✗` requirement;
  - the dashed `nothing` box;
  - the tool boxes and the owner lines of the three rows;
  - the space in `Component web`;
  - both switch variants follow the site toggle;
  - no label crosses its box (`workload-type: stateless ✓`, `from Git or kubectl`, `an instance package`).

  Also check that the search smoke test in `task qa` passes. Then check that every earlier figure is unchanged against `<scratch>/shots-s1` and `<scratch>/shots-s2`:
  - on Start here, ModuleToCluster (`1-*`) and RolesAndArtifacts (`2-*`) keep their numbers, and WhereThingsLive moves from `3-*` in `shots-s2` to `4-*` now;
  - on What OPM is, HelmAndOpm (`1-*`) and ModuleToCluster (`2-*`) keep theirs.
- [ ] 3.7 The gates green, PNGs read, then commit `feat(site): port the component-to-objects and three-ways-to-deploy figures`. Stage:
  - `site/layouts/_partials/opm/figures/component-to-objects.html` and `site/layouts/_partials/opm/figures/three-ways-to-deploy.html`;
  - `site/layouts/_shortcodes/opm/component-to-objects.html` and `site/layouts/_shortcodes/opm/three-ways-to-deploy.html`;
  - `site/assets/css/opm/figures.css` if it changed;
  - each deleted stub leftover by its path (`git -C <wt> add <path>` stages the deletion);
  - `README.md`;
  - `<cd>/tasks.md`, and `<cd>/design.md` if it changed.

## After section 3 (orchestration.md section 7, steps 6 to 8; not tasks)

Verify by following `<wt>/.claude/skills/openspec-verify-change/SKILL.md` for `port-remaining-figures`, running each `openspec` command as `cd <wt> && openspec ...`. Report with the section 7 block (`sections: 3/3`; take `surface` from design.md "Interface"), then stop and wait. Archive, push and open the PR only on the supervisor's go, as section 7, step 7 says.
