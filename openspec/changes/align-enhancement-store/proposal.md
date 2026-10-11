## Why

The enhancements repository moves to an OpenSpec store (`opm-enhancements`). In the new design every enhancement citation is an id beside a reason in words, never a decision number and never a lone id. This repo cites enhancement decisions by number in rule text, archived changes and two Markdown files, and its rules still ask for `enhancement.yaml`. Both must follow the new design.

## What Changes

- Rewrite every decision citation outside the active `deploy-site` change: a citation of an enhancement decision becomes `enhancement NNNN` beside its reason in words. Rewrites follow the `enh cite-rewrite` tool, then by hand for the sites the tool lists.
- Delete no file: this repo holds no `enhancement.yaml`.
- `openspec/config.yaml` gains `references:` to the store, the `Delivers` rule in `rules.proposal`, the comment rule, and a `context` line that tells how to read an entry. The `enhancement.yaml` rules and the delivery-log archive step go.
- `openspec/schemas/docs-site-change` (`schema.yaml`, `templates/proposal.md`): the Enhancement section asks for `Delivers NNNN, task X.Y.` lines.
- `AGENTS.md` and `README.md` say the same.
- No site behaviour changes: comments, rule text and archived text only.

## Before / After

**Before**

```yaml
# openspec/config.yaml
rules:
  proposal:
    - "... create enhancement.yaml in this change directory ..."
operations:
  archive:
    guidance:
      - "If this change directory contains enhancement.yaml ... task enhancements:delivery:log ..."
```

**After**

```yaml
# openspec/config.yaml
references:
  - id: opm-enhancements
    remote: https://github.com/open-platform-model/enhancements.git
rules:
  proposal:
    - "If the change delivers a line of an enhancement's `tasks.md`, add `## Enhancement` with one line `Delivers NNNN, task X.Y.` per task; otherwise `None.`"
operations:
  archive:
    guidance:
      - "If the change delivers a line of an enhancement's `tasks.md`, a PR on `enhancements` ticks that line."
```

## Impact

- Files: `openspec/config.yaml`, `openspec/schemas/docs-site-change/**`, `AGENTS.md`, `README.md`, `TODO.md`, and the archived changes under `openspec/changes/archive/` that cite a decision.
- Not touched: `openspec/changes/deploy-site/` (an active change; its `orchestration.md` forbids `enhancement.yaml`), `site/`, `layouts/`, `scripts/`, `tests/fixtures/` (the site reads enhancement data on the local branch `feat/read-enhancements-v2`), `.claude/**`.
- Owner action: run `openspec update` with the pinned CLI. The `REPO-LOCAL PATCH` blocks in `.claude/skills/` still ask for `enhancement.yaml` until then.
- No published URL, site version or source repo changes.
- Spec delta: none. This workspace has no specs artifact, and `.openspec.yaml` declares `skip_specs: true`.
- Depends on: the enhancements store merge, for the `references:` remote to resolve. Without a registered store the OpenSpec commands print a warning and go on.

## Enhancement

None.
