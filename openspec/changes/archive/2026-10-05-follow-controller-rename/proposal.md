## Why

The Kubernetes controller repository `open-platform-model/opm-operator` is renamed `open-platform-model/opm-controller` (enhancement 0032, "The operator becomes the controller"), and the product is called the controller everywhere ("operator" in the CoreOS sense means app-specific day-2 knowledge, which OPM's generic delivery engine does not carry). Its docs bundle becomes `docs/opm-controller`, signed by the renamed repository, and the cli bundle that anchors v1.0 pins it under the key `opm-controller`. Once a cli release pins that key, a site still configured for `opm-operator` fails `opm-docs pull` (missing pin, wrong signer) and holds every deploy. This change makes the site read the renamed project and name the controller in its own pages, figures and docs. There is no alias and no redirect: nobody runs OPM yet, and the rename leaves no trace.

## Gates

- **Merges after the cli release that pins `opm-controller`**: that cli release, whose docs bundle pins `opm-controller`, is live, and `ghcr.io/open-platform-model/docs/opm-controller` is public, signed by `open-platform-model/opm-controller`. Before that the pull fails on this branch (no such package); after it, main fails without this branch.
- **And after the next opm release in the 1.0 line (v1.0.0-beta.3 or later) with the new links**: v1.0 reads opm at its newest 1.0 tag, so this change builds only once that release re-points the three controller URLs. That release can only follow the frozen lock below, since before this change the new URLs do not exist on the live site.
- **Before it**: `site/bundles.frozen.json` is committed on main (a copy of the last good build's lock) before that cli release, so the site keeps deploying while this change waits. A cutover commit on this branch (`chore(site): drop the frozen bundle lock`) deletes it.

## What Changes

- **BREAKING (site config):** the v1.0 docs project `opm-operator` becomes `opm-controller` in `site/bundles.cue` (the `docs` key, its signer `repo` and the `pinned` list), in the edge build's required-project gate (`.github/workflows/site.yml`), in `gen-docs-bundles.sh`'s project-to-repository table, and in the footer's build stamp (`build-stamp.html`: tree order and the display label `controller`).
- Tests follow: the derived-config cases, the fixture `bundles.cue`, the fixture lock, the cli fixtures' `pins` key, the cross-link case, `test-site.sh`'s literal asserts, and the screenshot list in `shots.py`. The fixture bundle trees `opm-operator/` move to `opm-controller/` with their pages `the-fixture-controller.md` and `controller-resources.md`.
- Figures and their claim strings say "OPM controller", and `three-ways-to-deploy` records `owner: controller`, the API value after the rename. `three-ways-to-deploy` and `where-things-live` set "OPM" and "controller" on two lines to fit the longer label at their 360 width.
- Site-owned pages (`operating/_index.md`, `reference/_index.md`), `README.md`, `AGENTS.md`, `CONSTITUTION.md`, `TODO.md`, `openspec/config.yaml`, `Taskfile.yml` comments and the dated `openspec/changes/deploy-site/orchestration.md` name the controller. The persona "Platform Operator" and the CUE "operator" in `base.css` stay.
- The committed `site/bundles.frozen.json`, if present, is deleted.

## Before / After

**Before**

```cue
docs: "opm-operator": {repo: "open-platform-model/opm-operator"}
versions: "v1.0": pinned: ["library", "core", "opm-operator"]
```

```text
site/tests/fixtures/bundles/_versions/v1.0/opm-operator/   manifest.json, content/{operating/the-fixture-operator.md, reference/operator-resources.md}
site/tests/fixtures/edge/opm-operator/                     the same three files
build stamp footer                                         "... operator 1.0.0-beta.N ..."
site/bundles.frozen.json                                   present (committed before the cli release)
```

**After**

```cue
docs: "opm-controller": {repo: "open-platform-model/opm-controller"}
versions: "v1.0": pinned: ["library", "core", "opm-controller"]
```

```text
site/tests/fixtures/bundles/_versions/v1.0/opm-controller/ manifest.json, content/{operating/the-fixture-controller.md, reference/controller-resources.md}
site/tests/fixtures/edge/opm-controller/                   the same three files
build stamp footer                                         "... controller 1.0.0-beta.N ..." (the root release the cli pins)
site/bundles.frozen.json                                   none
```

## Impact

- **Files.** `site/bundles.cue`, `.github/workflows/site.yml`, `site/scripts/{gen-docs-bundles,test-site}.sh`, `site/layouts/_partials/opm/build-stamp.html`, `site/layouts/_partials/opm/figures/{three-ways-to-deploy,where-things-live,module-to-cluster,landing-overview,one-trait-any-provider}.html`, `site/layouts/_shortcodes/opm/{three-ways-to-deploy,module-to-cluster,where-things-live}.html`, `site/content/docs/{operating,reference}/_index.md`, `site/tests/browser/shots.py`, `site/tests/checks/{edge-config,edge-config-two-versions,docs-bundle-cross-link-miss}/`, `site/tests/fixtures/{bundles.cue,bundles/lock.json,bundles/_versions/v1.0/cli/manifest.json,edge/cli/manifest.json}`, the moved fixture trees, `Taskfile.yml`, `README.md`, `AGENTS.md`, `CONSTITUTION.md`, `TODO.md`, `openspec/config.yaml`, `openspec/changes/deploy-site/orchestration.md`. `site/config/production/module.toml` is generated by `gen-mounts.sh` and is not edited.
- **Build inputs.** One docs project is renamed (`docs/opm-controller`, signer `open-platform-model/opm-controller`); no input is gained or lost. No theme override changes.
- **Published URLs.** The controller's pages move with its bundle's content tree, in the source repository: `/docs/reference/operator/` to `/docs/reference/controller/`, `/docs/start/install-the-operator/` to `/docs/start/install-the-controller/`, `/docs/diagnostics/operator-conditions/` to `/docs/diagnostics/controller-conditions/`, and the cli's `/docs/reference/cli/opm-operator/` to `/docs/reference/cli/opm-controller/`. No redirects. The version set is unchanged; enhancement 0021 (documentation versioning) is not touched.
- **Source repositories (follow-ups there, never edits here).** opm-controller: rename its docs project, `docs/site/` paths and pages (its rename change). cli: pin `opm-controller` in its docs bundle and rename its `opm controller` command pages. opm (`start/_index.md`, `what-opm-does-not-do.md`) and cli (`start/install-the-cli.md`, in the release the site pins): re-point every link to the three moved controller URLs and release before this change builds, or the site's link check fails the v1.0 build.
- **Depends on:** the cli release that pins `opm-controller` and the public `docs/opm-controller` package.

## Enhancement

None.
