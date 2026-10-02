## 1. Build scripts and checks: one docs rule for every released repository

- [x] 1.1 In `site/scripts/resolve-versions.sh` `resolve_line`, send cli, library and opm-operator through `release_docs` (empty prefix) as core is, keeping every pin read at the release tags; the override "no longer needed" test uses `release_docs` for library and opm-operator too; update the header comments. Verify `sh site/scripts/resolve-versions.sh --check` on the real roots shows cli, library and opm-operator with `docs` `main` and `ref` still the release tag
- [x] 1.2 `--freeze`: a cli row whose docs are not its tag freezes by its docs SHA, preceded by `; cli <tag>, docs <docs>`; verify `--freeze` on the real roots prints it
- [x] 1.3 `site/tests/versions/test-resolve.sh`: state A rows carry the docs rule for cli, library and opm-operator; `line-cli-main` (cli docs from `main`'s head, pins from the tag), `line-cli-freeze` and `line-cli-freeze-check`; state B adds `release/v2.3` (library) and `release/v3.1` (opm-operator) and the branch, stamp, freeze and recover cases expect them; `real-line-frozen` expects the cli docs SHA. Verify `sh site/tests/versions/test-resolve.sh` reports 0 failed
- [x] 1.4 Comments: `site/versions.conf` header and the schedule comment in `.github/workflows/site.yml` name the rule for all five repositories
- [x] 1.5 `task check`, `task build` and `task test:site` green (the built `/v1.0/` footer stamp shows cli, library and opm-operator at `main` with a commit), then commit `feat(site): build cli, library and operator docs from their branch heads`

## 2. Durable decisions

- [x] 2.1 `AGENTS.md` Site versions: the docs rule names all five released repositories, and the floor and containment checks hold for each
- [x] 2.2 `AGENTS.md` Reserved sections: a generated CLI reference is generated from the cli release the stamp names (`ref`), never from the docs tree
- [x] 2.3 `README.md`: the line resolution table, the docs rule, "So a docs fix reaches the site", the CI "Source repositories" paragraph, the frozen-manifest paragraph (a cli frozen by its docs SHA with a comment) and the recovery paragraph (a cli docs head can fail a check)
- [x] 2.4 `task check` green, then commit `docs(site): record one docs rule for every released repository`

## 3. Archive

- [x] 3.1 Archive the change on this branch (`openspec archive --skip-specs`), so the archive rides the implementing PR; never push to main. `task check` green, then commit `chore(openspec): archive build-docs-from-branch-head`
