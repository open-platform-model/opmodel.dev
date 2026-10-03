## 1. The catalog picker

- [ ] 1.1 Add `site/layouts/_partials/opm/catalog-entries.html` (design.md Decisions 2 and 4).
- [ ] 1.2 Add `site/layouts/_partials/opm/catalog-picker.html` and `site/assets/css/opm/catalog-picker.css`; render the picker in place of `.Content` on `/catalogs/` in `opm/docs-main.html` (Decisions 1 and 3).
- [ ] 1.3 List each catalog in the `/catalogs/` sidebar (`site/layouts/_partials/sidebar.html`, Decision 5).
- [ ] 1.4 In `site/scripts/gen-catalogs.sh`'s last block only, write the one-sentence description and the generated Markdown list (Decision 1).
- [ ] 1.5 Add a `catalogs/picker` check to `site/scripts/test-site.sh`: the fixture `/catalogs/` links every catalog's newest release from a card title, its main from the card, lists every catalog in the sidebar, and its `index.md` links both.
- [ ] 1.6 Land the durable decisions in `README.md` ("The Catalogs section").
- [ ] 1.7 `task check`, `task test:site` and `task bundles:pull build` green; `task shots` (or the QA image) at `/catalogs/` in light, dark and phone width, plus a scratch build with a second catalog, PNGs read. Commit `feat(site): make the catalog picker the first thing on the Catalogs tab`.

## 2. Verify and archive

- [ ] 2.1 Follow `.claude/skills/openspec-verify-change/SKILL.md` for `make-catalog-picker-visible`; check that `git diff --stat origin/main` touches only the files in proposal.md's Impact.
- [ ] 2.2 Archive with `openspec archive make-catalog-picker-visible --yes --skip-specs`, run `openspec validate --all --strict --no-interactive`, and commit `chore(openspec): archive make-catalog-picker-visible`.
