# Tasks: docs-catalog-contract

> Content-only change. Bare-`@` ban applies to commits/PR (the pages themselves are file content, which is safe, but keep module paths glued regardless for copy-paste hygiene).

## 1. The catalog contract page

- [x] 1.1 `site/content/reference/catalog-contract.md` per design section order: levels + two-axes trap, the additive rule with three worked examples matching the gate's violation vocabulary, the three version-shaped values table, enforcement + the aid-not-guarantee honesty paragraph (no registry-side enforcement claimed).
- [x] 1.2 Cite decisions inline (0010 D4/D27/D34/D35, 0011 D23) as restated rules, not links-only.

## 2. The registry namespaces page

- [x] 2.1 `site/content/reference/registry-namespaces.md`: the prefix table (core, catalogs, modules, templates incl. `index` reservation and shortcut rationale, platforms-reserved, testing, community, everything-else-unpoliced) with enforcement point + defining decision per row (0011 D13/D14/D25).
- [x] 2.2 Hosts-not-indexes and shortcut-safety framing paragraphs.

## 3. Wiring + verification

- [x] 3.1 `site/content/reference/_index.md` links both pages.
- [x] 3.2 `task build` clean; visual check via `task serve` (front matter, nav, tables render).
- [x] 3.3 Workspace root `CLAUDE.md`: one line under Registry Policy pointing at the templates segment (internal counterpart of the public page).

## 4. Record

- [x] 4.1 `enhancements/0010/`: slice `docs-catalog-contract` → `done`, `openspec_ref: "opmodel.dev/docs-catalog-contract"`, history event noting 0010's implementation phase closes with it (only `modules-fleet-republish` remains, behind 0011's `modules-publish-cutover`).
