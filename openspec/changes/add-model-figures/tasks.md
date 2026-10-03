## 1. Figures

- [ ] 1.1 Add `opm/what-opm-models` (id `wom`, 360 x 580, title "What OPM models today"): `site/layouts/_shortcodes/opm/what-opm-models.html` and `site/layouts/_partials/opm/figures/what-opm-models.html` (design.md Decision 1).
- [ ] 1.2 Add `opm/two-models-one-boundary` (id `tmb`, 360 x 420, title "Two models, one boundary"): `site/layouts/_shortcodes/opm/two-models-one-boundary.html` and `site/layouts/_partials/opm/figures/two-models-one-boundary.html` (design.md Decision 2).
- [ ] 1.3 Add both names to `FIGURES` in `site/scripts/lint-sources.sh` and their titles to `site/layouts/_partials/opm/figure-titles.html` ("nine figures"); README names nine dialect figures.
- [ ] 1.4 Add both figures to the dialect contract in `openspec/changes/deploy-site/orchestration.md` (two table rows, "Exactly these nine names", embedded lint byte-identical to `lint-sources.sh`, its sha256), draw both in the fixture start page, and count nine figures in `test-site.sh`; land the durable decisions (design.md) in README, the contract and the bodies' comments.
- [ ] 1.5 `task check`, `task ci` and `task qa` green; build the fixture workspace and read the `/docs/start/` PNGs of both figures in all six variants: no text under 9 px, no label crossing a box edge or an arrow, both themes. Then commit `feat(site): add the what-opm-models and two-models-one-boundary figures`.

## 2. Verify and archive

- [ ] 2.1 Follow `.claude/skills/openspec-verify-change/SKILL.md` for `add-model-figures`; check that `git diff --stat origin/main` touches only the files in proposal.md's Impact.
- [ ] 2.2 Archive with `openspec archive add-model-figures --yes --skip-specs`, run `openspec validate --all --strict --no-interactive`, and commit `chore(openspec): archive add-model-figures`.
