## Context

A (`port-site-to-hugo-hextra`) leaves opmodel.dev with a Docker-only Hugo build behind Taskfile targets (orchestration.md section 6). `task ci` runs `check`, `image`, `build` and `test:site`. `task qa` runs the screenshots and the accessibility and search smoke tests. The repo has no `.github/` directory. The build reads six source repos, and the build reads them from paths it derives:
- `OPM_WS` is the parent of the opmodel.dev checkout. It is derived from `git rev-parse --path-format=absolute --git-common-dir`.
- Each source root is `$OPM_WS/<repo>`, unless `OPM_SRC_<REPO>` or `OPM_SRC_WORKTREE` says otherwise.

In a worktree, git inside the container cannot read the source repos (their `.git` is a file pointing at a host path), so page dates go missing. `OPM_REQUIRE_DATES=1` turns that into a failure, and only CI can set it: CI is the one place where every source is a real clone.

This change touches no file under `site/`. The site build gains and loses no input.

## Goals / Non-Goals

**Goals:**
- Every pull request to `main`, every push to `main`, a nightly run and a manual run build and test the site with the same Taskfile targets an agent runs locally.
- A local gate for the workflow files, `task ci:lint`, that each section can run before anything is pushed.
- A workflow F can extend with a deploy job without re-plumbing checkouts, toolchain or concurrency.
- Pull request titles that are Conventional Commits, because the squash title lands on `main`.

**Non-Goals:**
- Deploying (F), or any secret or environment.
- Cross-repo `repository_dispatch`: the nightly run replaces it. Publishing a build image to GHCR: each run builds its images.
- Checks inside the source repos' own pull requests (0018:D13, a follow-up).
- Changing any Taskfile target A defines, or any file under `site/`.

## Decisions

### 1. One workflow, `site.yml`, with jobs `build` and `browser`

F adds a `deploy` job to the same file (`needs: build`). One file keeps the checkout layout and the toolchain in one place. The sketch below is the review surface. Pins are in decision 9.

```yaml
name: Site

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  schedule:
    - cron: '23 3 * * *'        # nightly: source-repo merges reach CI within a day
  workflow_dispatch:

permissions:
  contents: read

env:
  OPM_REQUIRE_DATES: '1'        # a page without a git date fails the build (real clones only)

jobs:
  build:
    name: Build and test
    runs-on: ubuntu-latest
    timeout-minutes: 30
    # One group per job; never a workflow-level group (see decision 5).
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}-build
      cancel-in-progress: true
    defaults:
      run:
        working-directory: opmodel.dev   # per job, never workflow-level (see below)
    steps:
      - uses: actions/checkout@<sha> # v7.0.1
        with:
          path: opmodel.dev
          fetch-depth: 0
          persist-credentials: false
      - uses: actions/checkout@<sha> # v7.0.1
        with:
          repository: open-platform-model/opm
          ref: main
          path: opm
          fetch-depth: 0
          persist-credentials: false
      # ... the same for core, catalog_opm, cli, library, opm-operator
      - uses: actions/setup-go@<sha> # v7.0.0
        with:
          go-version-file: opmodel.dev/go.mod
          cache-dependency-path: opmodel.dev/go.sum
      - uses: actions/setup-node@<sha> # v6.5.0
        with:
          node-version: '24'
      - uses: go-task/setup-task@<sha> # v2.2.0
        with:
          version: 3.52.0
      - name: Install openspec
        run: npm install -g @fission-ai/openspec@1.12.0
      - name: Lint the workflows
        run: task ci:lint
      - name: Check, build and test the site
        run: task ci
      - name: The build leaves the tree clean
        run: |
          dirty=$(git status --porcelain --untracked-files=all -- . ':(exclude).task')
          [ -z "$dirty" ] || { printf '%s\n' "$dirty"; exit 1; }
      - name: Summary
        run: |   # table of the six source SHAs from site/public/build-stamp.json, then the file count
          ...
      - uses: actions/upload-artifact@<sha> # v7.0.1
        with:
          name: site-public
          path: opmodel.dev/site/public
          if-no-files-found: error
          retention-days: 14
      - uses: actions/upload-artifact@<sha> # v7.0.1
        with:
          name: build-stamp
          path: opmodel.dev/site/public/build-stamp.json
          if-no-files-found: error
          retention-days: 90

  browser:
    name: Browser QA
    runs-on: ubuntu-latest
    timeout-minutes: 45
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}-browser
      cancel-in-progress: true
    defaults:
      run:
        working-directory: opmodel.dev
    steps:
      # the seven checkouts, exactly as in build
      - uses: go-task/setup-task@<sha> # v2.2.0
        with:
          version: 3.52.0
      - name: Screenshots, accessibility and search smoke tests
        run: task qa
      - uses: actions/upload-artifact@<sha> # v7.0.1
        if: always()
        with:
          name: site-shots
          path: opmodel.dev/site/.shots
          include-hidden-files: true    # .shots is itself hidden; without this nothing uploads
          if-no-files-found: warn
          retention-days: 7
```

