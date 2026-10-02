## Context

The site is one Hugo 0.167 build over Hextra v0.13.0, run in Docker with `--network none`. Sources are the six repositories' `docs/site/` trees, mounted per version from `site/.versions/<v>/` (a `git archive` of the SHAs `resolve-versions.sh` picks from `site/versions.conf`), or read in place in explicit mode (`OPM_VERSIONS`). The enhancements repository (27 publishable entries, 216 core pages, Mermaid in 36 fences, generated INDEX.md and GRAPH.md) is not a source today. `research-notes.md` in this change holds the research and the spike report in full; `.claude/worktrees/enhancements-tab-spike` holds the spike's code.

Files under `site/` this change touches are listed in proposal.md's Impact. Section 1 also touched `site/scripts/gen-stamp.sh` (the stamp's `sections` key), `site/assets/js/opm-pagefind.js` and the override copies `layouts/_partials/scripts/search.html`, `sidebar.html` and `components/last-updated.html`, the site's own `layouts/sitemap.xml`, plus `opm/source.html`, `opm/build-stamp.html`, `opm/docs-main.html`, `opm/version-switch.html` and `custom/head-end.html`; no upstream pin in `site/overrides.sha256` changed. Section 2 adds `site/vendored.sha256`, `site/scripts/check-vendored.sh` (a build step), `site/NOTICE`, `site/tests/browser/{diagrams,qa_common,a11y,shots}.py` and `site/scripts/run-in-image.sh` (diagrams.py in `shots` and `qa`), and pins one more upstream file, Hextra's `layouts/_markup/render-codeblock-mermaid.html`, behind the section's copy of it. The build gains one vendored input: Mermaid 11.17.2. Section 3 overrides one more upstream file, Hextra's `layouts/_markup/render-blockquote-alert.html` (pinned in `site/overrides.sha256`), and touches `site/layouts/_markup/render-link.html`, `site/layouts/{page,section}.markdown.md`, `site/assets/css/opm/typography.css` and `site/tests/browser/{qa_common,a11y}.py`.

## Goals / Non-Goals

**Goals:**
- The enhancements are readable on the site, in one section, with their diagrams, under stable URLs keyed by id.
- No reader takes a draft for a feature: a status banner on every page, `noindex` on draft and accepted entries, no section page in `llms.txt` or the docs search.
- The docs build stays as strict as it is: every existing check keeps failing on what it fails on today outside the section.

**Non-Goals:**
- Versioning the enhancements (0021: enhancements are not versioned).
- Publishing experiments, research notes, schemas or policy files; their links go to GitHub at the built SHA.
- Rendering `authors` or `history` from `config.yaml`.
- Rewriting `0018:D3`-style tokens in prose into links (a later change).

## Decisions

### 1. One unversioned section in the same build, via a content adapter

`site/enhancements/_content.gotmpl` reads the mounted tree with `os.ReadDir`/`resources.Get`, parses `config.yaml` with `transform.Unmarshal`, and calls `AddPage` per entry and per numbered document with `url` front matter, which publishes outside `/<version>/` while the pages sit in the default version's page tree. The adapter is mounted into the default version only, so the section moves with the default version and its URLs never change. Verified in the spike: 218 pages, the tab active on every one, a second version renders without warning under `--panicOnWarning`.

**Alternatives:** mounting into every version (duplicates the record per version and contradicts 0021); a second Hugo build (no `GetPage` across builds, a second config to keep in sync); host-side conversion with sh/awk (brittle YAML and link rewriting).

### 2. The section page is generated outside the adapter

`AddPage` refuses an empty path, and a `site/content/` `_index.md` is mounted into every version. The section page is written by the build scripts from INDEX.md (front matter plus its body with comments removed) into a default-only mount.

### 3. Source pinned like the others

`[section "enhancements"] ref = origin/main` in `site/versions.conf`; the resolver records its SHA in `build-stamp.json` and `frozen.conf`; `override = <sha> <reason>` is the escape hatch when the repository breaks the build. Only the published files are archived (not `archive/0019/experiments`, 30 MB, not `0000/`, not the gitignored `diagrams/`). Page dates come from `config.yaml`'s `updated`.

### 4. Exclusions are explicit

