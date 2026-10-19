> **Gates.** `task bundles:pull build` needs the network and a lock for the real bundles, which this change cannot use (no v2 bundle is published). Every section's site gate is `task test:site` (Docker, no network, fixtures only), which builds the site over the v1 and v2 fixtures. `task qa` is not run: it needs a `task build` over real bundles. The visual result is read from the fixture build's HTML instead (section 2.5).

## 1. Spike: the v2 fixture and Hugo aliases

- [x] 1.1 Write the fixture source `site/tests/fixtures/ws/enhancements-v2/` per design.md Decision 7 and `regen-enhancements-v2.sh`; build `site/tests/fixtures/bundles-v2/enhancements/edge/` with docs-kit's `opm-docs` built from branch `feat/read-openspec-enhancements` (head `9d768e8`) on a copy; verify `jq .schema` prints `.../v2` and the bundle holds each page the source implies.
- [x] 1.2 Measure with a throwaway adapter patch over the v2 fixture: does `AddPage` honour `aliases`, and where is the stub written. Write the result into design.md Decision 4 ("Measured") and keep or replace the mechanism.
- [x] 1.3 Record the v1 baseline: build the v1 fixture on the unchanged site and keep the built `public/enhancements/` tree for the byte comparison in 2.4 (scratch, not committed).
- [x] 1.4 `task check` and `task test:site` green, then commit `test(site): add a v2 enhancements bundle fixture`.

## 2. Read data v1 and v2

- [x] 2.1 `gen-mounts.sh`: accept v1 and v2, refuse another schema naming both, and check `layout` on every v2 entry; turn case `enh-bundle-data-schema` into a `v3` case and add `enh-bundle-layout` (v2 entry with no layout).
- [x] 2.2 `_content.gotmpl` (the normal form of design.md Decision 2, `retired` per Decision 4, `capability` params), `opm/enh-status.html` (the six states, progress, the header rows of Decision 3) and `enhancements.css` for the new rows; `custom/head-end.html` publishes the stubs and `build-all.sh` the `_redirects` lines and their checks; `check-pages.sh` expects the alias stubs the data lists and no other extra page (case `enh-alias-target-missing`: an alias whose target page does not exist has no stub and fails).
- [x] 2.3 `test-site.sh`: a section that builds the site over `bundles-v2` and asserts the page set, each banner, the header rows of an accepted, a superseded and a draft entry, the capability page and its table, the alias stubs and their targets.
- [x] 2.4 The v1 fixture's built `public/enhancements/` is byte-identical to the baseline of 1.3 (`diff -r` prints nothing).
- [x] 2.5 Read the v2 fixture's built HTML for the entry header, banner and capability page; fix what reads wrong (the HTML was read; no screenshot, see the report).
- [x] 2.6 `task check` and `task test:site` green, then commit `feat(site): read enhancements data v1 and v2` (Correction: sections 2 and 3 share this one commit, because the tests of both live in one `test-site.sh` block).

## 3. Render hooks

- [x] 3.1 `render-heading.html` keeps `#d3` on legacy pages only; `render-table.html` classes the new INDEX columns; verify on the v1 and v2 fixtures (anchor present on 0001 decisions, absent on a new-layout page; the INDEX columns carry their classes).
- [x] 3.2 `render-link.html` and `opm/enh-aliases.html`: a link to a retired slug resolves to the replacing page without its fragment; a case with a site-owned page linking `/enhancements/<migrated>/problem/` builds, and a link to a missing page still fails (`q1-broken-link` stays green). Update the hook's comment. `site/overrides.sha256` is untouched (it pins upstream).
- [x] 3.3 `task check` and `task test:site` green, then commit as section 2 (Correction: one commit for sections 2 and 3).

## 4. Durable decisions, verification, archive

- [x] 4.1 Land design.md's Durable decisions: `AGENTS.md` (Durable decisions, "The Enhancements section"; Repository Layout for the new fixture directories) and `README.md` ("The Enhancements section", the link rule, the order of adoption); the header of `test-site.sh` names the v2 fixture.
- [x] 4.2 Verify with the `openspec-verify-change` skill (the diff touches only the files proposal.md's Impact names; every durable decision landed), `task check` and `task test:site` green, then commit `docs(site): land the enhancements data v2 decisions`.
- [x] 4.3 Archive with `openspec archive read-enhancements-data-v2 --yes --skip-specs`, run `task openspec:check`, and commit `chore(openspec): archive read-enhancements-data-v2`.
