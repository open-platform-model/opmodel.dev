# Proposal: docs-catalog-contract

> Slice `docs-catalog-contract` of enhancement `0010`, the last open implementation slice of the 0010/0011 pair. Decisions documented: 0010 D4, D27, D34, D35; 0011 D13, D14, D23, D25. This repo has no OpenSpec spec tree; this change ships proposal/design/tasks only, and the slice records with `openspec_ref: "opmodel.dev/docs-catalog-contract"`.

## Why

Everything this page set documents has now shipped (the publish pipeline, the gates, the reserved namespaces, the template segment) but the contracts exist only in enhancement decision logs and CLI help text. Two audiences have nothing public to read: a **catalog author** deciding whether a change is legal at a given contract level (and discovering the enforcement's honest boundary), and **anyone publishing OPM artifacts** needing to know which registry prefixes are policed, by what, and which are theirs. Both contracts were explicitly design-gated on being *published documentation*: 0010 D35 requires the aid-not-guarantee distinction to live "in the command's own help text" *and* the public contract; the registry-namespaces page was added to this slice's scope on 2026-08-16 precisely because the namespace truth was scattered across two decision logs, a CUE spec file, and the CLI's gate tables.

## What Changes

Two hand-written reference pages on the public site, plus navigation wiring:

- **`site/content/reference/catalog-contract.md`**, the catalog-author contract:
  - The **additive-only rule** (0010 D27): fields and options may be added, never removed; a new field must be optional or defaulted; an existing field's default may not move.
  - **Keyed to level** (0010 D34): the promise binds per member `apiVersion` (nothing at `vNalphaM`, D27 in full at `vNbetaM` and `vN`) and the member's level is **independent of the catalog's release version** (a `v1beta1` contract inside a `2.1.0-alpha.3` release is fully bound; the two axes never read across).
  - **The three version-shaped values** (0010 D4/D25): a member's `apiVersion` (the contract level, part of its key), a transformer's implementation version (the `…@1.2.0` in implementation FQNs, naming the bytes that run), and `catalogVersion` (the release that shipped the definition: provenance only, never part of a key).
  - **Enforcement and its honest boundary** (0010 D35, 0011 D23): OPM verifies the rule only for catalogs published through `opm catalog publish`. The compatibility gate compares each beta/GA member against the last published build that shipped it (prereleases included), and the member/posture gates run on every publish. `opm catalog registry check --compat` is an **aid, not a guarantee**; a catalog pushed by bare `cue mod publish` bypasses every gate, and nothing reports the broken chain.
- **`site/content/reference/registry-namespaces.md`**, the namespaces reference: every owned prefix (`core`, `catalogs/<name>`, `modules/<name>` flat with a snake leaf, `templates/<name>` reserved and cli-release-published with the `index` name reserved, `platforms` reserved and unpublished, `testing.opmodel.dev/*`, `community.opmodel.dev/m/<owner>/…`), each row carrying its enforcement point and defining decision; the hosts-not-indexes principle (0011 D13: nothing is asserted about unowned domains); and why bare-word template shortcuts are safe (0011 D25: expansion targets only the curated segment).
- **`site/content/reference/_index.md`** links both pages; a one-line pointer to the templates segment is added to the workspace root `CLAUDE.md` Registry Policy (the internal-audience counterpart, flagged when D25 landed).

## Impact

- Content-only: two Markdown pages + index wiring; no docgen, no Go, no generated content touched. Site builds via `task build`.
- Closes 0010's implementation phase. After this, only `modules-fleet-republish` (blocked on 0011's `modules-publish-cutover`) remains in the pair.
- Sources are the decision logs; the pages cite decisions by number so drift is traceable, but restate the rules in author-facing language (the pages are the contract's public form, not a link farm).
