# Open Platform Model — Documentation Site Constitution

## Purpose

This document is the reader-friendly reference for the principles that shape the `opmodel.dev` documentation site. This repo builds the public-facing documentation for the Open Platform Model using Hugo with the Hextra theme, assembled from the pages each source repository writes and generates.

Documentation here serves four audiences: Module Authors writing CUE definitions, Platform Operators deploying modules, End-users consuming modules, and Contributors extending OPM.

## Design Principles

| # | Principle | Summary |
|---|-----------|---------|
| **I** | [The Site Owns Assembly, Not Content](#i-the-site-owns-assembly-not-content) | The site assembles pages from their owning repositories and renders them |
| **II** | [Generated Before Handwritten](#ii-generated-before-handwritten) | Reference docs are generated in the owning repository; prose docs are handwritten |
| **III** | [Separation of Concerns](#iii-separation-of-concerns) | Content, the pipeline and the theme are independently replaceable layers |
| **IV** | [Type Safety Carries Through](#iv-type-safety-carries-through) | Generated reference must preserve CUE type fidelity |
| **V** | [Portability by Design](#v-portability-by-design) | Site content stays runtime-agnostic; platform-specific content is labeled |
| **VI** | [Semantic Versioning](#vi-semantic-versioning) | SemVer 2.0.0 for tooling; Conventional Commits for all commits |
| **VII** | [Simplicity & YAGNI](#vii-simplicity--yagni) | Complexity must be justified; prefer composable solutions |
| **VIII** | [Small Batch Sizes](#viii-small-batch-sizes-iterative--incremental-delivery) | Changes must stay tiny, incremental, and independently verifiable |

---

### I. The Site Owns Assembly, Not Content

This repo owns the pipeline from the source repositories' signed docs bundles to the rendered site:

- each source repository writes its pages in `docs/site/`, generates its own reference pages, and publishes both in a signed docs bundle (docs-kit)
- Hugo (Hextra theme) renders the bundles' pages, with the few site-owned pages, into the final site

The build reads no git repository but this one. The site must be reproducible from a clean checkout and a docs bundles' lock with `task bundles:pull build`.

---

### II. Generated Before Handwritten

Reference documentation MUST be generated from authoritative sources:

- core's definitions, the catalog's members, the CLI's commands, the operator's resources and the library's Go API are generated in the CI of the repository that owns each and published in its signed docs bundle, never committed for the site to read
- Getting-started guides, conceptual docs, and tutorials are handwritten

A generated block is marked as such, apart from any handwritten text on the same page. Nobody edits it by hand.

---

### III. Separation of Concerns

The three layers of the documentation pipeline MUST remain independently replaceable:

- the source repositories' docs bundles — authored and generated pages, in the page dialect
- `site/` (Hugo + Hextra) — assembly, static site generation and layout
- `site/content/` — the few site-owned pages

Changes to one layer must not require changes to the others unless the interface between them changes. The interface is the docs bundle (docs-kit's contracts) and its page dialect (C11): Markdown pages written under each repository's `docs/site/`.

---

### IV. Type Safety Carries Through

Generated reference MUST preserve CUE type fidelity:

- Field types, constraints, defaults, and optionality must be accurately represented
- Cross-references between definitions must be resolved, not elided
- The rendered output should allow a reader to reconstruct valid CUE from the documentation alone

CUE's structural typing is the source of truth. The documentation is a human-readable projection of that source.

---

### V. Portability by Design

Documentation MUST remain runtime-agnostic where the underlying OPM model is runtime-agnostic:

- Core concept pages must not assume a specific cloud provider or Kubernetes distribution
- Platform-specific deployment guidance must be labeled clearly
- ASCII-safe symbols (`[x]`, `[ ]`, `OK`, `FAIL`) MUST be used in diagrams and tables — never Unicode checkmarks (`✓`, `✗`)

---

### VI. Semantic Versioning

All tooling artifacts MUST follow SemVer 2.0.0. All commits MUST follow Conventional Commits v1: `type(scope): description`.

Allowed commit types:

- `feat`
- `fix`
- `refactor`
- `docs`
- `test`
- `chore`

---

### VII. Simplicity & YAGNI

Start simple. Complexity MUST be justified with clear rationale. Prefer:

- Direct solutions over clever indirection
- Theme built-ins over overrides; every override copy is hash-guarded
- Fewer content types and layouts over many specialized templates
- Explicit configuration over implicit convention

If a new component override or content loader is introduced, it must solve a real documentation problem that simpler approaches cannot.

---

### VIII. Small Batch Sizes (Iterative & Incremental Delivery)

All changes MUST be kept tiny. Small, incremental, independently verifiable steps are required.

- If a request is too large, it must be split into smaller sequential tasks
- Tiny changes produce focused, atomic commits
- A single commit should ideally address one specific concern

#### Execution Gate

Before beginning any implementation, the scope of the request MUST be evaluated against the small-batch principle.

If the request is too large, the required response is:

> "🛑 **Scope Warning**: This request is too large for a single safe iteration. I suggest we split it into the following smaller steps: [list 2-3 logical, tiny steps]. Should we start with step 1?"

---

## Quality Gates

Before merge, the expected validation gates are:

1. `task check` — every OpenSpec change validates
2. `task build` — Site builds without errors, every build check passing
3. `task test:site` — the build checks prove themselves on fixtures

## How Principles Work Together

These principles reinforce each other:

- Generating reference where the source lives keeps documentation synchronized with it
- Generated-before-handwritten prevents stale reference docs
- Separation of concerns makes each layer independently testable and replaceable
- Type safety carrying through ensures the documentation is trustworthy, not aspirational
- Small batch sizes keep pipeline changes reviewable and rollback-safe

When principles appear to conflict, treat that as a design smell and document the trade-off explicitly.

## Further Reading

- `AGENTS.md` — repository mechanics, commands, and coding guidance
- `site/` — Hugo site source
- `README.md` — implementation status and next steps
