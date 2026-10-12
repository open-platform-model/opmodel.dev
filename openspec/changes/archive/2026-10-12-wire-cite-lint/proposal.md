## Why

The workspace has one comment rule: a comment names an enhancement by id only beside a reason in words, never by decision number. Other repos run it locally and in CI. This repo has the rule in `openspec/config.yaml` but no check, so a later citation by decision number, or a lone id, passes review. The repo also runs the OpenSpec CLI at 1.12.0, which does not know the `references:` key, and its `task openspec:check` does not check the Durable decisions section of a change.

## What Changes

- `task cite-lint` runs `enh cite-lint` at a pinned commit of the enhancements repo, with no exclude.
- `site.yml` gains a `Cite lint` job: a plain call of the reusable `cite-lint.yml` of the `.github` repo, pinned by commit.
- The OpenSpec CLI pin moves from 1.12.0 to 1.14.1 (`site.yml`, the `openspec:check` message, `openspec/config.yaml`, `README.md`).
- `task openspec:check` also runs `.tasks/openspec-check.sh`: every active change names a target for each durable decision, and each named file exists. A test script covers the check.

## Before / After

**Before**

```yaml
# Taskfile.yml
openspec:check:
  cmds:
    - openspec validate --all --strict --no-interactive
# .github/workflows/site.yml
jobs:
  build: ...
  browser: ...
```

**After**

```yaml
# Taskfile.yml
vars:
  CITE_LINT_REF: e0335b2ec44e659c0191bc3523d79d17f26f8e7d
cite-lint:
  cmds:
    - go run github.com/open-platform-model/enhancements/tools/enh@{{.CITE_LINT_REF}} cite-lint --root .
openspec:check:
  cmds:
    - openspec validate --all --strict --no-interactive
    - bash .tasks/openspec-check.sh .
    - bash .tasks/openspec-check-test.sh
# .github/workflows/site.yml
jobs:
  cite-lint:
    name: Cite lint
    permissions: {contents: read}
    uses: open-platform-model/.github/.github/workflows/cite-lint.yml@<commit>
```

## Impact

- Files: `Taskfile.yml`, `.github/workflows/site.yml`, `.tasks/openspec-check.sh`, `.tasks/openspec-check-test.sh`, `openspec/config.yaml`, `AGENTS.md`, `README.md`.
- `task cite-lint` finds 0 findings today with no exclude. `site/tests/fixtures` holds old-entry mimics, but they are Markdown, which the rule skips.
- `task cite-lint` needs the network (`go run`). It is not part of `task check` or `task ci`, so the Docker-only site gates do not change; CI runs the rule through the new job.
- The `.claude/skills/` files keep `generatedBy: 1.12.0`; the owner regenerates them with `openspec update`.
- Owner action: install the OpenSpec CLI 1.14.1 locally. Nothing makes the `Cite lint` job a required check.
- No published URL, site version or source repo changes.

## Enhancement

None.
