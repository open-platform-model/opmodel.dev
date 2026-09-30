Run every task from your worktree `<wt>` (`task -d <wt> ...`). Every build and every `versions:*` task runs against the supervisor's `site-src` worktrees, so prefix it with `OPM_SRC_WORKTREE=site-src` (`orchestration.md` section 5). If you need `task serve` or `task preview`, use `SITE_PORT=1314`.

The two-version manifest `site/tests/versions/two-versions.conf` (task 2.4) is the only other manifest. You select it with `OPM_VERSIONS_MANIFEST=site/tests/versions/two-versions.conf`. After any two-version build into `site/public/`, rebuild with the real manifest before you run a section's gates.

## 1. Spike, the manifest and the resolver

- [x] 1.1 Read A's merged `main` against design.md Context and Decisions 3, 5, 6, 7, 10 and 12. Confirm or refute each of these:
  - `build` and `serve` run `versions:prepare` first;
  - `build`, `serve` and `test:site` leave `OPM_VERSIONS` unset unless a caller sets it, and whether a host `OPM_VERSIONS` reaches the container;
  - which Taskfile variables hold the six host source roots and `OPM_WS`;
  - whether `site/scripts/build-all.sh` takes a destination argument and a check-output argument;
  - where `build-all.sh` takes the default version from (the prototype read `defaultContentVersion` from `hugo.toml` with `sed`), and which file writes `_redirects`;
  - that `custom/head-end.html` publishes the `/latest/` stubs through `.Site.Version.IsDefault` and hard-codes no version name;
  - that `gen-lastmod.sh` keys site-owned pages as `opmodel.dev/site/content/<path>`, counts misses by walking the mounted pages, and gets `OPM_REQUIRE_DATES` from the host environment;
  - every place A runs or documents a fixture-workspace build through `task build` or `task serve` (not `test-site.sh`, which sets `OPM_VERSIONS` itself). From section 1 on, each needs `OPM_VERSIONS=v1.0=/src` (design.md Decision 3);
  - that A keeps the "v1.0 (beta)" label in `[[params.opm.versions]]`;
  - whether A's ignore and `clean` rules cover `site/config/<env>/`.

  Write the six S merge SHAs the supervisor handed over into design.md Decision 4. Write the six test SHAs into design.md Decision 11: the S merge SHAs, unless A's merge needed source fixes after the S merges. In that case use the buildable post-S SHAs the supervisor names, for example the `site-src` `HEAD`s that A merged against, and ask for them if none were handed over. Anything that contradicts design.md is a deviation: stop and report it (`orchestration.md` section 7, step 5). A fixture build that A runs or documents without `OPM_VERSIONS` is a deviation too: report where it is, and the supervisor rules on the edit.
- [x] 1.2 Spike, on scratch edits that you revert before 1.7. The question is Decision 7: which form of the generated versions config Hugo 0.167.0 honours.
  - Build two versions in the image: `v1.0` from `/src`, and `v0.9` from a copy of A's fixture workspace placed under `site/.versions/v0.9/`.
  - Try the three candidate forms, in both `build` and `serve` (`SITE_PORT=1314`, one SIGINT).
  - A form passes when both `/v1.0/` and `/v0.9/` publish every expected page (the Q2 check is green) and `/latest/` points at `v1.0`. That also shows whether Hugo keeps pages mounted from under the dot-directory `site/.versions/`.

  Record the chosen form and that finding in design.md "Research & Decisions" ("Hugo's versions config").
- [x] 1.3 Add `site/versions.conf` in the design.md Decision 1 form: a header comment, the six `[repo "..."] floor` lines from 1.1, and `v1.0` with `source = main` and the O3 comment.
- [x] 1.4 Add `site/scripts/resolve-versions.sh`: POSIX `sh`, `git` and `awk`, run on the host, with a usage header. It carries:
  - the grammar checks from Decision 1, including the character rule for `label` and the override reason;
  - the root checks from Decision 3, run first, naming `OPM_SRC_<REPO>` (and `OPM_VERSIONS` for a root that is not a git top level);
  - the resolution and three checks from Decision 3, reporting every failure as `<version>: <repo> <ref>: <reason>` and exiting 1;
  - the default mode, which writes `site/.versions/versions.tsv` in the Decision 5 format, and skips when `OPM_VERSIONS` is set;
  - `--check`, which writes nothing;
  - `--pins <cli-ref>`;
  - `OPM_VERSIONS_MANIFEST`.

  Verify: `OPM_SRC_WORKTREE=site-src sh site/scripts/resolve-versions.sh --check` prints six `v1.0` rows with `how` = `head`, each SHA equal to `git -C WS/<repo>/.claude/worktrees/site-src rev-parse HEAD`.
