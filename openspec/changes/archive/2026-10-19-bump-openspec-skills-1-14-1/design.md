## Context

`openspec update` overwrites generated skill files without a merge and recreates `openspec-sync-specs`. Four files here carry local edits against pristine 1.12.0: archive-change, new-change, propose and verify-change. A 3-way merge with `git merge-file` is clean for archive, new and verify, and has one conflict in propose.

## Goals / Non-Goals

**Goals:**
- Skills at 1.14.1 with the four local edits kept.

**Non-Goals:**
- Any change to `openspec/config.yaml`, the schema, a pin or a gate.

## Research & Decisions

### Propose conflict
**Context**: 1.14.1 adds workflow-selection text to step 3 of propose ("Use the configured default schema unless ...", a "show workflows" branch, "Otherwise, omit `--schema`"). The repo paragraph in the same step says the default is the project-local `docs-site-change` schema and never `spec-driven`.
**Explored**: 3-way merge of local, pristine 1.12.0 and pristine 1.14.1 with `git merge-file`.
**Decision**: Keep the repo paragraph and drop the 1.14.1 workflow-selection text in that step. Take every other 1.14.1 change in the file.
**Rationale**: The repo owner ruled this: keep the repo paragraph. A fixed schema leaves nothing to select.

### Local edits stay
**Decision**: The four edits stay, merged on each update. `AGENTS.md` names them.
**Rationale**: The earlier claim of no local patch is false today. The human rules that the files stay edited.

## Risks / Trade-offs

- [A later `openspec update` overwrites the edits] -> The `AGENTS.md` line says to merge with `git merge-file` against the pristine output of the previous version.

## Durable decisions

- The four kept skill edits, the `git merge-file` rule and the sync-specs deletion land in `AGENTS.md` (Skill files line).
