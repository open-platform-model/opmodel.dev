# Design: docs-catalog-contract

## Overview

Two hand-written pages under `site/content/reference/`, written for their audiences rather than transcribed from decision logs: the contract page addresses a catalog author mid-change ("is this edit legal at this level, and what will refuse it"); the namespaces page addresses anyone choosing a publish coordinate. Decisions are cited inline by number (`0010 D27`-style) so the provenance is checkable, but every rule is restated in plain language. The enhancement entries remain the design record, the pages become the contract's public form.

## Research & Decisions

### Placement: `reference/`, not `guides/`

Both pages state contracts (normative, lookup-shaped, stable) rather than walkthroughs. They sit beside the generated `reference/definitions` and `reference/cli` sections as the site's first hand-written reference pages; `guides/` (currently empty) stays for task-oriented prose. Hugo front matter mirrors the existing `reference/_index.md` conventions; diagrams, if any, follow the repo's box-drawing/ASCII style rule.

### The contract page's structure follows the author's decision path

1. **What you promised**: the level ladder, per-member `apiVersion`, the alpha carve-out, and the two-axes trap (release prerelease ≠ contract level) stated early because it is the misreading 0010 D34 documents as likely.
2. **What "additive" means**: D27's three clauses with one worked example each (add optional field: legal; remove field: refused; move a default: refused), matching the violation kinds the gate actually prints (`field removed`, `default changed`, `domain narrowed`, `field added without optional or default`) so the page and the refusal text teach the same vocabulary.
3. **The three version-shaped values**: a table of value, where it lives, what changes it, whether it is part of a key. This is the section that prevents the "bump `catalogVersion` to escape the gate" misunderstanding: `catalogVersion` is provenance, `apiVersion` is the escape hatch.
4. **How it is enforced, exactly**: publish-gate-only (D35 verbatim framing), the predecessor rule in one paragraph (last published build that shipped the member, prereleases included, per 0011 D23), and the honesty paragraph: `registry check --compat` is an aid; un-gated publishes exist and break the chain silently. The page must not imply registry-side enforcement that does not exist (tag immutability is the unowned Zot item and is *not* claimed).

### The namespaces page is a table with two prose frames

The table rows (prefix, meaning, who publishes, enforcement point, defining decision) are the payload. Two short frames around it: **hosts-not-indexes** (0011 D13: the registry asserts nothing about domains OPM does not own; your domain is yours, the gates go quiet), and **why shortcuts are safe** (0011 D25: `opm mod init standard` expands only into the reserved, release-pipeline-curated segment, so a bare word can never be squatted). `testing.opmodel.dev`'s row states its fixture-only meaning and names the operator-fleet relocation as its current occupant so nobody reads production intent into it.

### What the pages deliberately do not contain

No gate implementation detail (walk order, package loading), no CLI flag reference (the generated CLI section owns that), no enhancement narrative. Each page should survive the next slice landing without edits unless a *decision* changes. That is the test for whether a sentence belongs.

## Technical Notes

- Files: `site/content/reference/catalog-contract.md`, `site/content/reference/registry-namespaces.md`; `reference/_index.md` gains both links.
- Verify rendered output with `task serve` locally and `task build` clean.
- The root-workspace `CLAUDE.md` pointer (one line under Registry Policy naming the templates segment) is a workspace-file edit riding this change's PR set, not site content.
- Record-back: 0010 `plan.yaml` slice → `done`, `openspec_ref: "opmodel.dev/docs-catalog-contract"`, history event citing it; note in the event that this closes 0010's implementation phase.
