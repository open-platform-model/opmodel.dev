## Why

core, cli, library and opm-operator generate their reference pages with four private generators and commit the output, and the site reads it, with each repository's authored `docs/site/`, from git at refs `resolve-versions.sh` derives from the cli line. docs-kit phase 2 moves all four to signed docs bundles that carry the generated reference and the authored pages together (one cutover per product repository, `docs-kit DESIGN decision 20`; a site version shows the docs of what its cli pins, `docs-kit DESIGN decision 10`). This change is the site's half: pull those docs bundles per site version (docs-kit contract C16), mount them into that version's `/docs/`, and switch `v1.0` to them once the cli publishes a bundle whose pins all resolve.

## Gates

Named as in docs-kit's `docs/orchestration.md` (PR #13, `plan/phases-1b-2-3`). Releases are docs-kit release-please releases merged by the owner.

- **Section 1 (support): G2-site**, `pull-docs-placement` and `add-authored-docs` released (`pages[].edit`); the pin is the first release carrying both, and never older than any producer's `.opm-docs-version` (docs-kit C12; design.md Decision 8). Fixture bundle trees for `_versions/v1.0/{cli,core,library,opm-operator}` written to C3/C15/C16 and pulled by the pinned tool. (Planned as two sections, an ungated fixture-only one and a G2-site one; G2-site held before work started, so they are one. tasks.md records the replan.)
- **Section 2: G2-pins.** A cli release with a bundle exists whose `manifest.json` `pins` all resolve: `opm-docs pull` with a scratch config holding section 2's `versions."v1.0"` succeeds anonymously. Owner decision: the pins are met by release-mode backfill dispatches of core `v2.0.0-beta.1`, library `v1.0.0-beta.1` and opm-operator `v1.0.0-beta.4` (exactly what cli `main` pins), then cli `1.0.0-beta.6` with the docs hook, with no cascade bump of those pins in between. Merging section 2 is **G2-switch** (docs-kit's gates table defines it as this change's v1.0 switch merged), which core, cli and opm-operator wait for before deleting their generators.

## What Changes

- `site/bundles.cue` gains `docs` (section 1) and `versions."v1.0"` (section 2), C16.
- Side by side, per site version: a repository is read from its docs bundle exactly when the version's lock `docs` entries name its project; otherwise from git as today. `gen-mounts.sh` mounts `site/.bundles/_versions/<v>/<project>/content` at that version's `content/docs` and drops that repository's `docs/site` git mount for that version; the source lint skips it (the pull already linted the bundle).
- Page data from manifests: "Last updated" from `pages[].lastmod`; "Edit this page" to `https://github.com/<source.repo>/edit/main/<edit>` when `edit` is set, none otherwise; "View source" at `source.commit`. The build stamp records the lock's `docs` entries.
- The site's page-set and A1 checks cover bundle pages against site-owned pages and git-sourced pages; the post-build link check covers `/docs/` links across bundles (C15 leaves them to the site).
- `OPM_BUNDLES_LOCAL` accepts `<project>@v<M>.<m>=<dir>` (C16 D6), so `opm-docs serve --site` and local previews work.
- Section 2: `v1.0` reads cli, core, library and opm-operator from bundles; the two Reference placeholders and their exemption go; `resolve-versions.sh` stops resolving those four repositories for `v1.0`.

## Before / After

**Before**

```text
site/bundles.cue      registry, signer, tabs: {"catalog-opm": {...}}
site/versions.conf    [version "v1.0"] cli-line = v1.0, catalog-line = opm-v4
v1.0 /docs/ sources   git: opm (main), core, catalog_opm, cli, library, opm-operator (release lines and pins)
site/.bundles/        lock.json  catalog-opm/{4.5,edge}/
content/docs/reference/{cli,definitions}/_index.md   placeholder: true
Edit this page        git: main or the release branch the docs came from
```

**After (section 1; v1.0 unchanged)**

