# Tasks: resolve-versions-from-release-lines

`<wt>` is `/var/home/emil/dev/open-platform-model/opmodel.dev/.claude/worktrees/resolve-versions-from-release-lines` on branch `feat/resolve-versions-from-release-lines` (orchestration.md section 7, step 2). `WS` is `/var/home/emil/dev/open-platform-model`. `<scratch>` is your scratch directory, outside every repo.

There are three implementation sections, then the worker protocol. Section 1 is a spike: it proves the resolution on the real tags and writes "finding 1" to "finding 3" into design.md before anything is built on them. If a finding breaks a decision, stop and report it under `deviations`.

**Rules for this change**, on top of orchestration.md section 1:
- Builds read the supervisor's `site-src` worktrees, so prefix every `build`, `ci`, `qa` and `versions:*` command with `OPM_SRC_WORKTREE=site-src`. Never build against the owner's main checkouts. Never change a `site-src` worktree.
- Fetching the six source repositories is allowed, always as `git -C WS/<repo> fetch --no-write-fetch-head --no-prune --no-prune-tags --no-tags origin '+refs/heads/*:refs/remotes/origin/*' 'refs/tags/*:refs/tags/*'` (design.md decision 4): it adds tags and moves remote-tracking refs only, whatever the git config. Never `--force`, `--prune`, `--prune-tags` or a plain `--tags` fetch.
- Never create, move or delete a tag or a branch in a real repository (workspace `AGENTS.md`, "Release Tags Are Immutable"). The fixture repositories under `site/.check/versions-test/` and the spike's scratch repositories are test data.
- Nothing here needs `task serve` or `task preview`, and no port 4321 or 1313 is ever bound.

Gates, run on the whole worktree at every section end, as each section's last task lists them: `task -d <wt> check`; `OPM_SRC_WORKTREE=site-src task -d <wt> ci` (which runs `versions:test`); `OPM_SRC_WORKTREE=site-src task -d <wt> qa` when the footer changes (section 3); `task -d <wt> ci:lint` when the workflow changes (section 3); `git -C <wt> diff --check`.

## 1. Spike: prove line resolution against the real tags (design.md findings)