- **`working-directory` is a per-job default.** The repo is checked out at `$GITHUB_WORKSPACE/opmodel.dev`, so each job sets `defaults: run: working-directory: opmodel.dev` once, and no step repeats it. The default covers every `run:` step, the openspec install included. `uses:` steps ignore it, so their paths stay relative to `$GITHUB_WORKSPACE`.
- **Never a workflow-level `defaults`.** F's deploy job runs its secrets check before its checkout, and a workflow-level working directory would not exist yet at that step, so the step would fail.

### 2. Triggers: pull requests, pushes to main, nightly, manual

- `pull_request` to `main` checks every change before merge. That is the merge gate for the rest of wave 2.
- `push` to `main` checks what merged. F's deploy hangs off this trigger.
- The nightly `schedule` is how a source-repo merge reaches CI. The supervisor kept the nightly default over `repository_dispatch`: dispatch needs an App token with write access on opmodel.dev, and all six source repos would have to call it.
- `workflow_dispatch` reruns on demand.
- The cron runs at an off-the-hour minute, because GitHub delays scheduled runs at the top of the hour.

### 3. Checkout layout: seven `path:` checkouts, full history, no stored credentials

- **`path:` for every repo, opmodel.dev included.** `OPM_WS` is the parent of the opmodel.dev checkout. The default root checkout would put opmodel.dev at `$GITHUB_WORKSPACE`, and the sources would then have to sit inside it. With `path: opmodel.dev`, `OPM_WS` is `$GITHUB_WORKSPACE` and each source sits beside opmodel.dev, as it does in the workspace (orchestration.md trap 38).
- **Sources at `ref: main`** on every event. `v1.0` is built from each source repo's `main` until the beta tags exist (O3). B later changes what the build reads, through `versions:prepare`, not through these checkouts.
- **`fetch-depth: 0`** everywhere. gen-lastmod runs `git log -1` per file, and a shallow clone gives every page the clone's date, or none (trap 29). Full history also fetches tags, which B's resolver will read.
- **`persist-credentials: false`** everywhere. No step pushes, so no clone needs credentials. The flag leaves none configured, so nothing that points at the job token sits in a `.git` that the build containers mount.
- **The default job token reads all six sources.** They are all public (checked 2026-09-30). If one becomes private, its checkout needs an App token; that would be a new change.

### 4. Toolchain: only what the Taskfile targets call on the host

- The `build` job needs Go, because `task check` runs `go fmt`, `go vet` and `go test`. It also needs the openspec CLI, because `task check` runs `openspec:check`, and Task to run it all.
  - Go comes from `go-version-file: opmodel.dev/go.mod`. `cache-dependency-path` points at `opmodel.dev/go.sum`, because setup-go looks for `go.sum` at the workspace root and warns when it is not there.
  - openspec 1.12.0 is installed with npm on the runner, on Node 24 from `actions/setup-node`. This is cli's CI pattern. Node on a runner is fine; the no-npm rule is about the owner's machine.
  - Task is pinned to the exact version the host runs at apply time (`task --version`; 3.52.0 on 2026-09-30), not the org's usual `3.x`. The Taskfile is the build's entry point, and `3.x` would let CI run a newer Task than the one the local gates ran on (Principle IV: never float a tool version). Bump it on purpose.
- The `browser` job needs only Task (and Docker, which the runner has). `task qa` does not run `check`.
- Hugo, Pagefind, Playwright and axe-core stay inside the images A defines. Nothing here installs them on the runner.

### 5. Concurrency per job, one group per job

- The plan's group `${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true` is kept, but it is set per job, with a job suffix (`-build`, `-browser`).
- **Not at workflow level.** A workflow-level group would cancel a whole run when a newer one starts, including F's deploy job. F needs its own non-cancelling group (O1).
- **Not one shared job-level group.** Two jobs of one run in the same group with `cancel-in-progress: true` cancel each other: whichever starts second cancels the first.
- On `main`, a nightly or manual run and a push share `refs/heads/main`. A newer run therefore cancels an older run's build or browser job. That is intended: only the newest sources matter.

