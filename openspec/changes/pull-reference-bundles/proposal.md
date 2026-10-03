## Why

core, cli, library and opm-operator generate their reference pages with four private generators and commit the output, and the site reads it, with each repository's authored `docs/site/`, from git at refs `resolve-versions.sh` derives from the cli line. docs-kit phase 2 moves all four to signed docs bundles that carry the generated reference and the authored pages together (one cutover per product repository, `docs-kit DESIGN decision 10`: a site version shows the docs of what its cli pins). This change is the site's half: pull those docs bundles per site version (docs-kit contract C16), mount them into that version's `/docs/`, and switch `v1.0` to them once the cli publishes a bundle whose pins all resolve.

## Gates

Named as in docs-kit's `docs/orchestration.md` (PR #13, `plan/phases-1b-2-3`). Releases are docs-kit release-please releases merged by the owner.

- **Section 1: no gate.** Fixture bundle trees for `_versions/v1.0/{cli,core,library,opm-operator}` written by hand to C3/C15/C16 as docs-kit's `generalize-build-assembly`, `pull-docs-placement` and `add-authored-docs` designs show them, layered onto the fixture build by `test-site.sh` (the drift test cannot hold what the pinned tool does not write).
- **Section 2: G2-site plus `add-authored-docs` released.** docs-kit's G2-site is `pull-docs-placement` released; this change also needs `pages[].edit`, so the pin is the first release carrying both (and never older than any producer's `.opm-docs-version`, see design.md Decision 8).
- **Section 3: G2-pins.** A cli release with a bundle exists whose `manifest.json` `pins` all resolve: `opm-docs pull` with a scratch config holding section 3's `versions."v1.0"` succeeds anonymously. That needs, in order: core, library and opm-operator adopted (their `publish-*-bundle` section 1) and released with bundles (their section 2), then cli `publish-cli-bundle` sections 1 and 2. Merging section 3 is **G2-switch** (docs-kit's orchestration calls it "section 2"; this change splits its section 1 so the fixture work merges before any release), which core, cli and opm-operator wait for before deleting their generators (their section 3).

## What Changes

- `site/bundles.cue` gains `docs` (section 2) and `versions."v1.0"` (section 3), C16.
- Side by side, per site version: a repository is read from its docs bundle exactly when the version's lock `docs` entries name its project; otherwise from git as today. `gen-mounts.sh` mounts `site/.bundles/_versions/<v>/<project>/content` at that version's `content/docs` and drops that repository's `docs/site` git mount for that version; the source lint skips it (the pull already linted the bundle).
- Page data from manifests: "Last updated" from `pages[].lastmod`; "Edit this page" to `https://github.com/<source.repo>/edit/main/<edit>` when `edit` is set, none otherwise; "View source" at `source.commit`. The build stamp records the lock's `docs` entries.
- The site's page-set and A1 checks cover bundle pages against site-owned pages and git-sourced pages; the post-build link check covers `/docs/` links across bundles (C15 leaves them to the site).
- `OPM_BUNDLES_LOCAL` accepts `<project>@v<M>.<m>=<dir>` (C16 D6), so `opm-docs serve --site` and local previews work.
- Section 3: `v1.0` reads cli, core, library and opm-operator from bundles; the two Reference placeholders and their exemption go; `resolve-versions.sh` stops resolving those four repositories for `v1.0`.

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

**After (sections 1 and 2; v1.0 unchanged)**

```text
site/bundles.cue      + docs: {cli: {repo: "open-platform-model/cli"}, core: {...}, library: {...}, "opm-operator": {...}}
site/scripts/         + gen-docs-bundles.sh  (lock docs entries + manifests -> data/opm/docs-bundles.json)
site/tests/fixtures/bundles/_versions/v1.0/{cli,core,library,opm-operator}/   (cli carries pins)
site/Dockerfile       OPM_DOCS_VERSION=<release with pull-docs-placement and add-authored-docs>
```

**After (section 3)**

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

- **Files.** `site/Dockerfile`, `site/bundles.cue`, `site/versions.conf`, `site/scripts/{gen-docs-bundles (new),gen-mounts,gen-lastmod,gen-stamp,check-pages,build-all,serve,sections,run-in-image,resolve-versions,test-site}.sh`, `site/layouts/_partials/opm/source.html`, `site/layouts/_partials/components/last-updated.html`, `site/content/docs/reference/{cli,definitions}/_index.md` (deleted in section 3), `site/tests/fixtures/`, `site/tests/checks/`, `site/tests/versions/`, `.github/workflows/site.yml` (Summary step), `README.md`, `AGENTS.md`, `openspec/config.yaml` (Principle III's committed-reference sentence).
- **Build inputs.** Gained: four docs bundles per bundle-backed site version, from `ghcr.io/open-platform-model/docs/{cli,core,library,opm-operator}`, at the digests the lock records. Lost for `v1.0` in section 3: the git archives of those four repositories. The pinned `opm-docs` moves. No theme file is newly overridden; `last-updated.html` (already an override) gains a branch.
- **Published URLs.** None removed. `/docs/reference/cli/`, `/docs/reference/definitions/` and `/docs/reference/operator-resources/` keep their URLs; `/docs/reference/go-api/` is added by the library's bundle in section 3. The version set is unchanged and 0021:OQ15 is not touched; which release a site version shows is `docs-kit DESIGN decision 9` and `10`, applied, not settled here.
- **Behaviour change.** A docs-only merge to one of the four repositories no longer reaches `v1.0` at the next site build: it reaches it through that repository's docs revision (`publish.yml` `mode: revision`, `docs-kit DESIGN decision 9`) or its next release.
- **Source repos (follow-ups, never edited from here).** core `publish-definitions-bundle`, library `publish-go-api-bundle`, opm-operator `publish-crd-bundle`, cli `publish-cli-bundle`: their sections 1 and 2 before section 3 here; their section 3 (delete generators, committed pages and `exclude`) after it. library: `docs/site/embedding/embed-the-kernel.md` links `/docs/reference/go-api/`. opm and catalog_opm: none in this change.
- **Depends on.** `add-catalog-version-history` merged first if it is in flight (same scripts). docs-kit releases per the Gates.

Delivery: one PR per section (core, cli and opm-operator need v1.0 reading bundles after section 3)

## Enhancement

None implemented, so no `enhancement.yaml`. It implements the site half of docs-kit phase 2 (`docs-kit DESIGN decision 9`, `10`) against docs-kit contracts C3, C7, C8, C15 and C16.
