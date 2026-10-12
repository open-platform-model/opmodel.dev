## Context

`enh cite-lint` lives in the enhancements repo (`tools/enh`). The `.github` repo wraps it in a reusable workflow, `cite-lint.yml`, whose `enh-ref` default is the tool commit. This repo has one CI workflow with real jobs (`site.yml`, triggers `pull_request` and `push` to `main`) and `pr-title.yml` (`pull_request_target`).

## Goals / Non-Goals

**Goals:**
- Same comment rule locally and in CI, at one tool commit, with the smallest set of excludes.
- An `openspec:check` that also checks the Durable decisions section.

**Non-Goals:**
- Rewriting any citation, making the check required, adding the call to `pr-title.yml`.

## Decisions

- **Tool pin.** `CITE_LINT_REF` in the Taskfile equals the `enh-ref` default of `cite-lint.yml` at the pinned `.github` commit. Nothing checks that the two agree; a comment says to compare them at each `.github` pin move.
- **Excludes.** None. A lint run over the whole tree has 0 findings. Excludes would live in the Taskfile command and in the `with.exclude` of the CI call; a comment at each names the other.
- **CI call.** A job `cite-lint` in `site.yml`, not a new workflow: the file already has the right triggers and one job per check. The job has only `name`, a `concurrency` group like the other jobs, `permissions` (`contents: read`) and `uses`; no secret, no `with`. `site.yml` has no `pull_request_target` or `workflow_run` trigger. The commit comment is `# .github main`.
- **Not in `task check`.** `task check` and `task ci` run in the Docker-only flow and in the `build` job; adding a `go run` step would add a host Go dependency there. CI covers the rule through the new job.
- **OpenSpec pin.** `openspec validate --all --strict --no-interactive` passes under 1.14.1 here (checked in this change), so the pin moves. The `skip_specs` note in `config.yaml` no longer names the CLI version, because 1.14.1 writes the marker.
- **N11 check.** Same form as the catalog_opm check, adapted to the targets of this repo: `AGENTS.md`, `CONSTITUTION.md`, `README.md`, a contributor note, or "stays with the change". The check reads only active changes. `None.` passes. A named root file (`AGENTS.md`, `CONSTITUTION.md`, `README.md`, `TODO.md`) must exist. The check runs in CI through `task ci`, which calls `task check`.

## Risks / Trade-offs

- [The two tool pins drift] -> A comment in the Taskfile and a line in `AGENTS.md`; the same risk exists in the other repos.
- [Go 1.26.9 is not installed on the reviewer's machine] -> `go run` switches the toolchain itself.
- [A future check script has the wrong reading of a design] -> The test script holds nine cases.

## Durable decisions

- The `task cite-lint` rule and the `Cite lint` job, the pin comparison, and the "not in `task check`" choice land in `AGENTS.md` (task list) and `README.md` (CI table).
- The OpenSpec CLI pin 1.14.1 lands in `README.md` ("Pins").
- The N11 check lands in `AGENTS.md` (task list).
