## 1. Reveal

- [x] 1.1 Remove the `?themefx` experiment from `opm-theme-transition.js`; keep reveal for pointer switches, fade for keyboard and OS switches, nothing in the three no-animation cases.
- [x] 1.2 Keep the old toggle icon in the old snapshot (design.md Decision 2).
- [x] 1.3 Add `site/tests/browser/theme_reveal.py` and run it in `run-in-image.sh qa` (Decision 3); README lists the feature and the check.
- [x] 1.4 `OPM_VERSIONS=v1.0=/src task ci` and `task qa` green; read mid-transition PNGs at 1280 and 390 px, both directions. Commit `feat(site): animate the theme switch with a circular reveal`.

## 2. Verify and archive

- [x] 2.1 Follow `.claude/skills/openspec-verify-change/SKILL.md` for `add-theme-reveal`; check that `git diff --stat origin/main` touches only the files in proposal.md's Impact.
- [x] 2.2 Archive with `openspec archive add-theme-reveal --yes --skip-specs`, run `openspec validate --all --strict --no-interactive`, and commit `chore(openspec): archive add-theme-reveal`.
