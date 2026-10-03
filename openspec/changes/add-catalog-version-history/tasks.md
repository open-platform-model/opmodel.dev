> **Gate (section 3 only).** Sections 1 and 2 need nothing from docs-kit or the registry and may merge as their own PR before the gate (the real lock has no `history` entry, so the real build is unchanged). Section 3 starts at **G1b**: docs-kit `add-version-history` released (expected `v0.3.0`) (the current pin, opm-docs `0.2.2` from opmodel.dev#25, is the base). Re-read docs-kit's `docs/contracts.md` C13 at that release before starting it.

## 1. History input from fixtures

- [x] 1.1 Fixtures per design.md Decision 4: enrich `site/tests/fixtures/bundles/catalog-opm/{4.4,4.5,edge}/data/catalog.json` with real `fqn`s and `spec.fields` (C10) and the members the badges need, and the matching pages and manifests; regenerate `site/tests/fixtures/bundles/lock.json` with the pinned tool (`--local`, offline) and confirm the drift test passes.
- [x] 1.2 Write `site/tests/fixtures/history/catalog-opm/history.json` by hand to C13 (docs-kit `add-version-history` D4: key order, two-space indent, trailing newline) for those fixtures, with one `paths`-mode pair; `test-site.sh` layers it and a `history` lock entry (`jq`) onto its copy of the fixture bundles.
- [x] 1.3 `gen-mounts.sh` mounts `*/history.json`; `gen-catalogs.sh` performs Decision 1's checks and writes `history` per catalog into `catalogs.json`; `gen-stamp.sh` records `sections.catalogs.history`.
- [x] 1.4 Check cases under `site/tests/checks/`, each failing on its fixture: `cat-history-digest` (file edited after the lock), `cat-history-missing` (entry without file), `cat-history-schema` (wrong `schema`); a stale file without an entry yields no badges (asserted in `test-site.sh`).
- [x] 1.5 `site/catalogs/_content.gotmpl` adds `params.catalog.history` per Decision 2; `test-site.sh` asserts the params of one member page and one kind index from `hugo` output (the adapter's data, not yet rendered).
- [x] 1.6 `task check`, `task build` (real bundles: no history entry, no change) and `task test:site` green, then commit `feat(site): read catalog version history from the pulled bundles`.

## 2. Badges, the Changes list and Removed entries

- [x] 2.1 `layouts/_partials/opm/history-badge.html` and `assets/css/opm/history.css` per Decision 3; `layouts/catalogs/single.html` renders the badge row under the title; "Newer version" resolves its page through `catalogs.json` and fails the build naming the FQN when the page is missing (case `cat-history-newer-missing`).
- [x] 2.2 `history-changes.html` (the page-end list, the `paths`-mode sentence) and `history-removed.html` (kind index entries linking `<root><lastIn>/<page>/`); `layouts/catalogs/list.html` renders the latter.
- [x] 2.3 `test-site.sh` assertions on the built fixture pages: each origin badge, "Changed in 4.5", "Newer version" target, every list line form, the `paths` sentence on the edge pair, a Removed entry and its link, and no badge in any spec code block.
- [x] 2.4 Browser QA: `shots.py` adds a member page with all three badges and the list, and a kind index with a Removed entry (light, dark, phone); `a11y.py` covers them.
- [x] 2.5 `task check`, `task build`, `task test:site` and `OPM_BUNDLES=site/tests/fixtures/bundles task qa` green, the new PNGs read (badges legible in dark mode and at phone width), then commit `feat(site): show catalog version badges and change lists`.

## 3. The pinned tool writes the history (GATED: G1b)

- [ ] 3.1 `site/Dockerfile`: `OPM_DOCS_VERSION` and `OPM_DOCS_SHA256` of the release carrying `add-version-history` (the `opm-docs_<v>_linux_amd64.tar.gz` line of its `checksums.txt`, checked against a second download); `task image`; `opm-docs version` prints it. Re-sync `site/tests/lint/` cases that changed in docs-kit's conformance set at that tag, naming the tag in `link-catalogs/SOURCE`.
- [ ] 3.2 Re-pull the fixtures with the new tool (`--local`, offline): `catalog-opm/history.json` and the lock's `history` entry appear; assert the file is byte-identical to the hand-written one, then delete `site/tests/fixtures/history/` and the layering in `test-site.sh`. A difference is reported to docs-kit before anything here changes.
- [ ] 3.3 Real build: `task bundles:pull build`; `catalog-opm/history.json` exists for `4.5` and `edge`, the stamp names its digest, a 4.5 member shows "In 4.5 or earlier", an edge-only member "Unreleased".
- [ ] 3.4 Land the durable decisions: `AGENTS.md` (Site versions, "The Catalogs section": the site reads history, never computes it; Technology stack opm-docs version), `README.md` ("The Catalogs section": badges, the list, the digest check and its recovery).
- [ ] 3.5 `task check`, `task build`, `task test:site` and `task qa` green on the real bundles, the real member PNGs read, then commit `feat(site): pull catalog version history with opm-docs <version>`.
- [ ] 3.6 Verify with the `openspec-verify-change` skill (the diff touches only the files proposal.md's Impact names; every durable decision has landed), then archive with `openspec archive add-catalog-version-history --yes --skip-specs`, run `task openspec:check`, and commit `chore(openspec): archive add-catalog-version-history` (the archive rides this section's PR).
