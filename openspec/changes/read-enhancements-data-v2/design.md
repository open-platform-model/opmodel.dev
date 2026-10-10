## Context

The Enhancements section is one unversioned section at `/enhancements/`, built from the enhancements repository's signed section bundle (docs-kit C21). `gen-mounts.sh` checks the bundle and writes the section page; `site/enhancements/_content.gotmpl` adds every other page with its `url` and header params; `opm/enh-status.html` prints the status banner and the entry header; three hooks under `site/layouts/` shape its Markdown. All of them read `data/enhancements.json` as schema v1 (`gen-mounts.sh` refuses any other).

docs-kit's branch `feat/read-openspec-enhancements` (head `9d768e8`, C21 on that branch) writes schema v2: each entry has `layout` (`legacy` or `openspec`); a `legacy` entry keeps every v1 field; an `openspec` entry adds `breaking` (true, false or null), `after`, `supersededBy` as a list, `accepted` as `{date, commit}` or null, `progress {done, total}`, `capabilities`, `documents` (proposal, design, requirements, tasks) and `aliases` (`{from, to}` page paths, only for a migrated entry). It also writes pages the site has not met: `<NNNN>/{proposal,design,requirements,tasks}`, `capabilities/_index` and `capabilities/<capability>`, and an INDEX with `Progress` and `Breaking` columns and a Capabilities table (`Capability | Requirements | Purpose`). docs-kit writes data only; the site adds Hugo `aliases` itself.

The `opm-docs` pin in `site/Dockerfile` is 0.7.0, which writes and pulls v1 only. The docs-kit release carrying v2 does not exist yet, so nothing here can pull a real v2 bundle.

## Goals / Non-Goals

**Goals:**

- v1 data renders exactly as today: the built HTML of the v1 fixture is byte-identical before and after.
- v2 data renders every field docs-kit emits, and the retired slugs of a migrated entry redirect from the old URL.
- A page of another repository that still links a retired slug keeps building.

**Non-Goals:**

- Bumping the `opm-docs` pin, pulling a real v2 bundle, or deciding when `enhancements` adopts the reader.
- Rewriting any page: the producer's pages are rendered as they come (the section rule in AGENTS.md).
- A semver field: the site never showed one, so there is nothing for `breaking` to replace.

## Decisions

### 1. The data gate accepts v1 and v2

```sh
# gen-mounts.sh
case "$(jq -r '.schema // ""' "$D" 2>/dev/null)" in
  docs.opmodel.dev/data/enhancements/v1) ;;
  docs.opmodel.dev/data/enhancements/v2)
    # layout is read first (C21)
    bad=$(jq -r '.entries[] | select((.layout // "") != "legacy" and (.layout // "") != "openspec") | .id' "$D")
    [ -z "$bad" ] || enh_fail "data/enhancements.json (v2) entries without a layout of legacy or openspec: $bad" ;;
  *) enh_fail "data/enhancements.json is missing, or not docs.opmodel.dev/data/enhancements/v1 or .../v2" ;;
esac
```

The existing case `enh-bundle-data-schema` (v2 string over a v1 body) stops being a failure; it becomes a `v3` string. The v2 gate is the producer's contract restated at the smallest size; the rest of the shape is the producer's lint, not the site's.

### 2. One normal form in the adapter

```text
layout        = entry.layout | "legacy"                       (v1 has none)
supersededBy  = list: entry.supersededBy as a list, a string as [string], null/absent as []
breaking, after, accepted, progress, capabilities, repo = entry fields, absent for v1
```

