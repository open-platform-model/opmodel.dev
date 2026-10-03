## Context

The Catalogs tab (`add-catalogs-tab`, archived 2026-10-03) builds `/catalogs/opm/<segment>/` from pulled bundles: `gen-catalogs.sh` derives `data/opm/catalogs.json` from the lock and each `manifest.json`, `gen-mounts.sh` mounts `*/*/manifest.json`, `*/*/content/**` and `*/*/data/*.json` at `assets/bundles`, and `site/catalogs/_content.gotmpl` adds every page with `params.catalog`. The real tab today has two segments, `4.5` and `edge`.

docs-kit `add-version-history` (contract C13, read at `origin/plan/phases-1b-2-3`, `openspec/changes/add-version-history/design.md`) makes `pull` write `<out>/<project>/history.json` for each tab project with two or more catalog segments, and record its digest in the lock's optional `history` key (C7). Its D4 fixes the format and the derivations the site applies; this design quotes them rather than restating C13.

The build gains one input file per tab project and one pinned tool version. No URL, version or theme override changes.

## Goals / Non-Goals

**Goals:**

- Show C13's derivations on member pages and kind indexes, exactly as C13 words them, and nothing the file does not say.
- Fail the build when the mounted `history.json` is not the one the lock recorded.
- Build and test everything but the tool bump against fixtures, before G1b.

**Non-Goals:**

- Computing any history in the site (Principle III: the site generates no pages, and it computes no reference data).
- A diff view, per-field badges inside the spec block (`docs-kit DESIGN decision 12`; C13 puts field changes in the list), history for docs-placed bundles (they have no segments), or `level`/`appliesTo`/`servedBy` changes (not in C13).

## Decisions

### 1. Input and integrity check

`gen-mounts.sh` adds `'*/history.json'` to the `assets/bundles` mount's `files` list. `gen-catalogs.sh` reads the lock's `history` entries (`jq '.history // []'`) and, per tab project:

```text
entry and file     sha256(file) == entry.digest, else fail:
                   "gen-catalogs: catalog-opm: history.json is sha256:<have>, the lock records sha256:<want>; run task bundles:pull"
entry, no file     fail: "gen-catalogs: catalog-opm: the lock records history.json, but <dir> has none"
file, no entry     ignored (a stale file from an older pull); no badges
neither            no badges
```

It also checks `schema == "docs.opmodel.dev/history/v1"` and `project` equal to the entry, and writes into `catalogs.json` per catalog: `"history": {"path": "catalog-opm/history.json", "floor": "<floor>"}` or `null`. Nothing else reads the lock.

### 2. Adapter data

`site/catalogs/_content.gotmpl` loads the history once per catalog (`resources.Get` + `transform.Unmarshal`) and adds to every page's `params.catalog`:

```text
history: {
  floor:   "4.5"
  member:  members[<page fqn>] | null            // member pages only, by the fqn in data/catalog.json
  mode:    compared[to == <segment>].mode | ""   // the pair that ends at this segment
  removed: removed[<segment>] filtered to this kind   // kind index pages only
  lineage: lineage["<kind>/<name>"][<segment>]   // member pages only
}
```