### 6. The build job's steps

- **`task ci:lint` first.** It is cheap, it fails fast, and it keeps the workflow honest after F and later changes edit it.
- **`task ci`.** It runs `check`, `image`, `build` and `test:site`, with `OPM_REQUIRE_DATES=1` from the workflow env. It is the same target an agent runs locally, and only the dates rule differs.
- **Clean tree after the build.** This step is not in the plan's list; it closes two gaps.
  - `task check` runs `go fmt ./...`, which rewrites files and never fails. So unformatted Go passes `task check`, and in CI the rewrite shows up as a dirty tree.
  - Any build step that writes a tracked file, or a generated file that is not gitignored, breaks Principle III, and this step catches it.
  - `.task/` is excluded, because Task writes checksum files there, and `.task/checksum/build-docgen` is tracked on `origin/main` today (a follow-up, outside this change).
  - No Taskfile target reproduces this failure, so the README names its local equivalent: `task ci`, then `git status --porcelain` (Durable decisions).
- **Summary.** A markdown table of the six source SHAs from `site/public/build-stamp.json`, followed by `find site/public -type f | wc -l`. O3 wants the SHAs in CI artifacts, and F checks the file count against Cloudflare's per-deploy limit. The `jq` expression follows the stamp's key names. Section 1's spike reads them from a real build and records them below.
- **Artifacts.** `site-public` holds the whole `site/public` tree for 14 days: reviewers download it, and F may deploy it within the same run. `build-stamp` holds only the stamp, for 90 days: it records which sources a run built.

### 7. The browser job builds for itself, in parallel

- `task qa` needs a built site. A's `qa` is expected to build it itself, as the Astro `shots` task did (`deps: [build, ...]`). A downloaded artifact would then be rebuilt anyway.
- So the default is a self-sufficient job: the same seven checkouts, Task, and `task qa`, running in parallel with `build`. Its failure is a separate status check.
- Section 1's spike reads A's merged `qa` with `task --dry qa`. If `qa` does not build `site/public` itself, the job instead declares `needs: build` and downloads `site-public` into `opmodel.dev/site/public`.
  - It checks out opmodel.dev only if `qa` reads no source root: no `/src/<repo>` mount and no `OPM_SRC_*` path in its commands, and no global dynamic var (such as `OPM_BUILD_REFS`) that fails when the sources are missing. The spike checks both (task 1.3).
  - Otherwise it keeps all seven checkouts. A missing mount source would become a root-owned empty directory (trap 22), and a failing dynamic var would stop the job.
  - The task breakdown is the same in every case.
- `site/.shots/` is uploaded with `if: always()`. When an accessibility or search test fails in CI, the screenshots are the only way to see why.
  - The upload sets `include-hidden-files: true`. `actions/upload-artifact` skips hidden files by default, and it counts every file under a directory whose name starts with `.` as hidden. Without the flag, `site/.shots` would upload nothing on every run, failed or green. The directory holds only the PNGs the QA image writes, so the flag exposes nothing sensitive.
  - `if-no-files-found: warn`, not `ignore`. A run that took no screenshots shows a warning on the run page instead of passing in silence.

### 8. `task ci:lint`: actionlint from a digest-pinned image

```yaml
  ci:lint:
    desc: Lint .github/workflows with actionlint (and its bundled shellcheck), in a pinned image
    vars:
      ACTIONLINT_IMAGE: rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667
    cmds:
      - docker run --rm --network none --user {{.UID}}:{{.GID}} --volume {{.ROOT_DIR}}:/repo:ro --workdir /repo {{.ACTIONLINT_IMAGE}} -color {{.CLI_ARGS}}
```

- The image var is task-local, so the edit stays inside one task. B and M also add tasks to `Taskfile.yml`; separate tasks merge cleanly.
- The container runs read-only, with no network, as the calling user. It has no `:z` label (trap 23).
- `-color` gives readable logs. `{{.CLI_ARGS}}` passes extra flags, for example `task ci:lint -- -verbose`.
- If A's Taskfile no longer defines `UID` and `GID`, use `$(id -u):$(id -g)`.
- It stays out of `task ci`, because A owns that target's definition (orchestration.md section 6). The workflow calls both.

### 9. Pins

