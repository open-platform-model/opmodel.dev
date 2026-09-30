`<wt>` is `/var/home/emil/dev/open-platform-model/opmodel.dev/.claude/worktrees/add-site-ci`. It is on branch `ci/add-site-ci`, from `origin/main` after A merged (orchestration.md section 7 step 2). `WS` is `/var/home/emil/dev/open-platform-model`. `<scratch>` is your scratch directory, outside every repo. Every build runs in Docker through the Taskfile; never run hugo, npm, npx or node on the host.

Gates for every section (orchestration.md section 2, row E, and section 10):
- `task -d <wt> check`
- `OPM_SRC_WORKTREE=site-src task -d <wt> ci`. It reads the supervisor's `site-src` worktrees. Leave `OPM_REQUIRE_DATES` unset locally (trap 21).
- `task -d <wt> ci:lint`, from task 1.5 on.

Section 2 also runs `OPM_SRC_WORKTREE=site-src task -d <wt> qa`, the command its new job runs.

## 1. Build and test job, and the workflow lint (CI, Taskfile, README)

- [x] 1.1 Preconditions: A's cutover is on `origin/main`, the `site-src` worktrees exist, and nothing CI-related exists yet.
  - `task -d <wt> --list` names `ci`, `qa`, `lint:sources` and `versions:prepare`, and no `shots:image`.
  - `<wt>/site/Dockerfile` exists and `<wt>/site/package.json` does not.
  - For each of opm, core, catalog_opm, cli, library and opm-operator, `git -C WS/<repo>/.claude/worktrees/site-src rev-parse HEAD` prints a SHA.
  - `<wt>/.github` does not exist.
  - If any check fails, stop with nothing edited and report the blocker.
- [x] 1.2 Spike, CI layout. Clone the seven repos into `<scratch>/ciws/` the way CI checks them out: `git clone https://github.com/open-platform-model/<repo>.git <scratch>/ciws/<repo>` for opmodel.dev, opm, core, catalog_opm, cli, library and opm-operator. That gives full history, `main`, and real `.git` directories, not worktrees. Run `OPM_REQUIRE_DATES=1 task -d <scratch>/ciws/opmodel.dev ci`.
  - These clones are throwaway spike inputs that this change sanctions. They sit outside every repo, you edit and commit nothing in them, and 1.3 removes them. All the change's edits and commits stay in `<wt>`, as orchestration.md section 1 requires.
  - Verify: it passes, and the build summary prints a file count.
  - Verify: `<scratch>/ciws/opmodel.dev/site/public/build-stamp.json` names six SHAs, each equal to that repo's `git -C <scratch>/ciws/<repo> rev-parse HEAD`.
  - Then run `git -C <scratch>/ciws/opmodel.dev status --porcelain --untracked-files=all -- . ':(exclude).task'` and keep the output.
  - If the build fails only because of `OPM_REQUIRE_DATES=1` (for example, git refuses to read a mounted clone inside the container), stop and report. Dates belong to A's interface (trap 21), not to this change's files.
  - If the status output is not empty, stop and report the paths. The clean-tree step would fail on them, and `.gitignore` is outside this change.
- [x] 1.3 Spike, `task qa`. Run `task -d <scratch>/ciws/opmodel.dev --dry qa`.
  - Verify from the printed commands whether `qa` builds `site/public` itself (design.md decision 7).
  - Record also whether any printed command names a `/src/<repo>` mount or a path under `<scratch>/ciws/<repo>` for a source repo.
  - Then check the global dynamic vars (such as `OPM_BUILD_REFS`) against missing sources: `OPM_SRC_WORKTREE=absent task -d <scratch>/ciws/opmodel.dev --dry qa`. With no directory of that name, every source root is missing. Record whether it exits 0 and whether it prints any source path. A dry run runs only the dynamic vars' `sh:` lines and no task command, so it starts no container and creates no mount directory.
  - `qa` reads no source root only if it names none in the first run and the second run exits 0 without naming one. Only then may 2.1's fallback check out opmodel.dev alone.
  - Write four things into design.md, "CI layout and `task qa`": the stamp's key names, the status output from 1.2, whether `qa` builds `site/public`, and whether it reads a source root.
  - Then remove `<scratch>/ciws` (scratch clones, not worktrees). If a path in it is root-owned (trap 22), leave it and report it.