The adapter never derives anything; templates apply C13's derivation table. Besides the keys above it adds `fqn` (the page's member) and `pages` (that member's pages in this segment by apiVersion, from `data/catalog.json`), which the "Newer version" link resolves through.

The value is a JSON string (`""` without history) that templates unmarshal, not a map (implementation finding): Hugo rewrites a page's params maps in place, lowercasing their keys, and the C13 maps are shared by every page of a member, so a map param raced between pages (`fatal error: concurrent map writes` in a fixture build) and lost C13's camel-case keys.

### 3. Badges, list, removed entries

Under the member title (`history-badge.html`), one row of up to three badges:

| Badge | Condition (C13 D4) | Shown on |
|---|---|---|
| origin, exactly one of: "Unreleased" / "Added in `<first>`" / "In `<floor>` or earlier" | `first == "edge"` / `first` a minor and not `firstIsFloor` / `firstIsFloor` | every segment's page of the member |
| "Changed in `<segment label>`" | `member.changes[<segment>]` exists | that segment's page only |
| "Newer version" | `lineage[0] != member.apiVersion` | that segment's page |

docs-kit's orchestration says "one badge from C13's derivations"; this reads it as one origin badge plus the two page-specific ones, since an "Added in 4.5" member can also have changed in 4.6 (decided in planning; the owner may narrow it).

"Newer version" when `lineage[0] != member.apiVersion`, linking `<root><segment>/<kind>s/<name>-<lineage[0]>/` (the page path the bundle's manifest lists for that FQN; the link is resolved through `catalogs.json`, never built from a pattern, and fails the build if the page is missing). `<segment label>` is the label `catalogs.json` already carries ("4.5", "main (unreleased)").

At page end (`history-changes.html`), only when `member.changes[<segment>]` exists, a `## Changes in <segment label>` section with one bullet per change in file order:

```text
added      `retention.weekly` added
removed    `retention.monthly` removed
presence   `retention.daily` made required          (C13's table: to required "made required", to optional "made optional", optional -> regular "no longer optional", required -> regular "no longer required")
type       `retention.daily` type changed from `int` to `int & >0`
default    `schedule` default changed from `"0 2 * * *"` to `"0 3 * * *"`
ref        `target` now refers to `#BackupTarget`
spec       The spec changed in a way the field list does not show.
```

When `mode == "paths"`, the list opens with one sentence: "Compared by field paths only: these two builds were made by different docs-kit minors, so type, default and reference changes are not shown." (as built: edge is no minor, and `ref` is skipped too). A `default` or `ref` change with one side `null` reads "now defaults to", "no longer has a default (was ...)", "now refers to", "no longer refers to". On a kind index (`history-removed.html`), a "Removed in `<segment label>`" list linking `<root><lastIn>/<page>/`; a member whose kind has no index left in the segment (its last member is gone) is listed on the segment's landing instead; the build fails, naming the link, when that page is missing. `gen-catalogs.sh` refuses a history holding a value the site would word or link by that C13 does not allow: a `compared` mode other than `full` or `paths`, a `first` or `lastIn` that is not one of `segments`, a change op outside C13's seven, a presence change that is not between two different presences.

As built (Hextra's TOC reads only the rendered content, so a heading a layout writes would need an override copy of `toc.html`): the adapter appends both sections to the page body as Markdown that `history-changes.html` and `history-removed.html` return (the derivations stay in those templates; the adapter only calls them), so the TOC, the heading anchor and scroll offset, search and the `.md` output carry them. A Removed link names another segment of the page's own catalog, which the catalogs link hook refuses for bundle text; it carries the title `opm:removed`, which the hook accepts for that one case (still failing when the page is missing) and does not write out, and which the `.md` outputs drop. On a kind index the Removed section therefore comes before the child cards. The badges render from Hextra's `custom/content-begin.html` hook (beside the type badge, in one `.opm-badges` row), not from `layouts/catalogs/{list,single}.html`: both catalogs layouts delegate to `opm/docs-main.html`, whose title area that hook already sits in, so no layout or override copy changes. "Changed in X" shows only the page's own segment (docs-kit orchestration); C13's derivation table says "every key of `changes`", reported to docs-kit.

### 4. Fixtures before the gate

The drift test (`test-site.sh` re-pulls `site/tests/fixtures/bundles/` offline with the pinned tool and fails on any byte difference) cannot hold a `history.json` the pinned tool does not write. So sections 1 and 2 keep a hand-written C13 file outside that tree:

```text
site/tests/fixtures/history/catalog-opm/history.json    hand-written to C13 D4, for 4.4 (floor), 4.5, edge
```

`test-site.sh` layers it onto its copy of the fixture bundles and adds the matching `history` entry to that copy's lock with `jq`, so every badge test runs. Section 3 deletes the hand-written file and asserts the pinned tool's output equals it byte for byte before deleting; any difference is a contract mismatch, reported to docs-kit, never fixed by editing the site's expectation silently.

The fixture segments stay `4.4`, `4.5` and `edge` (docs-kit's orchestration names `4.5`, `4.6`, `edge`; the site keeps the segments its existing tests use). Content (as built; the planned `v1beta1` member became edge's `expose@v1alpha2`, so the existing switch and link tests keep their pages): `backup@v1alpha2` in all three, changed in 4.5 by one of each field op (`ref`, `type`, `default`, `presence`, `added`, `removed`) and in edge by four `presence` changes and an `added` (with 4.5's two, every transition C13 words); `volumes@v1beta1` changed in 4.5 by its spec text only (`spec`); `backup@v1alpha1` in 4.4 only ("Newer version" there, removed in 4.5); `stateless-workload@v1` removed in edge, whose blueprints index goes with it, so edge's landing lists it; `expose@v1alpha1` added in 4.5 and changed in edge, where `expose@v1alpha2` is new ("Unreleased") and takes the bare page, so edge's `traits/expose-v1alpha1` shows all three badges; a `paths`-mode pair by giving edge's manifest `tool` `0.2.0`. History values avoid `<`, `>` and `&`, which Go's encoder escapes unless told not to, so section 3's byte comparison tests the contract, not an escaping choice.

### 5. Files under `site/`

`Dockerfile`; `scripts/{gen-mounts,gen-catalogs,gen-stamp,test-site}.sh` (`gen-stamp.sh` records `sections.catalogs.history: [{project, digest}]`); `catalogs/_content.gotmpl`; `layouts/_partials/custom/content-begin.html` (a Hextra hook, not an override copy); `layouts/catalogs/_markup/render-link.html` and `layouts/{page,section}.markdown.md` (the `opm:removed` link mark); `layouts/_partials/opm/history-{badge,changes,code,removed}.html`; `assets/css/opm/history.css`; `tests/checks/cat-q2/` (it now drops edge's retention page, since 4.4's `backup-v1alpha1` is linked by the Removed list); `tests/fixtures/{bundles,history}/`; `tests/checks/` cases; `tests/browser/` shot list.

## Research & Decisions

### Read the history, never compute it

**Context**: the site already has every segment's `data/catalog.json` and could diff them in a template.
**Explored**: docs-kit `add-version-history` D2/D3 (tool-minor gate, `spec` token comparison with comments skipped, recompute on every pull); `scratchpad/research-1b-3.md`.
**Decision**: the site reads `history.json` only.
**Rationale**: the comparison needs CUE token scanning and tool-minor knowledge the site does not have; one implementation keeps the badge and the producer's view equal.

### Hand-written history file before the gate

**Context**: sections 1 and 2 must run before G1b, and the fixture tree is byte-compared with the pinned tool's output.
**Decision**: a hand-written C13 file layered by `test-site.sh`; section 3 proves the tool writes the same bytes.
**Rationale**: it turns the gate into a conformance test of the contract instead of a re-baseline.

## Risks / Trade-offs

- [C13 moves before G1b] -> the hand-written file is the only place that encodes it; section 3's byte comparison catches any drift, and docs-kit's PR is re-read before section 3 starts.
- [A change hidden behind `ref` is not reported] -> under-claiming is accepted by C13; the list says nothing it cannot back.
- [Today's real tab has one pair, 4.5 and edge] -> most real pages show "In 4.5 or earlier" until 4.6 ships; that is correct, not a defect.

## Durable decisions

- The site reads history, never computes it; badges and the list follow C13's derivations only. Lands in `AGENTS.md` (Site versions, "The Catalogs section") and `README.md` ("The Catalogs section").
- A `history.json` whose digest differs from the lock fails the build; recovery is a fresh `task bundles:pull`. Lands in `README.md`.
- Field changes appear only in the page-end list, never inside the spec block. Lands in `README.md`.
