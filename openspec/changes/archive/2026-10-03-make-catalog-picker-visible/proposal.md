## Why

The owner opened `/catalogs/` and found no way to choose a catalog: "there is no option to choose which catalog", then "I saw it now but it is not intuitive. You can easily miss it like I did". The landing shows a lead sentence, two paragraphs of prose, then one small bullet where only the word `opm` is a link. The sidebar shows only "Catalogs". The owner also asked for each catalog to be displayed more clearly, although there is one today.

## What Changes

- **A card per catalog**, generated from `data/opm/catalogs.json` and the bundles, so it holds for any number of catalogs: the catalog's name, its CUE module path (when the bundle carries catalog data), the member kinds it covers with their counts, its repository, its newest release, and links to the newest release and to main (unreleased). The whole card links to the newest release; the main link sits on top of it. Cards are full width and stacked, so one catalog fills the row instead of a half-empty grid.
- **The sidebar on `/catalogs/`** lists each catalog under the tab root, linking its newest release (main for a catalog with no release yet).
- **One short sentence** above the cards, as the page description (the lead), in place of the two paragraphs and the bullet list. The page's Markdown twin keeps a generated list of the catalogs with both links, so "View as Markdown" and readers of `index.md` still get them.
- **A site check** in `test-site.sh`: the fixture landing links every catalog's newest release from a card, its main from the card, and the sidebar lists every catalog.

## Before / After

**Before** (`/catalogs/`)

```text
h1 Catalogs
lead  The reference of every catalog OPM publishes, one tab per catalog, versioned by ...
p     Each catalog documents its members once per minor release, ...
ul    - [opm](/catalogs/opm/): `open-platform-model/catalog_opm`, newest release 4.5
sidebar: Catalogs
```

**After**

```text
h1 Catalogs
lead  Pick a catalog to read the reference of its newest release.
ul.opm-catpick
  li.opm-catpick-card (one per catalog, stacked, full width)
    h2 a[href=/catalogs/opm/4.5/]  opm catalog        Newest release 4.5.1 ->
       (the title link is stretched over the card)
       opmodel.dev/catalogs/opm@v4
       5 Blueprints  13 Resources  28 Traits
       From open-platform-model/catalog_opm   a[href=/catalogs/opm/edge/] main (unreleased)
sidebar: Catalogs
           opm catalog -> /catalogs/opm/4.5/
```

## Impact

- **Files.** `site/scripts/gen-catalogs.sh` (only the block that writes `.gen/catalogs/_index.md`), `site/layouts/_partials/opm/catalog-entries.html` (new), `site/layouts/_partials/opm/catalog-picker.html` (new), `site/layouts/_partials/opm/docs-main.html`, `site/layouts/_partials/sidebar.html`, `site/assets/css/opm/catalog-picker.css` (new), `site/scripts/test-site.sh` (one new check block), `README.md`, and this change directory.
- **Build inputs.** None added: the cards read `data/opm/catalogs.json`, the pages the adapter already adds, and each newest bundle's `data/catalog.json`, already mounted at `assets/bundles`. No theme file is newly overridden; `sidebar.html` and `docs-main.html` are existing OPM copies, and their upstream pins in `site/overrides.sha256` do not change.
- **Published URLs.** None added or removed. `/catalogs/` changes content; site versions are unaffected (the section is unversioned).
- **Source repos.** None has to change. A display name and a one-line description per catalog exist in no bundle (see design.md); adding them is a docs-kit follow-up, not part of this change.
- **Overlap.** opmodel.dev PR 31 (catalog version history) edits other blocks of `gen-catalogs.sh` and other hooks; this change stays out of them.
- **Sections.** One implementation section, then verify and archive.

## Enhancement

None implemented, so no `enhancement.yaml`.
