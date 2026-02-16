# AGENTS.md - Documentation Site Repository

> **⚠️ UNDER HEAVY DEVELOPMENT** - This project is actively being developed and APIs may change frequently.

## Overview

Documentation site for the Open Platform Model, built with Hugo and a custom Go tool (`docgen`) that generates reference documentation from CUE definitions and CLI commands.

## Constitution

This project follows the **Open Platform Model Constitution**.
All agents MUST read and adhere to the principles defined in the main project.

**Core Principles:**

1. **Type Safety First**: All definitions in CUE. Validation at definition time.
2. **Separation of Concerns**: Module (Dev) -> ModuleRelease (Consumer). Clear ownership boundaries.
3. **Composability**: Definitions compose without implicit coupling. Resources, Traits, Blueprints are independent.
4. **Declarative Intent**: Express WHAT, not HOW. Provider-specific steps in ProviderDefinitions.
5. **Portability by Design**: Definitions must be runtime-agnostic.
6. **Semantic Versioning**: SemVer v2.0.0 and Conventional Commits v1 required.
7. **Simplicity & YAGNI**: Justify complexity. Prefer explicit over implicit.

**Governance**: The constitution supersedes this file in case of conflict.

## Build/Test Commands

- Build docgen: `task build:docgen` (output: ./bin/docgen)
- Generate schema docs: `task generate:schema`
- Generate CLI docs: `task generate:cli`
- Generate all: `task generate`
- Serve site locally: `task serve`
- Build production site: `task build` (output: ./public/)
- Clean: `task clean`
- Format: `task fmt`
- Vet: `task vet`
- Test: `task test`
- All checks: `task check` (fmt + vet + test)

## Technology Standards

### Documentation Generator

- **Go 1.22+**: For the docgen tool
- **cuelang.org/go**: Native CUE evaluation for schema extraction
- **github.com/spf13/cobra**: CLI framework for docgen
- **github.com/spf13/cobra/doc**: CLI reference generation

### Static Site Generator

- **Hugo 0.146.0+**: Extended version for SCSS support
- **Hugo Modules**: Dependency management (Docsy theme)
- **Docsy Theme**: (temporarily disabled due to i18n issues, will re-enable)
- **Content Adapters**: Hugo's `_content.gotmpl` for programmatic page generation

### CUE Integration

- **cuelang.org/go/cue**: Walk definitions, extract docs, fields, constraints
- **Key APIs**:
  - `load.Instances()` - Load CUE modules
  - `Value.Doc()` - Extract doc comments
  - `Value.Fields()` - Iterate fields
  - `Value.Default()` - Get defaults
  - `Value.IncompleteKind()` - Get types
  - `Value.Expr()` - Get constraint expressions

### CLI Doc Generation

- **cobra/doc.GenMarkdownTreeCustom()**: Generate markdown with Hugo front matter
- Import CLI root command as Go dependency for auto-sync

## Code Style

- **Go**: gofmt, golangci-lint compliant
- **Imports**: stdlib first, then external, then internal
- **Errors**: Wrap with context (`fmt.Errorf("extracting schema: %w", err)`)
- **Interfaces**: Accept interfaces, return concrete structs
- **Context**: Propagate context.Context in all APIs
- **Tests**: Table-driven with testify assertions

## Project Structure

```text
├── cmd/docgen/            # Documentation generator tool
│   └── main.go            # CLI with schema/cli/all subcommands
├── internal/
│   ├── cuedoc/            # CUE schema extraction logic
│   │   └── extractor.go
│   └── cobradoc/          # Cobra CLI doc generation
│       └── generator.go
├── site/                  # Hugo site source
│   ├── hugo.toml          # Hugo configuration
│   ├── content/
│   │   ├── getting-started/
│   │   ├── guides/
│   │   └── reference/
│   │       ├── definitions/    # Generated from CUE
│   │       │   ├── _content.gotmpl  # Content adapter
│   │       │   └── _index.md
│   │       └── cli/            # Generated from cobra
│   │           └── _index.md
│   ├── data/
│   │   └── schema/             # Generated JSON (gitignored)
│   ├── layouts/
│   │   └── shortcodes/         # Custom shortcodes for rendering
│   └── static/
├── Taskfile.yml           # Build automation
├── go.mod
└── README.md
```

## Maintenance Notes

- **Project Structure Tree**: Update the tree above when adding new packages or directories.
- **Hugo Version**: Keep Hugo 0.146.0+ for content adapter support
- **Docsy Theme**: Currently disabled due to i18n file format incompatibility. Will re-enable once upstream fixes or switch to Hugo Book theme.