| Action or image | Pin | Source |
|---|---|---|
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` | cli, library, operator workflows |
| `actions/setup-go` | `b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0` | cli |
| `actions/setup-node` | `249970729cb0ef3589644e2896645e5dc5ba9c38 # v6.5.0` | cli |
| `go-task/setup-task` | `a00fbb05ce67b35648be3c78cbc9fd85354c757e # v2.2.0` | library, operator |
| `amannn/action-semantic-pull-request` | `48f256284bd46cdaab1048c3721360e808335d50 # v6.1.1` | cli, library |
| `actions/upload-artifact` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1` | new to the org; the v7.0.1 release commit, resolved 2026-09-30 |
| `rhysd/actionlint` | `1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667` | the multi-arch index digest of the latest release, resolved 2026-09-30 |

At apply time, check `actions/upload-artifact` and `rhysd/actionlint` for a newer release. If there is one, resolve its tag to a commit SHA or index digest, use it, and record it here. The org pins stay as the other repos have them.

### 10. `pr-title.yml`: cli's check with this repo's commit types

- The check is copied from cli `origin/main`: `pull_request_target`, `permissions: pull-requests: read`, `requireScope: false`, and the lowercase-subject pattern.
- The `types` list becomes this repo's Commit Standards (`openspec/config.yaml`): `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `build`, `ci`. cli's `perf` and `revert` are dropped, because this repo does not use them.
- The header comment is rewritten. opmodel.dev has no release-please. The reason for the check here is different: the repo's squash setting is `COMMIT_OR_PR_TITLE`. A pull request with more than one commit, which every OpenSpec change has, lands on `main` under its PR title.
- `pull_request_target` runs the workflow as it is on the base branch. So the check first runs on the first pull request opened after this change merges, not on this change's own pull request.
- It checks out no pull request code, so `pull_request_target` gives the third-party action nothing to run.

## Research & Decisions

### What the repo and the org allow (read 2026-09-30)
**Context**: The plan assumed third-party actions are allowed and the sources are public. It also said to copy cli's pins.
**Explored**:
- `gh api repos/open-platform-model/opmodel.dev`: public, squash title `COMMIT_OR_PR_TITLE`, squash message `COMMIT_MESSAGES`.
- `.../actions/permissions`: `allowed_actions: all`, `sha_pinning_required: false`.
- The six source repos are public, and each default branch is `main`.
- `git grep 'uses:'` over every org repo's `origin/main` workflows gave the pins in decision 9. No org workflow uses `actions/upload-artifact`.
- Upstream latest releases: upload-artifact v7.0.1, actionlint 1.7.12 (index digest from Docker Hub), setup-task v2.2.0, checkout v7.0.1, setup-go v7.0.0. Task's latest is v3.53.1; the host runs 3.52.0.
- `git ls-files .task` on `origin/main` lists `.task/checksum/build-docgen`.
- The upload-artifact v7.0.1 README: `include-hidden-files` defaults to `false`, and "Hidden files are defined as any file beginning with `.` or files within folders beginning with `.`". `site/.shots` is such a folder.
**Decision**: Third-party actions by full SHA. Reuse the org's pins, and pin the two new ones fresh. Pin Task exactly. Exclude `.task/` from the clean-tree step. Upload `site/.shots` with `include-hidden-files: true`.
**Rationale**: Every assumption the workflow rests on was checked against the live repo settings. The one surprise, a tracked Task checksum file, would have failed the clean-tree step on the first run.

