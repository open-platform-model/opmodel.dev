## Why

`main` is red since 2026-10-12. The pinned `opm-docs` 0.7.1 rejects the links `/enhancements/capabilities/<slug>/` and `/enhancements/<NNNN>/{proposal,requirements,tasks}/` that the enhancements edge bundle now holds, because its link rule predates the OpenSpec store layout. `opm-docs` 0.8.0 accepts them and 0.9.0 is the newest release. The site must bump first (docs-kit C12), as the producers already write the new layout.

0.9.0 also refuses a live old-layout entry folder in the fixture source `site/tests/fixtures/ws/enhancements/`, so that source moves to the OpenSpec layout in the same change.

## What Changes

- `site/Dockerfile`: `OPM_DOCS_VERSION=0.9.0` and the SHA-256 of the `linux_amd64` archive from the release `checksums.txt`.
- `AGENTS.md` and `README.md` name 0.9.0 and describe the new fixture source.
- The fixture source `ws/enhancements/` becomes the OpenSpec-layout tree that `ws/enhancements-v2/` held, plus the old entries 0001 and 0002 as archived legacy entries (0.9.0 accepts legacy entries only under `archive/`).
- `regen-enhancements.sh` builds from it and sets the progress of the draft 0042 (the old v2 fixture was edited by hand). `regen-enhancements-v2.sh`, `bundles-v2/` and the v2 lock overlay (`use_enhancements_v2`) go.
- Fixtures record the tool version (`0.9.0`) and the commit of the rebuilt enhancements bundle.
- `site/scripts/test-site.sh` and two checks read the new fixture: the page-set counts, the GitHub paths of `archive/0001`, one more Mermaid page (0026), and `enh-bundle-layout` drops the layout instead of setting the schema.

## Before / After

**Before**

```text
site/tests/fixtures/
  bundles/enhancements/edge/      v1 data, built from ws/enhancements/ (live 0000, 0001; archive/0002)
  bundles-v2/enhancements/edge/   v2 data, built by hand-run regen-enhancements-v2.sh
  ws/enhancements/  ws/enhancements-v2/
  regen-enhancements.sh  regen-enhancements-v2.sh
```

**After**

```text
site/tests/fixtures/
  bundles/enhancements/edge/      v2 data, 60 pages, rebuilt and diffed by task test:site
  ws/enhancements/                openspec/ tree, archive/0001 0002 0003 0025
  regen-enhancements.sh
```

## Impact

- Files: `site/Dockerfile`, `AGENTS.md`, `README.md`, `site/scripts/test-site.sh`, `site/tests/bundle-page.sh`, `site/tests/checks/enh-alias-target-missing`, `site/tests/checks/enh-bundle-layout`, `site/tests/fixtures/**`.
- No source repo changes. No published URL or site version changes: the site reads the same bundle.
- Lost coverage: no fixture holds schema v1 data any more (the pinned tool writes v2 only), so no test reads a v1 `data/enhancements.json`. Legacy entries stay covered through the v2 `layout: legacy` entries.
- Risk: a wrong checksum fails the image build.

## Enhancement

None.