## Key Packages

- `cmd/docgen/` - Documentation generator CLI
- `internal/cuedoc/` - CUE schema extraction (uses CUE Go API)
- `internal/cobradoc/` - Cobra CLI doc generation
- `site/` - Hugo site source

## Patterns

### CUE Documentation Extraction

1. Load CUE modules from catalog using `load.Instances()`
2. Walk definitions with `Value.Fields(cue.Definitions(true))`
3. Extract doc comments with `Value.Doc()`
4. Get field metadata: types, constraints, defaults, optional/required
5. Resolve cross-references (e.g., Trait `appliesTo` Resources)
6. Output structured JSON per module

### CLI Documentation Generation

1. Import CLI root command as Go dependency
2. Use `cobra/doc.GenMarkdownTreeCustom()` with Hugo front matter prepender
3. Generate one markdown file per command with synopsis, flags, examples
4. Cross-link parent/child commands

### Hugo Content Generation

1. `docgen` outputs JSON to `site/data/schema/`
2. `docgen` outputs markdown to `site/content/reference/cli/`
3. Hugo content adapter (`_content.gotmpl`) reads JSON and generates definition pages
4. Custom shortcodes render type tables, cross-references, constraints

## Glossary

See the [catalog glossary](https://github.com/open-platform-model/catalog/blob/main/docs/glossary.md) for OPM-specific terms.

### Personas

- **Module Author** - Writes CUE definitions, primary audience for reference docs
- **Platform Operator** - Deploys modules, needs deployment guides and CLI reference
- **End-user** - Consumes modules, needs getting started and conceptual guides
- **Contributor** - Extends OPM, needs architecture and design docs

## Documentation Style

### Box-Drawing Diagrams and ASCII Art

**Symbols for Yes/No in Tables and Diagrams**

When creating box-drawing tables or ASCII art diagrams in markdown code blocks, use **monospace-safe** symbols that render consistently across all terminals, editors, and GitHub.

**DO NOT USE** Unicode checkmarks (`✓` U+2713, `✗` U+2717) — these are ambiguous-width characters that break alignment in monospace fonts.

**Recommended Replacements:**

| Context | Yes | No | Example |
|---------|-----|-----|---------|
| **Box-drawing table cells** | `[x]` | `[ ]` | `│ No CRDs req. │  [x]   │  [ ]   │` |
| **Bullet-style property lists** | `[x]` | `[ ]` | `│    [x] Same resources → same digest` |
| **Inline after text** | `OK` | `FAIL` | `Apply: SS/jellyfin-media OK, Svc/jellyfin-media FAIL` |
| **Section headings** | `[x]` | `[ ]` | `### Scenario A: Normal Rename [x]` |
| **Parenthetical notes** | `ok` | `fail` | `Label check: "opm" (3 ok), name (≤63 ok)` |

**Rationale:**

1. **`[x]` / `[ ]`** - Checkbox-style brackets are exactly 3 ASCII characters wide, easy to align in tables
2. **`OK` / `FAIL`** - More readable mid-sentence than brackets
3. **`ok` / `fail`** - Lowercase variant for lightweight inline use

**Table Alignment Example:**

```text
┌──────────────┬────────┬────────┬────────┐
│ Feature      │ Schema │ CLI    │ Guide  │
├──────────────┼────────┼────────┼────────┤
│ Auto-gen     │  [x]   │  [x]   │  [ ]   │  ← 3 chars each, properly aligned
│ Cross-refs   │  [x]   │  [ ]   │  [ ]   │
└──────────────┴────────┴────────┴────────┘
```

**Why This Matters:**

- Unicode `✓` renders as 1 cell in some fonts, 2 cells in others (especially CJK locales)
- Broken alignment makes diagrams unreadable in terminals
- GitHub code blocks don't always match terminal rendering
- ASCII/bracket combinations are universally safe

## Implementation Status

See [README.md](README.md) for current implementation status and next steps.

## References

- [RFC-0006: Documentation Generation](https://github.com/open-platform-model/cli/blob/main/docs/rfc/0006-documentation-generation.md)
- [CUE Go API Documentation](https://pkg.go.dev/cuelang.org/go/cue)
- [Hugo Content Adapters](https://gohugo.io/content-management/content-adapters/)
- [cobra/doc package](https://pkg.go.dev/github.com/spf13/cobra/doc)