- [x] 1.4 Write `<wt>/.github/workflows/site.yml`, workflow `Site`, per design.md decisions 1 to 6 and 9.
  - The four triggers, top-level `permissions: contents: read`, and the workflow `env` `OPM_REQUIRE_DATES: '1'`.
  - Job `build`, with a job-level concurrency group suffixed `-build` and a comment saying why concurrency is per job.
  - The seven checkouts: `path:` for each, sources at `ref: main`, `fetch-depth: 0`, `persist-credentials: false`.
  - The toolchain: setup-go with `go-version-file` and `cache-dependency-path`; setup-node 24; setup-task at the host's exact `task --version`; `npm install -g @fission-ai/openspec@1.12.0`.
  - The steps: `task ci:lint`, `task ci`, the clean-tree step, the summary, and the `site-public` and `build-stamp` uploads. The summary is a `jq` table of the six SHAs, using the key names from 1.3, followed by the file count.
  - The job sets `defaults: run: working-directory: opmodel.dev`, with a comment saying it is per job because F's deploy job runs a step before its checkout. No step repeats `working-directory`, and there is no workflow-level `defaults`.
  - Check `actions/upload-artifact` for a release newer than v7.0.1. If there is one, pin its commit SHA and update decision 9.
  - Verify: every line that `grep -n 'uses:' <wt>/.github/workflows/site.yml` prints carries a 40-hex SHA and a `# vX.Y.Z` comment.
- [x] 1.5 Add `ci:lint` to `<wt>/Taskfile.yml` per design.md decision 8: one new task, with a task-local image var.
  - Check `rhysd/actionlint` for a release newer than 1.7.12. If there is one, pin its index digest and update decision 9.
  - Verify: `task -d <wt> ci:lint -- -verbose` exits 0 and names `site.yml`.
  - Negative checks, each reverted afterwards. A step reading `${{ github.nope }}` makes it fail, naming `site.yml` and the line. A `run: echo $HOME` step makes it fail with a shellcheck finding (SC2086). After both reverts, `task -d <wt> ci:lint` is green again.
- [x] 1.6 Add `## CI` to `<wt>/README.md`. It lands section 1's durable decisions (design.md, "Durable decisions"):
  - the workflow and when it runs, with the local equivalents `task ci` and `task ci:lint`;
  - the `path:` checkout layout, with sources at `main`, full history and no stored credentials;
  - `OPM_REQUIRE_DATES=1` only in CI;
  - the pins, and that each is bumped on purpose;
  - concurrency per job, one group per job, and a deploy job's own non-cancelling group; the `opmodel.dev` working directory as a per-job default, never workflow-level;
  - CI fails when `task ci` leaves the tree dirty (`.task/` excluded), for example after `go fmt` rewrote unformatted Go or a build wrote a file that is not gitignored; the local equivalent is `task ci`, then `git status --porcelain`;
  - the nightly run replacing dispatch, the 60-day schedule lapse, and the failure mail going to whoever last edited the cron line.
  - Verify: each statement matches `site.yml` and the `ci:lint` task as written.