`FirstSection == enhancements` drives: no version label, no `/latest/` stub, no edit link (or one to the enhancements repository), no `llms.txt` entry, no sitemap entry, and a section-scoped Pagefind bundle. `noindex` is set by status (draft, accepted).

### 5. Mermaid vendored, sized and fenced in

Mermaid 11 under `site/assets/lib/mermaid/`, fingerprinted with SRI and loaded only by pages with a fence (Hextra's `params.mermaid.js`). `useMaxWidth: false` inside a focusable scroller: without it 21 of 36 diagrams render text under 9 px, with it none. Edge labels need a contrast fix in dark mode. A global codeblock hook fails a fence outside the section, so docs pages stay diagram-free (0018:D14).

As built (section 2): the file is the npm tarball's `dist/mermaid.min.js`, verified against the registry's `dist.integrity` and pinned in `site/vendored.sha256` (SHA-256 581ed7d7…eb8, identical to the spike's copy), checked by `check-vendored.sh` with the `vendored-drift` fixture. `useMaxWidth: false` is an init directive the section hook prepends, so Hextra's `scripts/mermaid.html` stays un-overridden. Dark mode keeps Mermaid's dark theme (it follows the site's toggle) and darkens only the edge-label box (#ccc on #585858, 4.4:1, becomes #ccc on neutral-800) by an `!important` rule in `enhancements.css`, because Mermaid scopes its rules by the diagram's id; forcing the light theme would have put a white panel in the dark page. `diagrams.py` draws all 36 diagrams at 1280 px light and 390 px dark and fails on an error drawing, a label under 9 px or an axe colour-contrast violation, after proving on two canary diagrams that it catches the first two.

### 6. Direction notes link the section

The dialect lint accepts `/enhancements/<id>/` (and `#fragment`); the contract and its embedded lint change with it. A NOTE alert titled **Direction** gets its own look, so the notes on What OPM does not do stand out from ordinary notes.

As built (section 3): the lint accepts exactly `/enhancements/`, `/enhancements/<NNNN>/` and `/enhancements/<NNNN>/<document>/` (one of the seven slugs), each with an optional `#fragment`, and rejects every other path under `/enhancements` (no graph, no deeper path, no missing slash, no version prefix); `lint/link-enhancements` holds the rejected forms and `lint/clean` the accepted ones. The docs link hook resolves such a link through `hugo.Sites`, since the section's pages sit in the default version's page tree only, so every version links the same unversioned URL (`dialect-two-versions`); a missing entry or document, or a build without the section, fails the build (`enh-docs-missing-entry`, `enh-docs-link-without-section`). The Markdown output (`page.markdown.md`, `section.markdown.md`) writes such links as absolute URLs, like `/docs/` ones. A direction note is detected in an override of Hextra's `render-blockquote-alert.html` (pinned in `overrides.sha256`): a NOTE with no Obsidian title whose rendered body opens with the paragraph `<strong>Direction</strong>` is wrapped in `div.opm-direction`, labelled Direction in place of Note and its title line dropped, so the label is not said twice. `typography.css` gives it Tailwind's violet, the colour the GRAPH gives categories, a 3 px dashed start border (work not built) and a tinted box, against the ordinary note's grey; every other alert renders as upstream. A CSS-only rule cannot do it: the bold title is a paragraph inside the alert body, and the label Note is in markup a selector cannot rewrite. Inside the section, a link whose text is the file name it targets (`INDEX.md`, `GRAPH.md`, `03-decisions.md`) reads as the page ("the index", "the relationship graph", or the page's link title); the entry README's metadata line stays, because dropping it means pattern-matching one line of prose the enhancements repository owns, while relabelling holds for any file-name link anywhere in the record.

## Research & Decisions

### Does the build's machinery allow an unversioned section?
**Context**: every page today lives under `/<version>/`.
**Explored**: content adapters, `url` front matter, permalinks config, menu `pageRef`, `relURL` in each version (spike, 2026-10-01).
**Decision**: content adapter plus `url` front matter, mounted into the default version.
**Rationale**: only `url` escapes the version prefix; permalinks do not. The menu resolves in every version.

### Which checks object, and why?
**Context**: the spike ran the full suite.
**Explored**: check-front-matter (fires: adapter pages report the adapter as their file), check 10 (fires on `-->` in code blocks and Mermaid edges), the fixture suite (43 pass, 11 fail: the tab's link has no target without the source), llms/sitemap/stub/edit-link/search (leak by default).
**Decision**: fix each in section 1 with a fixture, never by weakening a check outside the section.
**Rationale**: the built site is the contract; a check that stops covering the docs is a regression.

### How does the tab exist only with the section?
**Context**: the menu lives in `config/_default/hugo.toml`; a menu entry in the generated `config/<env>/hugo.toml` replaced the whole `menus.main` (section 1 build: only Enhancements was left).
**Explored**: Hugo's config merge (it cannot merge slices across config directories), a front-matter menu on the section page (absent from every non-default version), a navbar override.
**Decision**: `gen-mounts.sh` writes the Enhancements entry together with a verbatim copy of `_default`'s `[menus]` block, only when the section is built; `_default` stays the one place the other entries are written.
**Rationale**: no theme override, the tab shows in every version (checked by the two-version test), and a build without the section shows no dangling tab.

### What do repository links that name nothing do?
**Context**: ten links on published pages name no path at the built SHA today (six `../../core/*.cue` links in archive/0001, `../INDEX.md` and `../GRAPH.md` in archive/0015 and 0016); the enhancements link fix is in flight there.
**Explored**: failing the build (every run red until enhancements merges), rendering them unlinked (spike).
**Decision**: the section's link hook links them to GitHub at the built SHA, marks them, and `build-all.sh` lists them after the build without failing. A link that climbs out of the repository, a broken `/docs/` link and a shortcode delimiter still fail.
**Rationale**: the enhancements repository owns the fix and its CI is the gate for it; once that CI lands, the listing can become a failure here.
**Superseded in section 3**: the enhancements repository fixed the ten links and gates them in its CI (b250137, PR 78), so a repository link that names nothing at the built SHA now fails the build (`enh-unresolved-link`), and the marker and the listing are gone. A link to a file that exists but is not published (an experiment, research, a schema, `config.yaml`) still goes to GitHub at that SHA.

## Risks / Trade-offs

- [Readers take a draft for a feature] -> banner on every page, `noindex` for draft and accepted, no docs-search or `llms.txt` presence.
- [A push to enhancements breaks every site run] -> its CI lands first; `override` pins a known-good SHA.
- [Stale INDEX/GRAPH] -> the enhancements freshness check.
- [3.5 MB of Mermaid on diagram pages; large GRAPH diagrams on a phone] -> loaded only where used; scroller; QA label-size rule.
- [Hugo behaviour reliance (`url` escaping the version prefix)] -> verified on 0.167; the fixture suite and the two-version test catch a regression on a Hugo bump.

## Durable decisions

- **The enhancements are an unversioned section at `/enhancements/`, built from the enhancements repository at a resolved SHA, with URLs keyed by id.** Lands in README ("Site versions" and "Sources") and AGENTS.md.
- **Draft and accepted entries are `noindex` and stay out of `llms.txt` and the docs search.** Lands in README.
- **Mermaid renders only inside the section; a fence elsewhere fails the build.** Lands in README ("Adding a figure") and AGENTS.md.
- **Vendored third-party files are pinned in `site/vendored.sha256` with version and source, checked before every build, and re-vendored from source, never re-pinned from disk.** Lands in AGENTS.md (Repository Rules) and README ("The Enhancements section").
- **Every section diagram is drawn in the QA image and fails on an error, a label under 9 px or under AA contrast (`diagrams.py`).** Lands in README and AGENTS.md (`task shots`).
- **Source pages may link `/enhancements/`, `/enhancements/<NNNN>/` and `/enhancements/<NNNN>/<document>/`, each with an optional `#fragment`, and nothing else under `/enhancements`; a link to a page the section lacks fails the build.** Lands in the dialect contract and README ("Page dialect"); the workspace `STYLE.md` follows in its own PR.
- **A NOTE alert whose bold title line is Direction renders as a direction note: labelled Direction, in its own violet, dashed-border box.** Lands in README ("Page dialect") and the dialect contract.
- **Inside the section, a repository link that names nothing at the built SHA fails the build; a link to an existing unpublished file goes to GitHub at that SHA.** Lands in README ("The Enhancements section").
