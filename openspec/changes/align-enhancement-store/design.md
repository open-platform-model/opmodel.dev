## Context

The rewrite is mechanical for most sites and manual for the rest. Source: `enh cite-rewrite` (forms 1 to 5) and `enh cite-lint` of the `enhancements` repo, built from a local checkout. The repo has 253 matches: 223 in archived changes, 15 in the active `deploy-site` change (excluded), the rest in rule text, `README.md` and `TODO.md`. The site files that read enhancement data are not edited here.

## Goals / Non-Goals

**Goals:**
- The repo is clean under `cite-lint` and a second `cite-rewrite` dry run makes no edit.
- Rules live in `openspec/config.yaml`, so no OpenSpec skill file needs a local patch for them.

**Non-Goals:**
- Behaviour, `site/`, `.claude/**`, the OpenSpec CLI pin, and the `cite-lint` task and CI call (a later task adds them).

## Decisions

- Archived changes are rewritten like live text: an id beside a reason in words (design of the enhancements store, section 9).
- A `0030:` or `0031:` token is removed and its reason text stays.
- A site the tool lists but does not rewrite (a lone id, a question number, a fenced block) is rewritten by hand, or left with a reason in the report.
- `deploy-site` is excluded: its `orchestration.md` forbids an `enhancement.yaml`, and it belongs to its author.
- The `skip_specs` patch in the skills needs no `config.yaml` line: OpenSpec 1.14.1 writes `skip_specs: true` for a schema with no specs artifact. The rule text of `config.yaml` still says the marker must exist.
- The "durable decisions" archive patch becomes `operations.archive.guidance` (the existing line stays); a check for it (`openspec:check`) is a later task.

## Risks / Trade-offs

- A wrong edit in archived text changes its meaning -> the writer reads a sample of the tool's edits, and reviewers read more.
- The `references:` key is unknown to OpenSpec 1.12.0, the pinned CLI -> `openspec validate --all --strict` is run under the pin and under 1.14.1.
- Skill files keep `REPO-LOCAL PATCH` text until the owner runs `openspec update` -> listed in the PR body.

## Durable decisions

- The comment rule ("an enhancement id only beside a reason in words, never alone, never a decision number") -> `openspec/config.yaml` and `AGENTS.md`.
- The `Delivers NNNN, task X.Y.` line in a proposal -> `openspec/config.yaml` (`rules.proposal`), the schema template and `AGENTS.md`.
