> **Gate.** Every section is authored now and merges in one PR after G-CLIREL (a cli release pinning `opm-controller`, and `docs/opm-controller` public) and after the next opm release in the 1.0 line (v1.0.0-beta.3 or later) whose links name the new controller URLs. Until then `task bundles:pull` cannot resolve the new project, so the checks that need the real pull run at the cutover, listed under **Cutover** below, not as checkboxes: the change is archived in this branch before the PR exists.
>
> **Cutover** (after G-CLIREL, on the rebased branch, before merge):
> 1. Delete `site/bundles.frozen.json` if main carries it, as its own commit `chore(site): drop the frozen bundle lock`.
> 2. `task bundles:pull build`: v1.0 reads `opm-controller` at the version the cli pins; the footer says `controller`.
> 3. `task shots` and `task qa`: read the PNGs of `three-ways-to-deploy`, `where-things-live` and `module-to-cluster` (light, dark, phone width) and confirm `reference/controller/` and `reference/controller/moduleinstance/` were shot (`shots.py` skips a missing page silently).

## 1. Read the renamed docs project

- [x] 1.1 `site/bundles.cue`: key, `repo` and `pinned` to `opm-controller`; comment. `.github/workflows/site.yml`: comments, the edge job's required-project list and its error text. `site/scripts/gen-docs-bundles.sh`: `tree_of` and its error text. `site/layouts/_partials/opm/build-stamp.html`: tree order and the label `controller`. `Taskfile.yml` comment.
- [x] 1.2 Tests: `site/tests/checks/{edge-config,edge-config-two-versions}/{bundles,expect}.cue`, `site/tests/fixtures/bundles.cue`, both cli fixture manifests' `pins` key, `docs-bundle-cross-link-miss/{setup.sh,expect}`, `test-site.sh` literals and header plus a stamp assertion that the footer labels the `opm-controller` bundle `controller`, `site/tests/browser/shots.py` (`reference/controller/`, `reference/controller/moduleinstance/`).
- [x] 1.3 `git mv` both fixture trees to `opm-controller/` and their pages to `the-fixture-controller.md` and `controller-resources.md`; manifests and page prose follow; regenerate `site/tests/fixtures/bundles/lock.json` with the all-local pull.
- [x] 1.4 `task check` and `task test:site` green (Docker, no network; 181 passed; its `versions:test` step needs a real pull and runs at the cutover), then commit `refactor(site)!: read the controller's docs bundle as opm-controller`

## 2. Name the controller in figures and site pages

- [x] 2.1 Figures: `three-ways-to-deploy` (labels, `owner: controller`, two-line tool label at 360 wide per design.md Decision 3), `where-things-live` (two-line label), `module-to-cluster` (label), comments in `landing-overview` and `one-trait-any-provider`; the three claim strings in `site/layouts/_shortcodes/opm/`.
- [x] 2.2 `site/content/docs/operating/_index.md` and `site/content/docs/reference/_index.md` descriptions.
- [x] 2.3 `task check` and `task test:site` green, then commit `docs(site): name the controller in figures and section overviews` (the screenshots are Cutover step 3)

## 3. Name the controller in the repository docs

- [x] 3.1 `README.md`, `AGENTS.md`, `CONSTITUTION.md`, `TODO.md`, `openspec/config.yaml`, `openspec/changes/deploy-site/orchestration.md`: the repository `opm-controller` and the product noun; personas stay.
- [x] 3.2 `task check` green, then commit `docs: name the controller in the repository docs`

## 4. Close out

- [x] 4.1 Residue check: `git grep -niE 'opm[-_ ]?operator|reference/operator|install-the-operator|operator-conditions'` outside `openspec/changes/archive/` finds nothing; every other `operator` is a persona, CUE or vendored.
- [x] 4.2 Verify the change against these artifacts, archive with `openspec archive follow-controller-rename --yes --skip-specs`, run `task openspec:check`, and commit `chore(openspec): archive follow-controller-rename`