- [x] 1.7 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci` and `task -d <wt> ci:lint` green. `git -C <wt> status --short` lists only `.github/workflows/site.yml`, `Taskfile.yml`, `README.md` and `openspec/changes/add-site-ci/`. Then commit `ci: build and test the site on every pull request`.

## 2. Browser job (CI, README)

- [x] 2.1 Add job `browser` to `<wt>/.github/workflows/site.yml` per design.md decision 7 and the 1.3 finding.
  - Default: its own concurrency group suffixed `-browser`; `defaults: run: working-directory: opmodel.dev`, as in `build`; the same seven checkouts as `build`; setup-task at the same version; `task qa`; and the `site-shots` upload of `opmodel.dev/site/.shots`, with `if: always()`, `include-hidden-files: true`, `if-no-files-found: warn` and 7 days' retention.
  - If 1.3 found that `qa` does not build `site/public`: `needs: build`, and download `site-public` into `opmodel.dev/site/public` with `actions/download-artifact` (pin it by commit SHA at apply time and add it to decision 9), then run `task qa`.
    - Check out opmodel.dev alone only if 1.3 also found that `qa` reads no source root. Otherwise keep all seven checkouts.
  - Verify: `task -d <wt> ci:lint` is green.
  - Verify: the `site-shots` upload step's `with:` block has exactly `name: site-shots`, `path: opmodel.dev/site/.shots`, `include-hidden-files: true`, `if-no-files-found: warn` and `retention-days: 7`, and the step has `if: always()`.
  - Verify: wherever `browser` has the seven checkouts, they are identical to `build`'s, line for line.
- [x] 2.2 Add the browser job to `README.md` `## CI`: what `task qa` checks in CI, and that the `site-shots` artifact holds the screenshots of every run that got as far as taking them, including a failed run's. Say also that the upload needs `include-hidden-files: true` because `.shots` is a hidden directory.
- [x] 2.3 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci`, `task -d <wt> ci:lint` and `OPM_SRC_WORKTREE=site-src task -d <wt> qa` green. `qa` is the command the new job runs; afterwards `<wt>/site/.shots/` holds PNGs. Then commit `ci: smoke-test the site in a browser`.

## 3. Pull request titles (CI, README)

- [ ] 3.1 Write `<wt>/.github/workflows/pr-title.yml` from cli's copy, per design.md decision 10. Read it with `git -C WS/cli fetch origin`, then `git -C WS/cli show origin/main:.github/workflows/pr-title.yml`.
  - Keep: `pull_request_target` with its four activity types, `permissions: pull-requests: read`, the action's SHA pin, `requireScope: false`, and the lowercase subject pattern with its error text.
  - Set `types` to `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `build`, `ci`.
  - Rewrite the header comment for this repo: the squash title is `COMMIT_OR_PR_TITLE`, and there is no release-please.
  - Verify: the `types` list equals the types under "Commit Standards" in `<wt>/openspec/config.yaml`, and `task -d <wt> ci:lint -- -verbose` is green and names both workflow files.
- [ ] 3.2 Add to `README.md` `## CI`: PR titles must be Conventional Commits with this repo's types, because a pull request with several commits lands on `main` under its title. Say also that the check first runs on the pull request after this change merges, because `pull_request_target` reads `main`'s workflow.
- [ ] 3.3 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci` and `task -d <wt> ci:lint` green. Then commit `ci: check pull request titles`.

## After section 3 (orchestration.md section 7, steps 6 to 8; not tasks)

These steps change no file and have no boxes; orchestration.md owns them.
- Verify by following `<wt>/.claude/skills/openspec-verify-change/SKILL.md` for `add-site-ci`. Run each `openspec` command as `cd <wt> && openspec ...`; never use the root `/opsx:verify` router. Check also:
  - `find <wt>/openspec/changes/add-site-ci -name enhancement.yaml` prints nothing;
  - `git -C <wt> diff --stat origin/main...HEAD` touches only the Touches list in proposal.md.
- Report with the block in orchestration.md section 7, step 6, then stop and wait.
  - `sections`: `3/3`.
  - `gates`: each section's gates, plus the spike runs of 1.2 and 1.3.
  - `surface`: adds `task ci:lint`. Relies on `task ci`, `task qa`, `OPM_WS`, `OPM_SRC_<REPO>`, `OPM_SRC_WORKTREE`, `OPM_REQUIRE_DATES`, `OPM_BUILD_REFS`, `site/public/`, `site/public/build-stamp.json` and `site/.shots/`.
  - `follow-ups`: at least checks in the source repos' own pull requests (0018:D13), and the tracked `.task/checksum/build-docgen` if it is still tracked (design.md decision 6).
- On the supervisor's go: the archive (with `--skip-specs`), the push and the pull request, as orchestration.md section 7, step 7 says. After the merge, the cleanup (step 8).
- This change merges only when the `Site` workflow is green on its pull request. On that first run, also confirm that the run lists a non-empty `site-shots` artifact (`gh api repos/open-platform-model/opmodel.dev/actions/runs/<run-id>/artifacts --jq '.artifacts[] | [.name, .size_in_bytes]'`), and report it with the PR URL. design.md "Risks / Trade-offs" says how to fix a failure seen only there.
