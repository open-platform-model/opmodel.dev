## 1. Pin

- [x] 1.1 `site/Dockerfile`, `AGENTS.md`, `README.md` and the tool fields of the fixtures name `opm-docs` 0.9.0
- [x] 1.2 `task bundles:pull` reports no link error, then commit `chore(site): pull bundles with opm-docs 0.9.0`

## 2. Fixture

- [x] 2.1 Move the fixture source to the OpenSpec layout, fold the v2 fixture into `regen-enhancements.sh`, delete the v2 script and `bundles-v2/`
- [x] 2.2 Update `test-site.sh`, `bundle-page.sh`, two checks, the lock commit, `AGENTS.md` and `README.md`
- [x] 2.3 `task ci` green, then commit `test(site): build the enhancements fixture from the OpenSpec layout`