### CI layout and `task qa` (section 1 spike; filled in at apply time)
**Context**: Two facts can only be read from A's merged `main`:
- whether the build passes with `OPM_REQUIRE_DATES=1` on real clones laid out as CI lays them out, and what `build-stamp.json` looks like;
- whether `task qa` builds `site/public` itself, and whether it reads any source root (decision 7's fallback).
**Explored**: tasks 1.2 and 1.3.
**Decision**: (record the stamp's key names, the `git status --porcelain` output after `task ci`, the `task --dry qa` result, and whether `qa` reads any source root)
**Rationale**: (record why the browser job keeps decision 7's default, or switches to the artifact, and with how many checkouts)

## Interface (orchestration.md section 6)

- **Adds:** `task ci:lint`.
- **Relies on:**
  - the tasks `ci` (`check`, `image`, `build`, `test:site`) and `qa`;
  - `OPM_WS`, derived from the git common dir;
  - the `OPM_SRC_<REPO>` defaults (`$OPM_WS/<repo>`, with `OPM_SRC_WORKTREE` unset in CI; set to `site-src` only in the local gates);
  - `OPM_REQUIRE_DATES`;
  - `OPM_BUILD_REFS`, which the Taskfile sets on the host;
  - the outputs `site/public/`, `site/public/build-stamp.json` and `site/.shots/`, and the build summary's file count.
- **Hands to F:** `site.yml` with its job layout; the `site-public` artifact; the per-job concurrency and `defaults` rules; and `task ci:lint` as F's workflow gate.

## Risks / Trade-offs

- [Nothing runs the workflow before the branch is pushed] -> `task ci:lint` is the per-section gate. The section 1 spike reproduces the CI layout locally. The merge condition is the `Site` run green on the pull request. A failure seen only there is fixed by one more commit on the branch (`ci: ...`), re-verified and reported. The supervisor may allow a draft pull request after section 1 to see a run early (Open Questions).
- [A source repo's `main` breaks the build] -> Every opmodel.dev pull request and the nightly run go red until the page is fixed in its repo. The lint names file and line. Fix the page, never the lint (trap 27). The nightly failure mail goes to whoever last edited the cron line (GitHub behaviour).
- [GitHub disables a schedule after 60 days without repo activity] -> The README says so. F's runbook repeats it for deploys.
- [Worktree builds cannot prove dates] -> Local gates run without `OPM_REQUIRE_DATES`, because `site-src` worktrees have a `.git` file (trap 21). The spike's real clones and the CI run are the only proof.
- [A missing mount source becomes a root-owned empty directory] (trap 22) -> Every checkout step must succeed before `task ci`. A failed checkout stops the job first. The spike clones all seven repos before building.
- [Runner disk] -> The Playwright QA image is large (about 3.5 GB). A hosted runner has room for it and the Hugo image. If a pull fails for space, report it; a free-space step would be a follow-up.
- [`upload-artifact` skips hidden files by default, including every file under a directory whose name starts with `.`] -> `site/.shots` is such a directory, so the `site-shots` upload sets `include-hidden-files: true` (decision 7). No local gate can see an empty artifact: `ci:lint` does not check upload inputs, and with `warn` the run stays green. So task 2.1 checks the upload's inputs, and the first `Site` run on the pull request must show a non-empty `site-shots` artifact. `site/public` has no dotfiles today. If A or F ever publishes one (such as `.well-known/`), F must set `include-hidden-files: true` on `site-public` before it deploys from that artifact.
- [Images rebuilt on every run] -> Accepted (supervisor default: no GHCR build image). Image tags come from the Dockerfile hash, so nothing on the runner collides.
- [Old Astro tasks] (trap 35) -> This change starts only after A's cutover. Task 1.1 checks that the bare names are Hugo's before anything runs.

## Durable decisions

- **What runs when, and the local equivalents** (`task ci`, `task qa`, `task ci:lint`): `README.md` `## CI`, section 1. The browser job's line is added in section 2, with the `site-shots` artifact and why its upload needs `include-hidden-files: true`. The PR title line is added in section 3.
- **CI checks out every repo with `path:`, sources at `main`, full history, no stored credentials; `OPM_REQUIRE_DATES=1` only in CI**: `README.md` `## CI`, section 1.
- **CI fails when `task ci` leaves the tree dirty (`.task/` excluded)**, for example unformatted Go that `go fmt` rewrote, or a generated file that is not gitignored. The local equivalent is `task ci` followed by `git status --porcelain`: `README.md` `## CI`, section 1.
- **Pins: actions by full SHA with a version comment, Task exact, openspec 1.12.0, actionlint by digest in `ci:lint`; bump each on purpose**: `README.md` `## CI`, section 1.
- **Concurrency is per job, one group per job; a deploy job uses its own non-cancelling group. The `opmodel.dev` working directory is a per-job default too, never workflow-level**: `README.md` `## CI`, section 1, and comments beside the first `concurrency:` and the first `defaults:` in `site.yml`.
- **The nightly run replaces dispatch; schedules lapse after 60 days without activity**: `README.md` `## CI`, section 1.
- **PR titles are Conventional Commits because the squash title is the PR title**: `README.md` `## CI`, section 3.
- **The spike's findings** (the stamp's shape, the `qa` layout): stay with the change.

## Open Questions

- Supervisor: allow a draft pull request after section 1, to see a first `Site` run before sections 2 and 3 (plan-final, "For the supervisor to decide")? Tasks are the same either way. Without it, the first run happens on the pull request after the verify.