A v1 entry gets `layout=legacy` and an empty `after`, and no `breaking`, `accepted` or `progress`, so every v1 row of the header stays as it is. `repo` (the data file's `repo`) lets the header link the accepted commit.

### 3. Status banner and entry header

```text
status       banner text (first words)
draft        Draft design.
accepted     Accepted design, not delivered.   + " N of M tasks shipped." when progress.total > 0
delivered    Delivered, closed.
superseded   Superseded by 0010, 0011, closed.  (the ids joined by ", ")
rejected     Rejected, closed.
withdrawn    Withdrawn, closed.   Kept as a record; it does not describe OPM.
other        Status <x>.          (unchanged)
```

The header (`dl.opm-enh-meta`, on the entry's own page) keeps its rows and order and adds, for a v2 entry only: After (after Created/Updated, links like Depends on), Breaking (yes or no; no row for null), Progress (N of M tasks shipped; no row when total is 0), Accepted (the date, the commit linked to `https://github.com/<repo>/commit/<sha>`), Capabilities (each name linked to its capability page when the section has one, else plain text). `Superseded by` joins the list. A v1 entry prints the same rows it prints today.

A capability page and the capabilities index carry `capability: true`, which gives the banner a third wording: "A capability: requirements OPM meets, kept in one place. The page lists the entries that changed it." The banner has no draft or accepted claim for them, because a capability page describes the main specs, not an entry.

### 4. Retired slugs get redirect stubs (spike, section 1)

```text
data:  entry.aliases = [{from: "0013/problem", to: "0013/proposal"}, ...]
site:  the target page carries param retired = ["0013/problem", ...]    built from the data before the page loop
       custom/head-end.html publishes, for each, a meta-refresh stub at /enhancements/<from>/index.html
       (noindex, canonical to the target), as it does for the catalog aliases
       build-all.sh writes the _redirects line "/enhancements/<from>/ /enhancements/<to>/ 301"
       check-pages.sh expects exactly those stubs among the section's pages
```

Unverified assumption at proposal time (docs-kit's design record lists it too): Hugo's content adapter `AddPage` honours the front matter key `aliases`, and the stub lands at `/enhancements/<from>/`.

Measured 2026-10-11 (section 1, Hugo 0.167.0, the v2 fixture, entry 0026):

```text
AddPage "aliases": ["/enhancements/0026/problem/"]
  -> honoured: public/v1.0/enhancements/0026/problem/index.html, a refresh to the target's absolute permalink
  -> NOT at /enhancements/0026/problem/: Hugo writes an alias under the output root of the site that holds
     the page (the default version's v1.0 directory), although the page's own url ignores that prefix.
     The old URL 404s, the stub sits where no link points, and check Q2 (page set of v1.0) fails on it.
```

**Chosen:** the catalogs section's pattern, not Hugo `aliases`. A stub published with `resources.FromString(...).Publish` lands at the path it is given, with no version prefix, and `_redirects` carries the permanent redirect for hosts that read it. `AddPage` `aliases` stays unused.

### 5. Links to a retired slug keep resolving

`render-link.html` resolves an `/enhancements/` link through `GetPage`; a miss fails the build. A signed docs bundle of another repository (v1.0's cli, core, library) cannot change after release, and its pages link `/enhancements/0021/decisions/#d3`. When 0021 migrates, that page stops existing and the build would fail until the bundle is republished. So a miss first looks the path up in a map built from the data's `aliases` (`opm/enh-aliases.html`, cached): a hit links to the replacing page and drops the fragment (an anchor such as `#d3` does not survive, C21); a miss fails as before. The map is empty for v1 data, so v1 behaviour is unchanged.

### 6. Hooks

- `render-heading.html`: the extra `d<N>` anchor on a `D<N>:` heading stays, and now only when the page's `layout` param is not `openspec`. A new-layout page has no numbered decisions, and no anchor is added where none can be cited. The adapter sets `layout` on every entry page; the section page and the graph have none and keep today's behaviour.
- `render-table.html`: the class map gains `Progress` (no wrap), `Breaking` (hidden below 48 rem, as Category), `Capability` (no wrap), `Requirements` (no wrap) and `Purpose` (hidden below 48 rem, as Summary). `Affects`, `Category`, `Summary`, `Why closed`, `Delivery`, `ID`, `Status` keep their classes.
- `render-link.html`: section 5. Its comment names the new slugs.

### 7. Fixtures and proof

```text
site/tests/fixtures/ws/enhancements-v2/        source: docs-kit's extractor test repository (legacy 0003 and 0025,
                                               openspec/changes/{0026,0042}-*, archive/{0040,0041,0043,0044},
                                               two seeds, two main specs) plus this repository's 0043, 0044 and INDEX.md
site/tests/fixtures/bundles-v2/enhancements/edge/   its bundle, built by docs-kit's opm-docs (branch, head 9d768e8)
site/tests/fixtures/regen-enhancements-v2.sh   rebuilds it with the opm-docs on PATH (not the pinned one)
```

The fixture entries cover: `draft` with no `breaking` decision (0042); `accepted` with `breaking: true`, `accepted {date, commit}`, progress and six aliases (0026, a migrated entry); `delivered`, `rejected`, `withdrawn` (0043) and `superseded` by a two-id list (0044); legacy `superseded` by one id (0003) and a legacy draft (0025); a seed change and two main specs, so a capability page with an "Entries that changed it" table exists. `test-site.sh` gains a section that builds the site over this bundle (the v1 fixture's lock with the enhancements entry's `commit` set to the v2 manifest's, because the pinned `opm-docs` cannot re-pull a v2 bundle) and asserts on the built HTML. The existing `enhancements/fixture-regen` check keeps proving the v1 fixture. The real-content proof (docs-kit's `opm-docs` over the `enhancements` swarm branch) is a one-off run, recorded in the report, not committed.

## Research & Decisions

### Which data version a v1 entry reads as
**Context**: `layout` is a v2 field; a v1 file has none, and the site must render it unchanged.
**Explored**: docs-kit C21 ("an old-layout entry has every v1 field and gains `layout`; a consumer reads `layout` first"); the v1 fixture.
**Decision**: a missing `layout` reads as `legacy`.
**Rationale**: v1 entries are exactly the legacy entries; no second code path.

### Retired-slug links
**Context**: Section 5. Options: (a) leave `render-link` strict and require every docs bundle to be republished first; (b) resolve through the alias map; (c) have docs-kit rewrite links.
**Explored**: `render-link.html`; C21 (aliases are data, links are not rewritten by docs-kit); the migration's order (docs bundles of released versions are immutable).
**Decision**: (b).
**Rationale**: (a) cannot work for a released bundle; (c) is not in docs-kit's contract and changes signed content. (b) is 15 lines and inert for v1.

## Risks / Trade-offs

- [Redirect stubs and `_redirects` lines drift apart] -> both come from the data's `aliases`, and `build-all.sh` fails when a stub or a line is missing.
- [The v2 fixture can drift from docs-kit's output because the pinned tool cannot rebuild it] -> `regen-enhancements-v2.sh` records the recipe and the docs-kit head; the pin-bump PR runs it and folds the two fixtures into one regeneration check.
- [The data gate lets an unknown v2 field through] -> docs-kit's contract says fields are added, never changed; an unknown field is ignored by the adapter.
- [A v2 INDEX column the class map does not know] -> an unclassed column still renders; it only loses its phone rule.

## Durable decisions

- The site reads data schema v1 and v2; a missing `layout` is `legacy`; a new schema (v3) is refused by name. Lands in `AGENTS.md` (Durable decisions, "The Enhancements section") and `README.md` ("The Enhancements section").
- Retired slugs: the data's `aliases` become meta-refresh stubs at the old URL (as the catalog aliases do) and `_redirects` lines, never Hugo `aliases` (they land under the default version's directory), and `render-link.html` resolves a link to a retired slug to that page without its fragment. Lands in `README.md` ("The Enhancements section" and the link rule under Contributing) and `AGENTS.md`.
- The v2 fixture is built outside the image until the pin moves; its recipe is `regen-enhancements-v2.sh`. Lands in the header of `test-site.sh` and `README.md`.
- The order of adoption (docs-kit release, this change and the pin bump, then the `enhancements` bump). Lands in `README.md`.
- Workspace `STYLE.md` "Site Pages" link rule is the owner's follow-up in the workspace repository; this repository's docs name it.