```text
site/bundles.cue      + docs: {cli: {repo: "open-platform-model/cli"}, core: {...}, library: {...}, "opm-operator": {...}}
site/scripts/         + gen-docs-bundles.sh  (lock docs entries + manifests -> data/opm/docs-bundles.json)
site/tests/fixtures/bundles/_versions/v1.0/{cli,core,library,opm-operator}/   (cli carries pins)
site/versions.conf    a version may carry from-bundles = <repo> ... (none does yet)
```

**After (section 2)**

```text
site/bundles.cue      + versions: "v1.0": {anchor: {project: "cli", tag: "1.0"}, pinned: ["library", "core", "opm-operator"]}
site/versions.conf    [version "v1.0"] catalog-line = opm-v4, from-bundles = cli core library opm-operator   (cli-line removed)
v1.0 /docs/ sources   bundles: cli 1.0 (anchor), library/core/opm-operator at cli's pins
                      git: opm (main), catalog_opm (catalog-line)
site/.bundles/        + _versions/v1.0/{cli,core,library,opm-operator}/{manifest.json,content/,data/}
lock.json             + docs: [{site: "v1.0", project: "cli", role: "anchor", tag: "1.0", ..., pins: {...}}, ...]
content/docs/reference/{cli,definitions}/_index.md   deleted
Edit this page        bundle pages: main at the manifest's edit path; generated pages: none
```

## Impact

- **Files.** `site/bundles.cue`, `site/versions.conf`, `site/scripts/{gen-docs-bundles (new),gen-mounts,gen-lastmod,gen-stamp,check-pages,build-all,serve,sections,run-in-image,resolve-versions,materialise,test-site}.sh`, `site/layouts/_partials/opm/{source,build-stamp}.html`, `site/layouts/_partials/components/last-updated.html`, `site/layouts/sitemap.xml`, `site/content/docs/reference/{cli,definitions}/_index.md` (deleted in section 2), `site/tests/fixtures/`, `site/tests/checks/`, `site/tests/versions/`, `.github/workflows/site.yml` (Summary step), `Taskfile.yml` (the pull task's description), `README.md`, `AGENTS.md`, `openspec/config.yaml` (Principle III's committed-reference sentence). `site/Dockerfile` moves in the separate opm-docs bump, not here.
- **Build inputs.** Gained: four docs bundles per bundle-backed site version, from `ghcr.io/open-platform-model/docs/{cli,core,library,opm-operator}`, at the digests the lock records. Lost for `v1.0` in section 2: the git archives of those four repositories. The pinned `opm-docs` moves. No theme file is newly overridden; `last-updated.html` (already an override) gains a branch.
- **Published URLs.** None removed. `/docs/reference/cli/`, `/docs/reference/definitions/` and `/docs/reference/operator-resources/` keep their URLs; `/docs/reference/go-api/` is added by the library's bundle in section 2. The version set is unchanged and 0021:OQ15 is not touched; which release a site version shows is `docs-kit DESIGN decision 9` and `10`, applied, not settled here.
- **Behaviour change.** A docs-only merge to one of the four repositories no longer reaches `v1.0` at the next site build: it reaches it through that repository's docs revision (`publish.yml` `mode: revision`, `docs-kit DESIGN decision 9`) or its next release.
- **Source repos (follow-ups, never edited from here).** core `publish-definitions-bundle`, library `publish-go-api-bundle`, opm-operator `publish-crd-bundle`, cli `publish-cli-bundle`: their adoption and backfill (G2-core, G2-library, G2-operator, G2-cli, then G2-pins) before section 2 here; their generator deletion (generators, committed pages and `exclude`) after G2-switch. library: `docs/site/embedding/embed-the-kernel.md` links `/docs/reference/go-api/`. opm and catalog_opm: none in this change.
- **Depends on.** `add-catalog-version-history` merged first if it is in flight (same scripts). docs-kit releases per the Gates.

Delivery: one PR per section (core, cli and opm-operator need v1.0 reading bundles after section 2)

## Enhancement

None implemented, so no `enhancement.yaml`. It implements the site half of docs-kit phase 2 (`docs-kit DESIGN decision 9`, `10`, `19`, `20`) against docs-kit contracts C3, C7, C8, C15 and C16.
