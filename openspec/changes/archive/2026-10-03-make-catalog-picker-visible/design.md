## Context

`gen-catalogs.sh` writes `.gen/catalogs/_index.md`, the `/catalogs/` section page, from `data/opm/catalogs.json`: front matter (`description`, `params.cards: false`) and a Markdown body of two paragraphs and one bullet per catalog. `custom/content-begin.html` shows the description as the lead. `opm/docs-main.html` renders the body. `sidebar.html` shows only the page itself on `/catalogs/` (`$leafOnly`). Each segment's landing page (`/catalogs/<name>/<segment>/`) is added by `site/catalogs/_content.gotmpl` in the default version's page tree, the same tree as `/catalogs/`, so `site.GetPage` finds it.

## Goals / Non-Goals

**Goals:**

- Picking a catalog is the first thing a reader sees on `/catalogs/`, in both themes and at phone width.
- Everything on a card is generated, for any number of catalogs.
- A lone catalog looks intentional: a full-width card, not a grid cell beside empty space.

**Non-Goals:**

- A catalog display name or description that no bundle carries (Decision 2).
- Changes to the per-segment landings, the version switch, or anything PR 31 touches.

## Decisions

### 1. Cards replace the body in HTML; the body stays for Markdown

`gen-catalogs.sh` marks the `/catalogs/` page `params.picker: true`, and `opm/docs-main.html` and `sidebar.html` key on it. On that page `opm/docs-main.html` MUST render `opm/catalog-picker.html` in place of `.Content`. `gen-catalogs.sh` keeps writing a Markdown body, now one generated list item per catalog with both links, which only the Markdown twin (`index.md`, "View as Markdown") shows. The page description becomes the one short sentence, shown as the lead:

```yaml
description: Pick a catalog to read the reference of its newest release.
```

```markdown
Pick a catalog to read the reference of its newest release.

- [opm catalog](/catalogs/opm/): newest release 4.5.1 ([main, unreleased](/catalogs/opm/edge/)), from `open-platform-model/catalog_opm`
```

The HTML and Markdown outputs then differ in shape but not in facts: both come from `catalogs.json`.

### 2. What a card shows, and where it comes from

No bundle carries a display name or a description for a catalog: `manifest.json` has none, `site/bundles.cue` (docs-kit C7's schema) has none, and the landing page's title and description are the catalog contract page's ("The Catalog Contract"), not the catalog's. So the card uses only facts the build has:

| Card part | Source |
| --- | --- |
| Title `<name> catalog` (`opm catalog`) | `catalogs.json` `name`, the tab root's last segment |
| Module path `opmodel.dev/catalogs/opm@v4` | `modulePath` in the newest segment's `data/catalog.json`, when the bundle carries it; omitted otherwise |
| Member kinds with counts (`5 Blueprints`) | the newest landing's child sections (title, weight order); the count is the number of distinct member names in `data/catalog.json` whose `page` lies in that section; without catalog data the kind shows without a count |
| Repository `open-platform-model/catalog_opm` | `catalogs.json` `repo` (text, not a link: the bundle names no host) |
| Newest release `4.5.1`, beside the title with an arrow | the newest segment's `version` |
| Links | the newest segment's landing, and `edge`'s landing as "main (unreleased)" |

A catalog with no release yet links its card to `edge` and says "No release yet"; it has no second link.

The name is shown as written (`opm`), never upper-cased: the tab name is a path segment and the catalog's CUE module name, and the version switch already reads `opm 4.5`. The description already exists at the source: core's `#Catalog.metadata.description`, which catalog_opm fills. docs-kit's cue-catalog extractor does not copy it into `data/catalog.json`; once it writes `description` there, the card shows it (the card already reads the optional field). A display name waits on a tab-only `placement.title` in docs-kit's manifest; `#Placement` is closed, so the site must accept the field before a bundle carries it.

### 3. One card shape, one column

Cards are stacked, full width, at every width and for any count. Two columns would leave the only card today beside empty space, and a catalog's facts (module path, kinds, repository) read better on one wide row than in a narrow cell. The card is a list item whose title link is stretched over the card with a `::after` box (the whole card is the newest-release link, keyboard focus lands once on the title); the "main (unreleased)" link is positioned above that box, so it stays its own target. No link nests inside another.

The styles live in `site/assets/css/opm/catalog-picker.css`, on Hextra's colour variables, with dark mode keyed on `html.dark`, like `cards.css`.

### 4. One data partial for the cards and the sidebar

`opm/catalog-entries.html` returns one dict per catalog (name, title, href, release, edgeHref, repo, modulePath, kinds) and is called with `partial` (twice per build, only on `/catalogs/`, so it needs no cache). `opm/catalog-picker.html` and `sidebar.html` both read it, so the sidebar entry and the card can never point at different pages.

### 5. The sidebar on `/catalogs/`

In the `$leafOnly` branch `sidebar.html` adds one entry per catalog under the root entry, titled `<name> catalog`, linking the same page as its card. A catalog page's own sidebar (its segment's tree) does not change.

## Research & Decisions

### Where the landing comes from
**Context**: The task named `gen-catalogs.sh` and the adapter as candidates.
**Explored**: `site/catalogs/_content.gotmpl` adds only segment pages; the adapter cannot add the empty path, so `gen-catalogs.sh` writes `.gen/catalogs/_index.md` (its last block). PR 31 edits `gen-catalogs.sh`'s header comment, a new history block and the `jq` that writes `catalogs.json`, not the last block.
**Decision**: Change only the last block of `gen-catalogs.sh`; render the cards from a template.
**Rationale**: A template can read the pages and the bundle data; Markdown cannot hold a stretched-link card without raw HTML, which the site's pages never use.

### Where a display name could come from
**Context**: The task asked for the catalog's title and one-line description "from its bundle/manifest if available".
**Explored**: the pulled 4.5.1 and edge bundles (`manifest.json`, `data/catalog.json`, `content/_index.md`), `site/bundles.cue`.
**Decision**: Decision 2's table; no invented prose.
**Rationale**: The landing's title is the contract page's, and a hand-written name in this repo would be content the site engine owns (Constitution I).

## Risks / Trade-offs

- [A future bundle has no `data/catalog.json`] -> The card drops the module path and the counts and still shows the kinds, the release and both links.
- [Many catalogs] -> Stacked full-width cards grow the page linearly; acceptable for the handful of catalogs a platform publishes.

## Durable decisions

- **`/catalogs/` lists catalogs as generated cards, and its Markdown body only feeds the Markdown twin.** Lands in `README.md` ("The Catalogs section") and in the head comments of `opm/catalog-picker.html` and `gen-catalogs.sh`.
- **A card shows only facts the bundles carry; the description waits on docs-kit's cue-catalog extractor writing `description` into `data/catalog.json`, and a display name on a tab-only `placement.title` in docs-kit (closed `#Placement`, so the site accepts it first).** Lands in `README.md` ("The Catalogs section").
