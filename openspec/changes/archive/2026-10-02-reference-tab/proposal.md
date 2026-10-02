# Proposal: reference-tab

## Why

The navbar has a Reference tab, but it only points at `docs/reference/`, which is also a section of the Docs sidebar. The owner wants Reference to be its own tab beside Docs and Enhancements, gone from the Docs left-hand list. The site-owned Reference pages also still describe the v0 `docgen` tool and kinds that no longer exist (`ModuleRelease`, `Policy`).

## What Changes

- The sidebar override shows the Reference tree alone on a page under `docs/reference/`, and leaves Reference out of every other docs page's tree. The docs home's cards leave it out too.
- A `navbar-link.html` override marks only the Reference tab current on those pages (Hextra marks Docs too, since its section holds them).
- The URLs stay under `/docs/reference/`, so no source page, link or release changes.
- `check-pages.sh` records the Reference tree in `nav-order-reference.txt`; the fixture test asserts each tree holds only its own pages.
- The three site-owned Reference pages are rewritten to say what they will hold, without the v0 content.

## Before / After

```text
Before                                   After
navbar: Docs | Reference | Enhancements  navbar: Docs | Reference | Enhancements
docs sidebar: Start here ... Reference,  docs sidebar: Start here ... Diagnostics
              Diagnostics                reference sidebar: Reference > Definitions,
                                                    CLI Reference, Catalog members, ...
on a reference page: Docs and Reference  on a reference page: Reference current
both current
.check/<v>/nav-order.txt                 .check/<v>/nav-order.txt, nav-order-reference.txt
```

## Impact

Site-owned templates, pages, checks and tests only. No source repo changes.
