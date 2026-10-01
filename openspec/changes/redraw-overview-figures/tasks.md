## 1. Figures

- [x] 1.1 Replace the bodies and shortcodes of `opm/landing-overview` (372 x 498), `opm/module-to-cluster` (360 x 680) and `opm/helm-and-opm` (360 x 606) with the owner-approved drafts and their claims (design.md Decisions 1 to 3).
- [x] 1.2 Add `opm/one-trait-any-provider` (id `otp`, 360 x 658, title "One trait, any provider"): `site/layouts/_shortcodes/opm/one-trait-any-provider.html` and `site/layouts/_partials/opm/figures/one-trait-any-provider.html`.
- [x] 1.3 Add `one-trait-any-provider` to `FIGURES` in `site/scripts/lint-sources.sh` and its title to `site/layouts/_partials/opm/figure-titles.html`; README names seven dialect figures.
- [x] 1.4 Add the figure to the dialect contract in `openspec/changes/deploy-site/orchestration.md` (table row, embedded lint byte-identical to `lint-sources.sh`, its sha256), draw it in the fixture start page, and count seven figures in `test-site.sh`; land the durable decisions (design.md) in README, the contract and the partials' comments.
- [x] 1.5 `task check`, `task ci` and `task qa` green; read the landing, `/docs/start/` and `/docs/start/what-is-opm/` PNGs in all six variants: no text under 9 px, no label crossing its box, both themes. Then commit `feat(site): redraw the overview figures and add one-trait-any-provider` (with a review-fix commit `fix(site): register one-trait-any-provider in the dialect contract and fixture`).

## 2. Verify and archive

- [ ] 2.1 Follow `.claude/skills/openspec-verify-change/SKILL.md` for `redraw-overview-figures`; check that `git diff --stat origin/main` touches only the files in proposal.md's Impact.
- [ ] 2.2 Archive with `openspec archive redraw-overview-figures --yes --skip-specs`, run `openspec validate --all --strict --no-interactive`, and commit `chore(openspec): archive redraw-overview-figures`.
