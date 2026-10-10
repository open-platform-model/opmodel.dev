## Why

docs-kit's reader for the OpenSpec layout of the `enhancements` repository (docs-kit PR 56, contract C21) writes `data/enhancements.json` as schema v2 beside v1. The site stops on v2 with a named error (`site/scripts/gen-mounts.sh`, the schema check), so the `enhancements` repository cannot adopt the new reader until the site accepts both. The order is fixed: a docs-kit release, then this change, then `enhancements` bumps `.opm-docs-version` in its migration's last commit. This change is the middle step. It renders today's v1 data unchanged and the v2 data fully.

## What Changes

- **Data gate.** `gen-mounts.sh` accepts `docs.opmodel.dev/data/enhancements/v1` and `.../v2`, and refuses any other schema naming both. For v2 it also checks that every entry names a known `layout`.
- **Adapter.** `site/enhancements/_content.gotmpl` reads the v2 fields: `layout`, `breaking`, `after`, `supersededBy` as a list, `accepted`, `progress`, `capabilities`, `aliases`. A v1 entry reads as before (`supersededBy` a string or null, no other new field). It marks each target page with the retired slugs the entry's `aliases` name, and tags the capability pages.
- **Status partial and header.** `opm/enh-status.html` switches on `draft`, `accepted`, `delivered`, `superseded`, `rejected` and `withdrawn`. An accepted entry with `progress` says "N of M tasks shipped". The entry header gains After, Breaking, Progress, Accepted and Capabilities rows for a v2 entry. The banner joins the `supersededBy` ids.
- **Render hooks.** `enhancements/_markup/render-heading.html` keeps the `#d3` anchors on legacy pages only. `render-table.html` classes the INDEX's new columns (Progress, Breaking, Capability, Requirements, Purpose). `render-link.html` resolves a link to a retired page slug (`/enhancements/0013/decisions/`) to the page that replaced it, so a docs page that still names an old slug keeps building.
- **Redirects.** `custom/head-end.html` publishes a stub at each retired slug and `build-all.sh` writes the `_redirects` line, as for the catalog aliases. Hugo `aliases` does not work here: it writes under the default version's directory (measured in section 1).
- **Checks.** The page-set check (`check-pages.sh`) expects the alias stubs the data lists and no other extra page; `build-all.sh` checks the stubs and the lines.
- **Fixtures and proof.** A v2 fixture bundle, built by docs-kit's `opm-docs` from a small fixture repository (`ws/enhancements-v2/`), and cases that build the site over it. The v1 fixture and its regeneration check stay as they are.
- **Not in this change.** The `opm-docs` pin in `site/Dockerfile` stays at 0.7.0. It moves in its own PR when the docs-kit release exists (docs-kit C12: the site bumps first). Until then the v2 fixture is built outside the image and committed, and the test suite builds the site over it without re-pulling it.

No published URL changes. v1 pages render byte for byte as before (section 1 measures it).

## Before / After

**Before**

```text
gen-mounts.sh:   [ "$(jq -r '.schema' "$D")" = docs.opmodel.dev/data/enhancements/v1 ] || enh_fail ...
_content.gotmpl: params enhId status category affects created updated archived dependsOn amends
                 supersedes revives supersededBy(string)
enh-status.html: draft | accepted | delivered | superseded | rejected | other
tests:           bundles/enhancements/edge/ (v1, pinned opm-docs rebuilds it byte-identical)
```

**After**

```text
gen-mounts.sh:   schema in {enhancements/v1, enhancements/v2}; v2: layout in {legacy, openspec} on every entry
_content.gotmpl: v1 params as before, plus layout breaking after accepted progress capabilities repo retired;
                 supersededBy is a list for layout openspec
enh-status.html: draft | accepted (+ progress) | delivered | superseded (list) | rejected | withdrawn | other
header (dl):     Status Category Affects Created Updated [After] [Breaking] [Progress] [Accepted]
                 [Capabilities] Depends on Amends Supersedes Revives Superseded by
render-link:     /enhancements/<NNNN>/<retired slug>/ -> the entry's replacing page (data aliases)
head-end, _redirects: a stub and a 301 line per retired slug
tests:           bundles/enhancements/edge/            v1, unchanged
                 bundles-v2/enhancements/edge/         v2: layout legacy and openspec, aliases, capabilities
                 ws/enhancements-v2/                   its source; regen-enhancements-v2.sh rebuilds it with a newer opm-docs
```

## Impact

- **Files.** `site/scripts/gen-mounts.sh`, `site/scripts/check-pages.sh`, `site/enhancements/_content.gotmpl`, `site/layouts/_partials/opm/enh-status.html`, `site/layouts/_partials/custom/head-end.html`, `site/scripts/build-all.sh`, a new partial `site/layouts/_partials/opm/enh-aliases.html`, `site/layouts/enhancements/_markup/{render-heading,render-table}.html`, `site/layouts/_markup/render-link.html` (an override copy pinned in `site/overrides.sha256`: the hash is of the upstream file and stays), `site/assets/css/opm/enhancements.css`, `site/scripts/test-site.sh`, `site/tests/bundle-page.sh`, `site/tests/browser/qa_common.py` (picks a draft entry's decisions, requirements or design page), `site/tests/checks/` (`enh-bundle-data-schema` changed; `enh-bundle-layout` and `enh-alias-target-missing` new), `site/tests/fixtures/` (`ws/enhancements-v2/`, `bundles-v2/`, `regen-enhancements-v2.sh`), `README.md`, `AGENTS.md`.
- **Build inputs.** None gained or lost: no mount, no pin, no vendored file. The v2 fixture is a committed bundle tree.
- **Published URLs.** None change. A migrated entry later gains redirect stubs at its retired slugs (`/enhancements/0013/problem/`), which the data lists. No version is touched; 0021:OQ15 is not touched.
- **Source repos.** `enhancements` (follow-up): bumps `.opm-docs-version` and its `docs.yml` refs in its migration's last commit, after this merges and after the site's `opm-docs` pin moves. Workspace `STYLE.md` "Site Pages" (follow-up, owner): the link rule lists the new slugs `proposal`, `design`, `requirements`, `tasks` and `/enhancements/capabilities/<capability>/`, and the seven old slugs only for the ten archived entries. docs-kit: none (its C21 already states the data).
- **Depends on.** The docs-kit release carrying PR 56 (for the real bundle and the pin bump, not for this change's tests). Order: the docs-kit release; then this change and the site's `opm-docs` pin bump, in either order; then `enhancements`' bump (docs-kit C12 and C21).

## Enhancement

None. It is the site half of the enhancements migration's docs-kit step; the design is the swarm's `design/T2.3.md` section 5, which is not an enhancement entry.