- [x] 1.5 Add `site/tests/versions/test-resolve.sh`, with every Decision 11 resolver case:
  - fixture repositories created under `site/.check/versions-test/repos/`, the only directory the test removes and recreates;
  - the two root cases: a missing root, and a fixture root that sits inside another repository;
  - the resolver-only test at cli `v1.0.0-alpha.25` (library `v1.0.0-alpha.35`, core `v2.0.0-alpha.12`, opm-operator `v1.0.0-alpha.19`);
  - the negative `--check` anchored at cli `v1.0.0-alpha.25`, whose output must name `cli v1.0.0-alpha.25` (older than the floor) and `opm-operator v1.0.0-alpha.19` (no `docs/site`).

  Verify: it prints one line per case and exits 0. Change one expected pin on a scratch edit and it exits 1. Restore it.
- [x] 1.6 `Taskfile.yml`, `versions:*` tasks only (Decision 12).
  - Add `versions:check` and `versions:test`, passing A's host source roots and `OPM_WS`.
  - Set the body of `versions:prepare` to `resolve-versions.sh --check` for now, skipped when `OPM_VERSIONS` is set. Section 2 switches it to writing and materialising.

  Verify:
  - `OPM_SRC_WORKTREE=site-src task versions:check` passes;
  - `OPM_SRC_WORKTREE=site-src task build` still prints A's page count for `v1.0`;
  - `OPM_VERSIONS=v1.0=/src OPM_WS=<wt>/site/tests/fixtures/ws task build` passes, and the same build without `OPM_VERSIONS` fails before `docker run`, naming `OPM_SRC_<REPO>` and `OPM_VERSIONS`.

  The hand-written `[versions]` block stays in `hugo.toml` until section 2, which removes the duplicate.
- [x] 1.7 Revert the 1.2 scratch edits (`git -C <wt> status` shows only the files of 1.1 and 1.3-1.6). Then run the gates: `task check`, `OPM_SRC_WORKTREE=site-src task versions:test` and `OPM_SRC_WORKTREE=site-src task ci`. When all are green, commit `feat(site): resolve each version's source refs from a manifest`.

## 2. Materialise anchored versions and generate the versions config

