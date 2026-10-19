## Why

OpenSpec moves to 1.14.1 in every repo of the workspace. The CLI pin here is already 1.14.1, but the generated skill files under `.claude/skills/` still carry `generatedBy: "1.12.0"`. The 1.14.1 skills also match the CLI that the `openspec:check` gate runs. `AGENTS.md` says that no skill file keeps a local patch. That is false: four files carry one, and the human rules that they stay.

## What Changes

- Regenerate the ten `openspec-*` skill files with `openspec update --force` under 1.14.1.
- Merge the four local edits (archive-change, new-change, propose, verify-change) with `git merge-file` against pristine 1.12.0. In propose, keep the repo paragraph on the fixed `docs-site-change` schema and drop the workflow-selection text of 1.14.1 in that step.
- Delete `.claude/skills/openspec-sync-specs/` again: `openspec update` recreates it, and this repo has no specs.
- Rewrite the skill-files line of `AGENTS.md` so that it names the four kept edits and the sync-specs deletion.

## Before / After

**Before**

```text
.claude/skills/openspec-*/SKILL.md      generatedBy: "1.12.0"
AGENTS.md  Skill files: no openspec-* skill file keeps a local patch
```

**After**

```text
.claude/skills/openspec-*/SKILL.md      generatedBy: "1.14.1" (ten files)
.claude/skills/openspec-sync-specs/     absent
AGENTS.md  Skill files: archive, new, propose and verify keep local edits,
           merged by git merge-file on each update; sync-specs is deleted
```

## Impact

- Files: `.claude/skills/openspec-*`, `AGENTS.md`, this change folder.
- No pin, gate, spec, site page, published URL, site version or source repo changes. No `openspec/specs/` exists.
- `openspec/config.yaml` and the schema are not touched.

## Enhancement

None.