- [ ] 1.1 Preconditions. `git -C <wt> merge-base --is-ancestor 0f3a19c origin/main` succeeds. The six `site-src` worktrees exist (orchestration.md section 5). Fetch the six source repositories with the command in the rules above. Record whether `deploy-site` has merged (`git -C <wt> ls-tree -d --name-only origin/main openspec/changes/archive/`). If it has, merge `origin/main` into this branch before section 3 (orchestration.md section 7, step 7): resolve the conflicts in README "Summary and artifacts" and around the `build-stamp` upload in `site.yml` (design.md, Risks), drop this change's edits to "GitHub Pages (interim)", which deploy-site deleted, and run the section-3 gates after the merge. Verify: each fetch exits 0 and prints no "would clobber existing tag" line. If one does, stop and report: a tag moved upstream.
- [ ] 1.2 Finding 1: the resolution table on the real repositories. In a scratch directory outside WS, write a throwaway POSIX sh script: the two line regexes and `semver_max` of design.md decision 3, `docs_source` of decision 2 (with `X.Y` the minor of the named release, and rule 3 at that release's own commit), and the pin reads `resolve-versions.sh` already does (`git show <ref>:go.mod`, `PinnedOperatorVersion`, `DefaultSchemaModule`). Run it read-only against the six `site-src` roots (`WS/<repo>/.claude/worktrees/site-src`) for `cli-line = v1.0` and `catalog-line = opm-v4`. For each repository, print the ref, the `docs` value, the SHA, the floor check (`git merge-base --is-ancestor <floor> <sha>`, floors from `<wt>/site/versions.conf`), `docs/site` at the SHA (`git ls-tree -d`), and for core and catalog_opm the containment of the named release and the floor at it. Verify: every row passes, and the table equals the 2026-10-01 snapshot in proposal.md (Before / After), or differs only by a newer tag or head, recorded with its SHA.
- [ ] 1.3 Finding 1, continued: the order. Feed `semver_max` every tag of each line in use (cli `v1.0`, library `v1.0`, opm-operator `v1.0`, core `v2.0`, the catalog major `opm-v4` and its minor `opm-v4.4`), plus the synthetic list `v1.0.0-beta.2 v1.0.0-beta.10 v1.0.0-beta.3 v1.0.0-rc.1 v1.0.0 v1.0.1-beta.1 v1.50.0` under the `v1.0` regex. Verify: on the real lists it agrees with `git -C <root> -c versionsort.suffix=- tag -l --sort=-v:refname` (filtered by the same regex, first line). On the synthetic list it prints `v1.0.1-beta.1`, and `v1.0.0` once `v1.0.1-beta.1` is removed.
- [ ] 1.4 Finding 2: refs from a worktree. From each `site-src` root, run `git rev-parse --is-shallow-repository`, `git rev-parse --verify refs/remotes/origin/main` and `git tag -l --merged refs/remotes/origin/main`. Compare with the same commands on `WS/<repo>`. Verify: `false`, the same SHA and the same tag list in both places (worktrees share tags and remote-tracking refs, design.md decision 4). Record any difference as a finding against decision 4 and stop.
- [ ] 1.5 Finding 3: the fixture shape and the fetch flags, in a scratch directory outside WS, from a scratch script:
  - make two throwaway repositories, `up` (`git init -b main`, two commits, a tag) and `git clone up line`, plus a linked worktree `git -C line worktree add --detach ../wt`;
  - in `line`, create a local-only tag; in `up`, add a tag and a branch `release/v4.2` with one commit, made with `git switch -c`, then `git switch main`;
  - from `wt`, run the decision 4 fetch command with `GIT_CONFIG_COUNT=2`, `GIT_CONFIG_KEY_0=fetch.prune`, `GIT_CONFIG_VALUE_0=true`, `GIT_CONFIG_KEY_1=fetch.pruneTags`, `GIT_CONFIG_VALUE_1=true`;
  - then create a local tag `v9.0.0` in `line` and, after a new commit, a tag `v9.0.0` in `up` (two creations, no tag is moved), add `+refs/tags/*:refs/tags/*` to `line`'s `remote.origin.fetch`, and run the fetch command again.

  Verify: the first fetch exits 0, `line` gains the tag and `refs/remotes/origin/release/v4.2`, the local-only tag survives, and no `FETCH_HEAD` appears in `line/.git/` or `line/.git/worktrees/wt/`. The second fetch exits 1 with "would clobber existing tag", `line`'s `v9.0.0` is unchanged, and its `origin/main` equals `up`'s `main`. `git clone --depth 1 file://<scratch>/up shallow` reports `true` for `--is-shallow-repository`. None of these commands is refused by the session's hooks. Delete the scratch directory.
- [ ] 1.6 Write findings 1-3 into design.md as `### Spike findings (task 1.2-1.5)` under "Research & Decisions": the table with full SHAs and the date, the order results, the worktree results, and the fixture-shape result. If a finding contradicts a decision, stop and report it under `deviations` (orchestration.md section 7, step 5) before section 2.
- [ ] 1.7 `task -d <wt> check` and `git -C <wt> diff --check` green. Stage `openspec/changes/resolve-versions-from-release-lines/design.md` and `openspec/changes/resolve-versions-from-release-lines/tasks.md`, then commit `docs(openspec): record the release-line resolution spike`.

## 2. Resolve line versions (build scripts, Taskfile, resolver tests)

- [ ] 2.1 `site/scripts/resolve-versions.sh`, grammar (design.md decision 1). Precondition: the owner's answer to the blocking catalog-line question in design.md Open Questions, as the supervisor recorded it (in the launch message or in design.md). With no answer recorded, stop and report it under `questions`. If the answer is a minor line, stop and report it under `deviations` before writing the grammar. Then:
  - add `version.cli-line` and `version.catalog-line` to the key whitelist and to the at-most-once loop;
  - kind by keys: `source` makes `main`, `cli-line` makes `line`, otherwise `anchored`;
  - a line version requires both keys and excludes `source`, `cli`, `catalog` and `opm`; `source = main` excludes both line keys; an anchored version excludes `catalog-line`; `cli` is required only for `anchored`; each exclusion is a named error;
  - `cli-line` must match `^v[0-9]+\.[0-9]+$` and `catalog-line` `^opm-v[0-9]+$` (a minor or a `k8s-v` line is a named error);
  - overrides keep their rules (never cli, the reason required);
  - refuse `OPM_VERSIONS_MANIFEST` when it resolves to `site/.versions/frozen.conf`, by path and before reading it (decision 6);
  - rewrite the header comment and the usage block for three kinds, `--fetch` and `--freeze`; the header states that line mode assumes `origin` is the upstream repository (decision 4).

  Verify: `test-resolve.sh` case `line-grammar` (task 2.8).
- [ ] 2.2 Helpers (design.md decisions 2-4), with comments:
  - `semver_max PREFIX` in awk (SemVer 2.0.0 §11; the comment says why never `sort -V` or plain `--sort=-v:refname`);
  - `line_tags ROOT PREFIX LINE`, where `LINE` is `X.Y` (a minor) or `X` (a major), with the two regexes of decision 3;
  - `newest_in_line`;
  - `main_head ROOT` (`refs/remotes/origin/main`);
  - `docs_source REPO PREFIX X.Y REF`: rules 1-3, returning `docs`, `sha` and the rule text; rule 3 returns the commit of `REF`, the release the stamp names.

  For line versions only, the root checks: not shallow, and `refs/remotes/origin/main` present, each a named error (decision 6). The resolver itself still never fetches.
- [ ] 2.3 The line resolution in the version loop:
  - cli is the newest tag in `cli-line`, then `resolve_pins`;
  - core keeps its pinned version as `ref` and takes its tree from `docs_source core "" <X.Y of the pin> <the pin>`;
  - catalog_opm is the newest tag of the `catalog-line` major as `ref`, its tree from `docs_source catalog_opm opm- <X.Y of that tag> <that tag>`;
  - opm is `main` at `main_head`;
  - an override (decision 1) replaces a row: `docs` is `tag` or `sha`, no `docs_source` and no containment check, core still read at the effective library. The replaced row is still resolved and checked without reporting its errors. `how` is `override:<reason>; replaces <ref> (<how>)` or `override:<reason>; replaces no pin`. The run fails with the "no longer needed" error once the replaced row passes every check. Anchored overrides are unchanged.

  Every row goes through `check_ref` with a non-`main` kind. For core and catalog_opm, also check the floor at the commit of the release the stamp names, and, under rules 1 and 2, its containment in the docs SHA. Line rows carry kind `line`, the `how` texts of decision 2, and error text naming the rule (decision 6), with no `@` anywhere. Append the tenth column `docs` to the header and to every row of every kind (`worktree`, `tag`, `sha`, `main`, `release/...`), and write `# site<TAB><opmodel.dev HEAD>` after the header in both `--check` and write mode. Verify: cases `line`, `line-override`, `line-override-stale`, `line-core-pre-floor`, `line-branch`, `line-newer-tag`, `line-catalog-major`, `line-contain`, `line-pre-floor` and `line-no-tag`, plus every existing case unchanged.
- [ ] 2.4 Modes:
  - `--fetch`: the decision 4 command (explicit refspecs, the tag one without `+`; `--no-write-fetch-head --no-prune --no-prune-tags --no-tags`) for the six roots, resolved as for a build; it fetches every root, then exits 1 naming each root whose fetch failed;
  - `--freeze`: print the frozen manifest of design.md decision 10 (the opmodel.dev commit in the header, `docs = tag` rows by tag name, every other row by SHA), writing nothing;
  - write mode also writes `site/.versions/frozen.conf` (via `.tmp` and `mv`);
  - the failure trap removes `frozen.conf` with `versions.tsv`, and explicit mode removes both.

  Verify: cases `line-stale`, `line-branch`, `line-freeze`, `line-fetch-prune` and `line-fetch-clobber`. Then touch a marker file in `<scratch>` and run `sh <wt>/site/scripts/resolve-versions.sh --fetch` once with `OPM_SRC_WORKTREE=site-src`. It exits 0 and creates no file under `<wt>`, and for each of the six repositories `find WS/<repo>/.git/worktrees/site-src -newer <marker>` prints nothing (no `FETCH_HEAD` there).
- [ ] 2.5 `site/scripts/materialise.sh`: archive every version whose kind is not `main` (`[ "$kind" != main ]`, decision 7), and update its header comment. Comment-only edits in `site/scripts/build-all.sh`, `site/scripts/serve.sh` and `site/scripts/gen-mounts.sh` name the third kind. Verify: `git -C <wt> diff -- site/scripts/build-all.sh site/scripts/serve.sh site/scripts/gen-mounts.sh` changes comments only.
- [ ] 2.6 `site/scripts/gen-stamp.sh`: write `"docs"` per ref when column 10 is set, and `"site"` from the `# site` line of `versions.tsv` when it is there. Update the header comment: kinds, `docs`, `site`, and `sources` = the roots' checked-out `HEAD`, not the record for anchored or line versions. Verify: case `line-stamp`, and the fixture builds of `task test:site` still pass (explicit rows have no column 10 and no `site`).
- [ ] 2.7 `Taskfile.yml`: add `versions:fetch` (`sh site/scripts/resolve-versions.sh --fetch`, `env: *versions-env`), update the `versions:prepare` and `versions:check` descriptions for line versions, and change the `serve` description so it no longer says "reading the sources in place" (decision 12). Verify: `task -d <wt> --list` shows `versions:fetch` with its description, and `grep -n 'in place' <wt>/Taskfile.yml` prints nothing, or only text naming `OPM_VERSIONS=v1.0=/src` live editing.
- [ ] 2.8 `site/tests/versions/test-resolve.sh`, the line fixtures and cases of design.md decision 11:
  - the upstream additions (cli `v1.5.0-beta.2`, `v1.5.0-beta.10`, `v1.5.0-beta.3`, `v1.50.0`, `v1.6.0`; library `v2.2.0-oldcore`; core `v4.2.0-rc.0` and its docs commit after `v4.2.0`; catalog_opm `opm-v0.9.0` and its docs commit after `opm-v1.1.0`), made before any case runs;
  - the line roots as `git clone`s under `repos/line/`;
  - after every existing case, the state-A cases (`line`, `line-override`, `line-override-stale`, `line-core-pre-floor`, `line-pre-floor`, `line-no-tag`, `line-grammar`, `line-shallow` with a `file://` clone, `line-no-origin`);
  - then states B to E in order, each case in the state design.md decision 11 names: B `line-stale`, `line-branch`, `line-stamp` (gen-stamp.sh on the host with `SITE_DIR` under `repos/`) and `line-freeze`; C `line-newer-tag`; D `line-catalog-major`; E `line-contain`;
  - then `line-fetch-prune` and `line-fetch-clobber`.

  Every expected SHA comes from `git rev-parse` on the fixtures, never a literal, and every failing case asserts that the message names the version, the repository and the rule. Every fixture tag is created once and never moved. Update the header comment. Verify: `sh <wt>/site/tests/versions/test-resolve.sh` with `OPM_SRC_WORKTREE=site-src` prints `ok` for every case, existing ones included, and writes nothing outside `site/.check/versions-test/`.
- [ ] 2.9 The case `real-line` (decision 11): a manifest under `repos/manifests/` with the real floors, `cli-line = v1.0` and `catalog-line = opm-v4`, resolved with `--check` against the caller's roots. Assert:
  - exit 0;
  - the cli ref equals git's own order;
  - library, core and opm-operator equal `--pins <that ref>`;
  - the catalog ref equals git's order for `opm-v4.*`;
  - every `docs` is `tag`, `main` or `release/...`.

  Keep `real-pins` and `real-pre-floor`. Verify: it passes with `OPM_SRC_WORKTREE=site-src`, and its rows match finding 1.
- [ ] 2.10 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci` (its `versions:test` runs the new cases; `site/versions.conf` and `two-versions.conf` still use `source = main` for v1.0, so the site build is unchanged) and `git -C <wt> diff --check` green. Stage `site/scripts/resolve-versions.sh`, `site/scripts/materialise.sh`, `site/scripts/gen-stamp.sh`, `site/scripts/build-all.sh`, `site/scripts/serve.sh`, `site/scripts/gen-mounts.sh`, `site/tests/versions/test-resolve.sh`, `Taskfile.yml` and `openspec/changes/resolve-versions-from-release-lines/tasks.md`, then commit `feat(site): resolve site versions from release lines`.

## 3. Build v1.0 from its release lines (site config, layouts, two-version test, CI, docs)

- [ ] 3.1 `site/versions.conf`: move `v1.0` to `cli-line = v1.0` and `catalog-line = opm-v4` (proposal.md, After). Rewrite the header comment for three kinds and say that the owner reversed the fixed-anchor rule on 2026-10-01; the floors stay. Verify: `OPM_SRC_WORKTREE=site-src task -d <wt> versions:check` prints six `line` rows equal to finding 1, or differing only by a newer tag or head, recorded with its SHA (as in 1.2).
- [ ] 3.2 Layouts (design.md decision 8):
  - `site/layouts/_partials/opm/build-stamp.html`: `anchored` and `line` both show "documents ..."; a line row adds the docs suffix for branch-sourced trees;
  - `site/layouts/_partials/opm/source.html`: for `line`, `viewURL` is `blob/<sha>/...`, `refText` follows decision 8, and `editURL` uses `edit/<docs>` when `docs` is `main` or `release/...`;
  - `site/layouts/_partials/components/last-updated.html`: the edit link shows on the default version, or when the kind is neither `anchored` nor `line`.

  Update each file's header comment. No published text carries an enhancement reference or an `@`. Verify: `git -C <wt> diff origin/main -- site/overrides.sha256` is empty, and `OPM_SRC_WORKTREE=site-src task -d <wt> build` is green, including the drift guard.
- [ ] 3.3 `site/tests/versions/two-versions.conf`: move `v1.0` to line mode (`cli-line = v1.0`, `catalog-line = opm-v4`); `v0.9` stays anchored. Rewrite its header: it no longer says that no repository has a tag cut after its merge, and it gives v0.9's real reason (anchored at the page-dialect merges, the oldest refs that build, with the pins there overridden). `site/tests/versions/check-two-versions.sh`, reading every expected ref and SHA from `site/.versions/versions.tsv`:
  - the v1.0 stamp links all six v1.0 SHAs;
  - v1.0 "View source" links carry `blob/<sha>/docs/site/` per repository;
  - v1.0 edit links follow decision 8;
  - the "pages added after the test SHAs" assertion and the `write-a-blueprint` check compare v0.9 against v1.0's resolved SHA per repository instead of the root's `HEAD`;
  - v1.0's archive per repository equals `git ls-tree` at its resolved SHA.

  Verify: `OPM_SRC_WORKTREE=site-src task -d <wt> versions:test` passes and prints the new assertions as `ok`.
- [ ] 3.4 `.github/workflows/site.yml` (design.md decision 9):
  - a comment on the first source checkout: `fetch-depth: 0` brings every tag and every branch as `refs/remotes/origin/*`, which the version resolver reads;
  - the cron comment: the nightly run publishes newly tagged releases and release-branch docs fixes;
  - the Summary step lists every version's refs from `.versions`, as decision 9 shows;
  - a new `upload-artifact` step, `build-manifest`, uploads `opmodel.dev/site/.versions/frozen.conf` alone with `include-hidden-files: true`, `if-no-files-found: error` and `retention-days: 90`, right after `build-stamp`; the `build-stamp` step is unchanged, so `build-stamp.json` stays at its artifact's root;
  - no checkout, trigger, permission or pin changes.

  Verify: `task -d <wt> ci:lint` green, and `git -C <wt> diff origin/main -- .github/workflows/site.yml` leaves the `build-stamp` step's `path:` unchanged. Run the Summary step's `jq` command on a local `site/public/build-stamp.json` and check that it prints six v1.0 rows with 12-hex commit links.
- [ ] 3.5 README.md (durable decisions 1-7):
  - Overview (line 32 today): `v1.0` (beta) is built from its release lines, not "from each source repository's current checkout";
  - Quick Start (`task serve`, "reads the sources in place"), the "Tasks" block (add `task versions:fetch`; `task serve`'s comment) and the dev-loop paragraph that says `task serve` reads every `docs/site/` in place: a line version serves archives, and live editing is `OPM_VERSIONS=v1.0=/src task serve`;
  - rewrite "Site versions" for three kinds:
    - the line rules table, with the catalog line a major;
    - overrides in a line version (only for a failing row; the "no longer needed" error);
    - the fetch rule and `task versions:fetch`, and that a local build needs `origin` to be the upstream repository;
    - the record (`versions.tsv`, `build-stamp.json` with `site`, the footer, the summary) and rebuilding from `frozen.conf` (the `build-manifest` artifact; check out the recorded opmodel.dev commit; copy the file out of `site/.versions/` first);
    - the reversal sentence ("Until 2026-10-01 ... ; the owner reversed this on 2026-10-01 ...");
    - moving to a new catalog major or cli line by commit;
    - that a library or opm-operator docs fix reaches the site only through a cli release that bumps its pin (unless the owner answers otherwise, design.md Open Questions);
    - "When the resolution fails": the recovery per failure kind of design.md Risks;
  - replace the beta-tags edit example with the line manifest;
  - "CI": the "Checkout layout", "Summary and artifacts" (the summary's resolved refs; the `build-manifest` artifact) and "Source repositories" bullets (the nightly run is the mechanism; no dispatch; `gh workflow run Site --ref main`; a failing upstream release turns every run red until recovered);
  - in "GitHub Pages (interim)", the `build-stamp.json` curl comment names the resolved refs. Skip this edit if `deploy-site` has merged (task 1.1), because that subsection is then gone;
  - "Implementation Status": `[x]` v1.0 follows its release lines.

  Verify: `grep -n -e 'cli-line' -e 'catalog-line = opm-v4' -e 'versions:fetch' -e 'frozen.conf' -e 'build-manifest' -e '2026-10-01' -e 'OPM_VERSIONS=v1.0=/src' -e 'no longer needed' <wt>/README.md` hits each term. `grep -n 'never a moving line' <wt>/README.md` hits only the reversal sentence. `grep -n -e 'in place' -e 'current checkout' <wt>/README.md` hits only text that names `OPM_VERSIONS=v1.0=/src` live editing or `source = main`.
- [ ] 3.6 AGENTS.md (durable decisions 1-6):
  - under "Site versions": rewrite "One manifest" (three kinds; the reversal), "Where pins come from" (line mode, the catalog major, the docs rules, overrides only for a failing row, remote-tracking refs only, `origin` assumed) and "Dialect floors" (also at the release the stamp names; containment; naming the rule);
  - in "Git runs on the host", archives for every non-`main` kind, `frozen.conf`, and the fetch flags;
  - the "Files" bullet adds the line cases;
  - "Durable decisions" URL layout (line 110 today): v1.0 is built from its release lines, not "from each source repo's current checkout";
  - "Build And Dev Commands": `task versions:fetch`, the `versions:prepare` wording, and the `task serve` line: a line version serves archives, and `OPM_VERSIONS=v1.0=/src task serve` is live editing.

  Verify: `grep -n -e 'cli-line' -e 'versions:fetch' -e 'refs/remotes/origin' -e '2026-10-01' <wt>/AGENTS.md` hits each term. No line still says `source = main` is allowed "only until" beta tags exist. `grep -n -e 'in place' -e 'current checkout' <wt>/AGENTS.md` hits only text that names `OPM_VERSIONS=v1.0=/src` live editing or `source = main`.
- [ ] 3.7 The built site. Run `OPM_SRC_WORKTREE=site-src OPM_REQUIRE_DATES=1 task -d <wt> build`. Verify:
  - green;
  - `site/public/v1.0/docs/index.html` holds a footer naming cli, library, core, catalog, operator and opm, with six `commit/<sha>` links equal to `site/.versions/versions.tsv`;
  - a cli page and a core page each carry "View source" at `blob/<sha>/`;
  - `site/public/build-stamp.json` has `"kind": "line"`, a `docs` field per ref, and `"site"` equal to `git -C <wt> rev-parse HEAD`;
  - `OPM_SRC_WORKTREE=site-src OPM_VERSIONS=v1.0=/src task -d <wt> build` (explicit mode, the live-edit path) is green;
  - the round trip, last: rerun the first build of this task (the explicit-mode build removed `versions.tsv` and `frozen.conf`), copy `site/.versions/frozen.conf` and `site/public/build-stamp.json` to `<scratch>`, then run `OPM_SRC_WORKTREE=site-src OPM_REQUIRE_DATES=1 OPM_VERSIONS_MANIFEST=<scratch>/frozen.conf task -d <wt> build`. It is green, its `build-stamp.json` names the same six SHAs per repository and the same `site` as the copy, with kind `anchored`, and cli, library and opm-operator carry the same tag names. `OPM_VERSIONS_MANIFEST=<wt>/site/.versions/frozen.conf task -d <wt> versions:check` fails with the "copy it first" error.
- [ ] 3.8 `OPM_SRC_WORKTREE=site-src task -d <wt> qa` green. Read `site/.shots/v1.0_docs/stamp-*.png` in all six variants: the longer footer wraps cleanly at phone width, links stay legible in light and dark, and nothing overlaps.
- [ ] 3.9 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci`, `OPM_SRC_WORKTREE=site-src task -d <wt> qa` (screenshots read in 3.8), `task -d <wt> ci:lint` and `git -C <wt> diff --check` green, run after any merge of `origin/main` into this branch (task 1.1), never before it. Stage `site/versions.conf`, `site/layouts/_partials/opm/build-stamp.html`, `site/layouts/_partials/opm/source.html`, `site/layouts/_partials/components/last-updated.html`, `site/tests/versions/two-versions.conf`, `site/tests/versions/check-two-versions.sh`, `.github/workflows/site.yml`, `README.md`, `AGENTS.md` and `openspec/changes/resolve-versions-from-release-lines/tasks.md`, then commit `feat(site): build v1.0 from its release lines`.

## 4. Verify, report and archive (orchestration.md section 7, steps 6 and 7)

- [ ] 4.1 Read `<wt>/.claude/skills/openspec-verify-change/SKILL.md` and follow it for `resolve-versions-from-release-lines`, running each `openspec` command as `cd <wt> && openspec ...`, never through the root `/opsx:verify` router. Also verify:
  - `git -C <wt> diff --stat origin/main` touches only the proposal's "Touches" list;
  - `find <wt>/openspec/changes -name enhancement.yaml` prints nothing;
  - every durable decision in design.md marked for `AGENTS.md` or `README.md` is there (tasks 3.5 and 3.6);
  - `git -C <wt> diff origin/main -- site/layouts | grep -n '^+.*@'` prints nothing, and a read of every `how` and error string added to `resolve-versions.sh` finds no `@` (a branch ref prints as `main f5c4463`).
- [ ] 4.2 Report to the supervisor with the block in orchestration.md section 7, step 6:
  - `sections: 3/3`, counting the implementation sections;
  - `surface` is design.md's "Interface" subsection;
  - `deviations` is whatever the spike changed;
  - `gates` lists every command of 1.7, 2.10 and 3.9;
  - `follow-ups` lists the workspace `AGENTS.md` rewording, the post-GA edit targets, and the dispatch;
  - `questions` lists design.md's Open Questions that are still open.

  Then STOP and wait.
- [ ] 4.3 Only on the supervisor's go: tick this box, then run `cd <wt> && openspec archive resolve-versions-from-release-lines --yes --skip-specs`, then `cd <wt> && openspec validate --all --strict --no-interactive`. When both are green, stage `openspec/changes/archive/<date>-resolve-versions-from-release-lines` and the removed `openspec/changes/resolve-versions-from-release-lines` by explicit path, and commit `chore(openspec): archive resolve-versions-from-release-lines`. Pushing and the pull request follow orchestration.md section 7, step 7, outside this file.
