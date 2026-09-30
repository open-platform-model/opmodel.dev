## Why

opmodel.dev has no CI: the repo has no `.github/` directory and GitHub lists no workflows for it. After `port-site-to-hugo-hextra` (A) merges, the site builds and is tested only on an agent's machine. Nothing checks a pull request here. A source-repo merge that breaks the page dialect or a link is found only by the next local build.

This change makes every pull request, every push to `main`, a nightly run and a manual run build and test the site exactly as the Taskfile does. It merges first in wave 2 for two reasons. B, C, D and M then merge through a checked workflow. And the deploy change (F) adds its job to a workflow that is already green.

## What Changes

- **New `.github/workflows/site.yml`** (workflow `Site`).
  - Triggers: `pull_request` to `main`, `push` to `main`, a nightly `schedule`, and `workflow_dispatch`.
  - Hygiene: every action pinned by full commit SHA with a version comment, top-level `permissions: contents: read`, and `OPM_REQUIRE_DATES=1` for the whole workflow.
  - Concurrency is set per job, with one group per job and `cancel-in-progress: true`. There is none at workflow level, so F's deploy job can use its own non-cancelling group.
  - Seven `actions/checkout` steps, each with `path:`: `opmodel.dev` at the event's ref, and opm, core, catalog_opm, cli, library and opm-operator at `main`. All use `fetch-depth: 0` and `persist-credentials: false`.
  - Job `build`: Go from `opmodel.dev/go.mod`, Node 24 with openspec 1.12.0, and Task at an exact version. It runs `task ci:lint`, then `task ci`, then checks that the build left the tree clean. It writes the six source SHAs and the file count into the job summary, and uploads `site/public` and `build-stamp.json` as artifacts.
  - Job `browser`: `task qa` (screenshots, accessibility and search smoke tests). It uploads `site/.shots/`.
- **New `.github/workflows/pr-title.yml`**, copied from cli. It fails a pull request whose title is not a Conventional Commit, using this repo's commit types.
- **`Taskfile.yml`: new `ci:lint`.** It runs actionlint, which bundles shellcheck, from a digest-pinned image over `.github/workflows/`. It is the local per-section gate, because no workflow runs before the branch is pushed.
- **`README.md`: a new `## CI` heading.** It says what runs when, gives the local equivalents, and names the pins and the concurrency rule.

Nothing here is **BREAKING**. No URL, page or version changes, and nothing deploys.

## Before / After

**Before**

```text
.github/                     none
Taskfile.yml                 check, image, build, serve, preview, lint:sources, test:site,
                             shots, qa, ci, clean, versions:prepare   (A)
README.md                    no CI heading
```

**After**

```text
.github/workflows/
  site.yml                   on: pull_request (main), push (main), schedule (nightly), workflow_dispatch
                             env: OPM_REQUIRE_DATES=1
                             jobs:
                               build    checkout x7 (path:, fetch-depth 0) -> setup-go, setup-node,
                                        setup-task, openspec 1.12.0 -> task ci:lint -> task ci
                                        -> clean tree -> summary (6 SHAs, file count)
                                        -> artifacts site-public, build-stamp
                               browser  checkout x7 -> setup-task -> task qa -> artifact site-shots
  pr-title.yml               on: pull_request_target; Conventional Commit title check
Taskfile.yml                 + ci:lint   actionlint by digest over .github/workflows/
README.md                    + ## CI
```

## Impact

- **Touches.** `.github/workflows/site.yml` and `.github/workflows/pr-title.yml` (new). `Taskfile.yml`: the new `ci:lint` task only. `README.md`: its own `## CI` heading. `openspec/changes/add-site-ci/`: task ticks and the spike findings written into `design.md`. Nothing under `site/` changes.
- **Build inputs.** The site build gains no input. CI adds a runner toolchain: Go from `go.mod`, Node 24 for the openspec CLI, and Task at an exact version. It also adds the actionlint image, pinned by digest. Each run builds the Hugo and QA images from their Dockerfiles; nothing is published to GHCR.
- **Source repos.** None has to change. Every run reads each source repo's `main`. After this change, a page there that breaks A's lint or link check fails opmodel.dev's nightly run and every opmodel.dev pull request until it is fixed in its own repo. It is never fixed here. Running the same checks in the source repos' own pull requests is a follow-up (0018:D13), outside this change.
- **URLs and versions.** Nothing is published. The build is `v1.0`, from each source repo's `main` (owner decision O3). B moves the refs later. Versioning stays 0021:OQ15, an open question this change does not touch.
- **Depends on.**
  - Starts when: A (`port-site-to-hugo-hextra`) is merged. Its cutover gives the tasks their final names, which the workflow calls.
  - Starts when: the supervisor's six `site-src` worktrees exist. The local build gates read them.
  - Merges when: the verify is green and the `Site` workflow is green on this change's pull request. E merges first in wave 2, before B, C, D and M. The supervisor merges it.
  - F (`deploy-site`) starts after this change is merged.
- **Hands off to F.** `site.yml`, into which F adds its deploy job; `task ci:lint`; the per-job concurrency groups; and the `site-public` artifact.

## Enhancement

None as a delivery claim. This change carries no `enhancement.yaml`, because no change in this set claims delivery (supervisor ruling O7).

Related decisions, for context only:
- 0018:D8 says two repositories publishing one address fail the build. A's check enforces that, and this change runs it on every pull request and every night.
- 0018:D13 wants machine checks in the pull requests of the repo that owns the page. This change runs them only in opmodel.dev, so it does not satisfy 0018:D13:R1. The source-repo check is named above as a follow-up.