- [ ] 2.1 Add `site/scripts/materialise.sh` (design.md Decision 6). For each anchored version it writes `git archive` trees under `site/.versions/<v>/<repo>/docs/site`, with the `.sha` skip marker. It removes version directories that are not in the manifest, and only inside `site/.versions/`. For every version, `main` included, it writes `site/.versions/<v>/lastmod.tsv` with both kinds of row: source pages (`<repo>/docs/site/<path>`, from `git -C <root> log -1 --format=%cI <sha> -- docs/site/<path>`) and site-owned pages (`opmodel.dev/site/content/<path>`, from the opmodel.dev checkout's `HEAD`). With `OPM_VERSIONS` set it does nothing.
- [ ] 2.2 Set the body of `versions:prepare` to `resolve-versions.sh` (which writes `versions.tsv`) followed by `materialise.sh`. With `OPM_VERSIONS` set, it skips both steps and removes any stale `site/.versions/versions.tsv`.
- [ ] 2.3 Wire the resolved file into the container side (Decisions 5, 7, 8 and 10):
  - `build-all.sh` and `serve.sh` load the version list from `versions.tsv`. They fall back to an explicit `OPM_VERSIONS`, and then to A's default.
  - `gen-mounts.sh` writes the versions config in the form 1.2 chose.
  - `gen-lastmod.sh`, in manifest mode, runs no `git`: it reads the `lastmod.tsv` files, still walks every source and site-owned page, and counts a page with no row as a miss (check 13). In explicit mode it keeps A's container-side `git log`.
  - `check-pages.sh` and the Pagefind, `_redirects`, root `index.html` and root `404.html` steps iterate the list, and take the default version from it, never from `hugo.toml`.
  - The `/latest/` stubs need no edit: A's `custom/head-end.html` follows the generated `defaultContentVersion` (design.md Decision 10).
  - Remove `[versions]`, `defaultContentVersion` and A's `[[params.opm.versions]]` entry from `site/config/_default/hugo.toml`. The generated config now carries all three.
  - `data/opm/build.json` and `public/build-stamp.json` gain the `versions` key, and keep A's keys.
  - Add one ignore line for the generated config only if A's rules miss it.
  - Adapt the fixture call sites or label assertions of A's `test:site` harness (`site/scripts/test-site.sh`) only if 1.1 found them in conflict. In explicit mode the label is the version name.

  Verify with `OPM_SRC_WORKTREE=site-src task build`:
  - `site/public/build-stamp.json` has `versions.v1.0` with six refs whose `how` is `head`, and A's keys unchanged;
  - `find site/public/v1.0 -name index.html | sort` equals section 1's build;
  - `site/data/opm/lastmod.json` has dates for `v1.0` pages even in this worktree build, for source keys (`cli/docs/site/...`) and site-owned keys (`opmodel.dev/site/content/...`) alike;
  - `OPM_REQUIRE_DATES=1 OPM_SRC_WORKTREE=site-src task build` passes, which proves check 13 locally;
  - `OPM_VERSIONS=v1.0=/src OPM_WS=<wt>/site/tests/fixtures/ws task build` passes in explicit mode, and `task test:site` is green.
- [ ] 2.4 Add `site/tests/versions/two-versions.conf` (design.md Decision 11). It holds `v1.0` (`source = main`, default) and `v0.9` ("v0.9 (test)"), anchored at the cli test SHA with `catalog` and `opm` at the catalog_opm and opm test SHAs. Its overrides for library, core and opm-operator point at their test SHAs, each with the reason "test pins post-S SHAs, no post-S tag yet". The test SHAs are the ones 1.1 recorded in design.md Decision 11: the S merge SHAs, or the buildable post-S SHAs the supervisor named if A's merge needed source fixes after the S merges.

  Verify with `OPM_VERSIONS_MANIFEST=site/tests/versions/two-versions.conf OPM_SRC_WORKTREE=site-src task build`:
  - the build log shows the lint over `.versions/v0.9/<repo>/docs/site` for all six repositories;
  - Q2 is green for both versions;
  - `site/public/v0.9/` and `site/public/v1.0/` both hold a `pagefind/` directory;
  - `site/public/_redirects` points at `/v1.0/`;
  - `site/.versions/v0.9/cli/docs/site` lists exactly `git -C WS/cli/.claude/worktrees/site-src ls-tree -r --name-only <cli test SHA> docs/site`.

  Then rebuild with the real manifest. `site/public/v0.9/` and `site/.versions/v0.9/` must be gone.
- [ ] 2.5 Land the durable decisions (design.md "Durable decisions") in `README.md`, under a new `## Site versions` heading:
  - the manifest;
  - `source = main` until beta tags exist;
  - the edit that moves `v1.0` onto tags;
  - where pins come from, and overrides with reasons;
  - floors;
  - `task versions:check`;
  - `OPM_VERSIONS_MANIFEST`;
  - a fixture-workspace build runs with `OPM_VERSIONS=v1.0=/src`.
- [ ] 2.6 Land them in `AGENTS.md` too, under a new `## Site versions` heading of this change's own. Do not edit A's `## Durable decisions` section or its layout tree. The heading holds:
  - the manifest is the only list of versions, and nothing globs `v*/`;
  - pins come from `cli/go.mod`, library `DefaultSchemaModule` and cli `PinnedOperatorVersion`; catalog and opm are explicit; never `cli/hack/platform/`; an override needs a reason;
  - no ref older than its repository's floor builds;
  - in manifest mode every git date is computed on the host by `materialise.sh`;
  - the files this change adds: `site/versions.conf`, `site/scripts/{resolve-versions,materialise}.sh` and `site/tests/versions/`.

  Complete the header comment of `site/versions.conf` with the O3 and floor rules. Verify: `grep -n "^## Site versions" README.md AGENTS.md` hits both, and `git -C <wt> diff origin/main...HEAD -- AGENTS.md` changes no line outside that heading.
- [ ] 2.7 Run the gates: `task check`, `OPM_SRC_WORKTREE=site-src task versions:test`, `OPM_SRC_WORKTREE=site-src task ci`, `OPM_REQUIRE_DATES=1 OPM_SRC_WORKTREE=site-src task build`, and `task qa` (the label now comes from the manifest; read the header PNGs). When all are green, commit `feat(site): build tagged versions from git archives`.

## 3. Stamp, source links, version switch and outdated bar

- [ ] 3.1 `site/layouts/_partials/opm/build-stamp.html` (design.md Decision 8): an anchored version shows "Documents cli X, library L, core Y, catalog Z, operator W, opm <short SHA>", and a `main` version shows the short SHAs as A did. Verify:
  - on the real build, the footer of `/v1.0/docs/` shows the six `site-src` `HEAD` short SHAs;
  - on the two-version build, the footer of a `/v0.9/` page names the six test SHAs in short form.
- [ ] 3.2 Make the source links follow the resolved refs:
  - `site/layouts/_partials/opm/source.html` builds `viewURL` from the version's resolved ref for that repository;
  - `site/layouts/_partials/components/last-updated.html` follows the table in design.md Decision 8: "Edit this page" (`edit/main`) on a `source = main` version and on the default version; "View source at <ref>" on every anchored version, beside the edit link when that version is the default.

  Verify on the two-version build:
  - `site/public/v0.9/docs/start/what-is-opm/index.html` contains `blob/<opm test SHA>/docs/site/start/what-is-opm.md` and no "Edit this page" link;
  - `site/public/v1.0/docs/start/what-is-opm/index.html` contains `edit/main/docs/site/start/what-is-opm.md` and no "View source at" link.

  Then, on a scratch copy of `two-versions.conf` that moves `default = true` to `v0.9`, build once: the same `/v0.9/` page carries both `edit/main/...` and `blob/<opm test SHA>/...`. Delete the scratch copy and rebuild with the real manifest.
- [ ] 3.3 Update the version switch: `site/layouts/_partials/opm/version-switch.html`, `version-links.html` and `site/layouts/_partials/navbar-title.html` (the switch call only), plus `site/assets/css/opm/versions.css`.
  - With two or more versions, it lists the labels in weight order, marks the default and keeps the nearest-parent fallback.
  - With one version, it is unchanged from A.
  - `navbar-title.html` keeps A's class hooks `opm-brand`, `opm-title-long` and `opm-title-short`, which `add-brand-marks` (M) selects in `brand.css`.

  Verify: on the two-version build, `/v0.9/` and `/v1.0/` pages list "v1.0 (beta)" before "v0.9 (test)". On the real build, the header HTML of `/v1.0/docs/` equals section 2's.
- [ ] 3.4 `site/layouts/_partials/banner.html`: the outdated bar on every version that is not the default, worded as design.md Decision 9 says, with `data-pagefind-ignore="all"`. Verify: `grep -l opm-outdated` finds it in every HTML page under `site/public/v0.9/docs/` and in none under `site/public/v1.0/`.
- [ ] 3.5 Add a shots extra in `site/tests/browser/` for the open switch and for a page carrying the outdated bar. It runs only when `build-stamp.json` lists two or more versions.
- [ ] 3.6 Run `task qa` on the two-version build and read the PNGs: the open switch (light, dark, site/OS mismatch both ways, phone), the outdated bar, and the footer stamp. Then rebuild with the real manifest, run `task qa` again, and read the header and footer PNGs.
- [ ] 3.7 Run the gates: `task check`, `OPM_SRC_WORKTREE=site-src task versions:test`, `OPM_SRC_WORKTREE=site-src task ci`, `OPM_REQUIRE_DATES=1 OPM_SRC_WORKTREE=site-src task build`, and `task qa` on the real build with the PNGs read. When all are green, commit `feat(site): stamp each version with the refs it documents`.

## 4. N-version outputs and the two-version regression test

- [ ] 4.1 On the two-version build:
  - `site/public/robots.txt` names `/v1.0/sitemap.xml` and `/v0.9/sitemap.xml`;
  - each sitemap lists only its own version's URLs;
  - each version has its own `llms.txt` and `404.html`;
  - the root `404.html` is `v1.0`'s.

  Edit `site/layouts/robots.txt` or `site/layouts/sitemap.xml` only if one of these fails, and report the edit under `deviations`.
- [ ] 4.2 If A's `build-all.sh` has no destination argument, or no way to keep its `.check/` output apart, add both with unchanged defaults (`public`, `.check`). The two-version build then writes its site to `site/.check/versions-test/public/` and its `<v>/nav-order.txt` to `site/.check/versions-test/check/`, never `site/public/` or the real `site/.check/<v>/` (design.md Decision 11).
- [ ] 4.3 Add `site/tests/versions/check-two-versions.sh`, with every Decision 11 assertion. Its header comment says the test never writes `site/public/`. Extend `versions:test` to:
  1. run `versions:prepare` with the two-version manifest;
  2. build into `site/.check/versions-test/public/`, with the check output in `site/.check/versions-test/check/`;
  3. run the assertions;
  4. run `versions:prepare` with the real manifest again, which restores `site/.versions/`.

  Verify:
  - `OPM_SRC_WORKTREE=site-src task versions:test` passes;
  - `site/public/build-stamp.json` is byte-identical before and after it, and `site/.check/versions-test/repos/` survives the build;
  - on a scratch edit that drops the outdated bar, it fails, naming the assertion. Revert the scratch edit.
- [ ] 4.4 Only if the supervisor allowed it (design.md "Open Questions"): add one line to A's `test:site` that runs `versions:test`. Otherwise skip this task, and name the missing CI step under `follow-ups`.
- [ ] 4.5 Extend the search smoke test in `site/tests/browser/` to query every version listed in `build-stamp.json` `versions`, in its own test function beside A's. Verify: `task qa` on the two-version build searches both versions and passes. Then rebuild with the real manifest.
- [ ] 4.6 Run the gates: `task check`, `OPM_SRC_WORKTREE=site-src task versions:test`, `OPM_SRC_WORKTREE=site-src task ci`, `OPM_REQUIRE_DATES=1 OPM_SRC_WORKTREE=site-src task build`, and `task qa` on the real build with the PNGs read. When all are green, commit `test(site): build two tagged versions in the regression suite`.

## 5. Verify and hand off (orchestration.md section 7, steps 6 and 7)

- [ ] 5.1 Read `<wt>/.claude/skills/openspec-verify-change/SKILL.md` and follow it for `version-site-from-tags`, running every `openspec` command as `cd <wt> && openspec ...`. Confirm three things:
  - every durable decision marked for promotion is in `README.md` or `AGENTS.md`;
  - `find <wt>/openspec/changes/version-site-from-tags -name enhancement.yaml` prints nothing;
  - `git -C <wt> diff --stat origin/main...HEAD` (from the merge base, so changes that merged to `main` after this branch started are left out) stays inside proposal.md "Touches".
- [ ] 5.2 Report to the supervisor with the block in `orchestration.md` section 7, step 6:
  - `surface`: design.md "Interface: what this change adds and relies on";
  - `deviations`: whatever 1.1, 1.2, 4.1, 4.2 and 4.4 found or did.

  Then stop and wait.
- [ ] 5.3 On the supervisor's go, tick this box first. Then:
  1. `cd <wt> && openspec archive version-site-from-tags --yes --skip-specs`;
  2. confirm `cd <wt> && openspec validate --all --strict --no-interactive` is green;
  3. commit `chore(openspec): archive version-site-from-tags`.

  The push and the PR follow `orchestration.md` section 7, step 7. They are not tasks here.
