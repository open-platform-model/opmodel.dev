> **Gates.** Sections 1 and 2 need `serve-docs-from-bundles` sections 2 and 4 merged (its section 1 was folded into its producer sections on 2026-10-04) and change nothing the real build reads; they may be committed before the gate. Sections 3 and 4 start at **G3.4**: `serve-docs-from-bundles` sections 2, 3 and 4 merged (v1.0's `from-bundles` names all six repositories and the Enhancements section is bundle-built). One PR; its merge is docs-kit's **G3.5**.

## 1. Spike: dates for site-owned pages

- [ ] 1.1 Measure design.md Decision 1's options a, b and c in a worktree build, a main-checkout build and a CI run on a branch: does every site-owned page get its last commit date, with what mounts and what host steps. Write the result and the choice into design.md Decision 1, replacing "Expected outcome".
- [ ] 1.2 Implement the choice (expected: `site/scripts/gen-site-dates.sh`, run by `build` and `serve` on the host, writing `data/opm/lastmod.json` for `site/content` only), alongside `gen-lastmod.sh` for now; a case `site-dates-missing` fails when a committed site page has no date under `OPM_REQUIRE_DATES=1`.
- [ ] 1.3 `task check`, `task build` (dates on the landing and every overview, read from the built HTML) and `task test:site` green, then commit `feat(site): date site-owned pages without the source archives`.

## 2. Every test builds from bundle fixtures

- [ ] 2.1 Move every page left in `site/tests/fixtures/ws/` into `site/tests/fixtures/bundles/_versions/v1.0/<project>/` (manifests to C3), and add `_versions/v0.9/` per design.md Decision 3 (the enhancements fixture stays layered until `serve-docs-from-bundles` section 4 moves it into the pulled set); re-pull every fixture offline and update the fixture lock; the drift test passes.
- [ ] 2.2 Port every check case and `test-site.sh` assertion that used the fixture workspace to the bundle fixtures; list the cases that tested only the resolver, archives or floors, to delete in section 3.
- [ ] 2.3 `check-two-versions.sh` builds `v1.0` and `v0.9` from bundles and keeps its assertions (own pages per version, the switcher, catalogs and enhancements once outside both); `site/tests/subpath/` builds from the bundle fixtures.
- [ ] 2.4 `task check`, `task build` and `task test:site` green with the fixture workspace unused (`grep -rn fixtures/ws site/scripts` finds nothing), then commit `test(site): build every fixture from docs bundles`.

## 3. Delete the git pipeline (GATED: G3.4)

- [ ] 3.1 Delete `site/scripts/{resolve-versions,materialise,gen-lastmod}.sh`, `site/tests/versions/test-resolve.sh` and its fixtures, `site/tests/fixtures/ws/`, the cases listed in 2.2, `site/.versions/` handling in `task clean` and `.gitignore`.
- [ ] 3.2 `site/versions.conf` per design.md Decision 2 and its cross-check in `sections.sh` (case `versions-conf-mismatch`, case `versions-conf-unknown-key`); `gen-mounts.sh`, `sections.sh`, `build-all.sh`, `serve.sh`, `gen-stamp.sh`, `opm/source.html`, `opm/build-stamp.html` and `components/last-updated.html` lose their git branches; `from-bundles` is gone.
- [ ] 3.3 `run-in-image.sh` loses `sources()`, the `/src/<repo>` and enhancements mounts, `OPM_WS`, `OPM_SRC_*`, `OPM_SRC_WORKTREE`, `OPM_VERSIONS` and `OPM_BUILD_REFS`; `Taskfile.yml` loses `versions:prepare`, `versions:check`, `versions:fetch` and `lint:sources`, and `build`/`serve` require a current lock; `.github/workflows/site.yml` checks out only this repository in every job and drops the `build-manifest` artifact; `task build:edge` builds in manifest mode over its derived config (`add-edge-build` Decision 5) and `sources-main` checks out only this repository; `task ci:lint` green.
- [ ] 3.4 Real build: `task bundles:pull build` with no source repository on disk beside the checkout (an empty `OPM_WS`-less environment), every page present, every check green, the stamp without `sources` or `refs`.
- [ ] 3.5 `task check`, `task build`, `task test:site` and `task qa` green, then commit `refactor(site): retire the git source pipeline`.

## 4. Retire the shell lint and land the docs (GATED: G3.4)

- [ ] 4.1 Delete `site/scripts/lint-sources.sh`, `site/tests/lint/` and the shell-lint half of `test-site.sh`; replace the dialect contract copy in `openspec/changes/deploy-site/orchestration.md` with a pointer to docs-kit C11.
- [ ] 4.2 Land the durable decisions of design.md: `AGENTS.md` (Purpose; Repository Rules: the source lint rule rewritten, the network list; Site versions rewritten around `bundles.cue` and the reduced `versions.conf`; Environment Notes: "Source repositories" and "Git dates" rewritten; Build And Dev Commands; Repository Layout; Technology stack), `README.md` ("Sources", "Site versions", "Page dialect", "Contributing": `opm-docs serve`), `openspec/config.yaml` (context and Principles I, II, III), `CONSTITUTION.md` where it names the source lint or git-assembled sources.
- [ ] 4.3 `task check`, `task build` and `task test:site` green, then commit `refactor(site): retire the shell dialect lint`.
- [ ] 4.4 Verify with the `openspec-verify-change` skill (the diff touches only the files proposal.md's Impact names; every durable decision has landed), then archive with `openspec archive retire-git-pipeline --yes --skip-specs`, run `task openspec:check`, and commit `chore(openspec): archive retire-git-pipeline` (the archive rides this section's PR).
