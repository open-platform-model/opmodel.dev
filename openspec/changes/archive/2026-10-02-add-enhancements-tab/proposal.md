## Why

The owner wants the enhancements, OPM's design record, on opmodel.dev as a tab of their own next to Docs and Reference: the INDEX, the GRAPH, every entry and its diagrams (decision 2026-10-01). The docs already point at them: What OPM does not do carries direction notes that link enhancements (0018:D3 as amended 2026-10-01), today through GitHub. A spike (worktree `enhancements-tab-spike`, 2026-10-01) built the tab on Hugo 0.167 with all 36 Mermaid diagrams rendering offline, and listed what the existing checks need.

## What Changes

- A new **Enhancements** tab in the navbar, between Reference and Search, shown only when the build has the enhancements source.
- An unversioned section at `/enhancements/`, outside `/<version>/`, built in the same Hugo run by a content adapter over the enhancements repository:
  - `/enhancements/`: the INDEX, with a status banner saying entries are designs, not features;
  - `/enhancements/graph/`: the GRAPH;
  - `/enhancements/NNNN/`: an entry's README with a header from its `config.yaml` (status, category, affects, dates, links to `depends_on` and `amends`);
  - `/enhancements/NNNN/{problem,design,decisions,graduation,risks,operational,questions}/`: its seven documents.
  All 27 entries are published, live and archived; URLs are keyed by id, so archiving an entry keeps them.
- The enhancements repository becomes an eighth source, recorded in `site/versions.conf`, resolved to a SHA and stamped like the others, and materialised as a `git archive` of only the published files.
- Draft and accepted entries carry `noindex` and stay out of `llms.txt` and the sitemap. The section has its own search bundle, separate from the docs.
- Mermaid 11 is vendored and loaded only on pages that draw a diagram, with a width and dark-mode rule; a Mermaid fence anywhere else fails the build.
- A direction note (a NOTE alert whose title line is **Direction**) gets its own style, and source pages may link `/enhancements/NNNN/` (the page dialect gains that link form).
- Nothing is **BREAKING**: no docs URL, version or theme override changes.

## Before / After

**Before**

```text
navbar        Docs · Reference · Search · GitHub · Theme
sources       opm core catalog_opm cli library opm-operator (versioned, per site/versions.conf)
public/       <version>/... · latest/ · index.html · reference-archive/
dialect       links: /docs/<section>/<page>/ only
mermaid       a fence fails the build (no network, no CDN)
```

**After**

```text
navbar        Docs · Reference · Enhancements · Search · GitHub · Theme   (Enhancements only when the source is mounted)
sources       + enhancements (unversioned, [section "enhancements"] in site/versions.conf, ref resolved to a SHA)
public/       + enhancements/ (index, graph/, NNNN/, NNNN/<document>/), own Pagefind bundle
site/         + enhancements/_content.gotmpl, + layouts/enhancements/, + assets/lib/mermaid/ (vendored, pinned)
dialect       links: /docs/<section>/<page>/ and /enhancements/<id>/ (with an optional #fragment)
mermaid       renders inside /enhancements/ only; a fence anywhere else still fails the build
```

## Impact

- **Files.** `site/config/_default/hugo.toml`, `site/versions.conf`, `site/scripts/{resolve-versions,materialise,gen-mounts,run-in-image,build-all,check-pages,lint-sources,test-site}.sh`, new `site/enhancements/`, `site/layouts/enhancements/`, `site/layouts/_markup/render-codeblock-mermaid.html`, partials for the banner, header and exclusions, `site/assets/css/opm/enhancements.css`, `site/assets/lib/mermaid/` with its licence and pin, test fixtures, `.github/workflows/site.yml` (one more checkout), `README.md`, `AGENTS.md`, and the dialect contract in `openspec/changes/deploy-site/orchestration.md`. As built, also `site/vendored.sha256` with `site/scripts/check-vendored.sh` (the Mermaid pin), `site/NOTICE`, the Hextra overrides `render-blockquote-alert.html` and the section partials, `gen-stamp.sh`, `serve.sh`, `opm-pagefind.js`, `sitemap.xml`, the Markdown output layouts and the browser and version tests; design.md's Context lists every file.
- **Build inputs.** One gained: the enhancements repository at a resolved SHA. One vendored file: Mermaid 11.
- **Source repos.** enhancements: its CI (vet, link and freshness checks) must land first, so a broken link there cannot turn every site build red; its own PR. opm: switch the six direction-note links on What OPM does not do from GitHub to `/enhancements/NNNN/` after this merges. Workspace `STYLE.md` ("Site Pages"): name the `/enhancements/` link form.
- **Published URLs.** Added: `/enhancements/` and below. Nothing moved or removed. The version set is unchanged; enhancements are unversioned (0021:OQ15 is not touched).
- **Depends on:** the enhancements CI and link-fix PR.

## Enhancement

None implemented, so no `enhancement.yaml`. It follows 0018:D3 as amended on 2026-10-01 (direction notes may link enhancements).
