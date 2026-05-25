# opmodel.dev repository guide

> **UNDER HEAVY DEVELOPMENT** — Active dev, APIs may change.

## Purpose

Documentation site for Open Platform Model. Hugo + custom Go tool (`docgen`) generates reference docs from CUE definitions (in `core/`, `catalog/`) and CLI commands (in `cli/`). Public-facing site at opmodel.dev.

## Repository Rules

- `CONSTITUTION.md` defines design principles for the project; this repo follows the Open Platform Model Constitution.
- Hugo 0.146.0+ required for content adapter (`_content.gotmpl`) support.
- Docsy theme currently disabled (i18n format incompatibility) — re-enable after upstream fix or switch to Hugo Book theme.
- Generated content under `site/data/schema/` is gitignored — never hand-edit; regenerate via `docgen`.

## Entrypoint

Read these on entry:

- `CLAUDE.md` — repo working rules (this file).
- `CONSTITUTION.md` — design principles.
- `README.md` — implementation status + next steps.
- `Taskfile.yml` — authoritative build/generate/serve entrypoints.
- [RFC-0006: Documentation Generation](https://github.com/open-platform-model/cli/blob/main/docs/rfc/0006-documentation-generation.md) — the design behind docgen.

## Repository Layout

```text
├── adr/                   # Architecture Decision Records
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

## Environment Notes

- **Go**: `1.22+` for the `docgen` tool.
- **Hugo**: `0.146.0+` extended version (SCSS + content adapter support).
- **Hugo Modules**: dependency management (Docsy theme — currently disabled).

## Build And Dev Commands

- `task build:docgen` — build docgen tool (output: `./bin/docgen`).
- `task generate:schema` — generate schema docs from CUE.
- `task generate:cli` — generate CLI docs from cobra.
- `task generate` — generate all.
- `task serve` — serve site locally.
- `task build` — build production site (output: `./public/`).
- `task clean` — remove build artifacts.
- `task fmt` — format Go code.
- `task vet` — run `go vet`.
- `task test` — run tests.
- `task check` — fmt + vet + test.

## Coding Standards

### Go style

- `gofmt`, `golangci-lint` compliant.
- Imports: stdlib → external → internal, blank lines between groups.
- Errors: wrap with context (`fmt.Errorf("extracting schema: %w", err)`).
- Interfaces: accept interfaces, return concrete structs.
- Context: propagate `context.Context` in all APIs.
- Tests: table-driven, `testify` assertions.

### Technology stack

- **docgen**: Go 1.22+, `cuelang.org/go` (native CUE eval), `cobra` + `cobra/doc` (CLI ref).
- **Site**: Hugo 0.146.0+ extended, Docsy theme (disabled), `_content.gotmpl` for programmatic page generation.
- **CUE Go APIs used**: `load.Instances()`, `Value.Doc()`, `Value.Fields()`, `Value.Default()`, `Value.IncompleteKind()`, `Value.Expr()`.

### Patterns

- **CUE doc extraction**: load modules via `load.Instances()` → walk defs with `Value.Fields(cue.Definitions(true))` → extract doc comments → resolve cross-refs (e.g. Trait `appliesTo` Resources) → output structured JSON per module.
- **CLI doc generation**: import CLI root as Go dep → `cobra/doc.GenMarkdownTreeCustom()` with Hugo front matter prepender → one markdown file per command.
- **Hugo content generation**: `docgen` outputs JSON to `site/data/schema/` + markdown to `site/content/reference/cli/` → content adapter reads JSON → custom shortcodes render type tables, cross-refs, constraints.

### Documentation style (box-drawing diagrams + ASCII art)

Use **monospace-safe** symbols in box-drawing tables/ASCII art. Must render consistently across terminals, editors, GitHub.

**DO NOT USE** Unicode checkmarks (`✓` U+2713, `✗` U+2717) — ambiguous-width chars that break monospace alignment.

| Context | Yes | No |
|---|---|---|
| Box-drawing table cells | `[x]` | `[ ]` |
| Bullet-style property lists | `[x]` | `[ ]` |
| Inline after text | `OK` | `FAIL` |
| Section headings | `[x]` | `[ ]` |
| Parenthetical notes | `ok` | `fail` |

Rationale: `[x]`/`[ ]` are 3 ASCII chars wide, easy table alignment. `OK`/`FAIL` more readable mid-sentence. Unicode `✓` renders 1 cell in some fonts, 2 in others (especially CJK locales) — broken alignment makes diagrams unreadable in terminals.

## Working Style for Agents

- Update the Project Structure tree above when adding new packages/directories.
- Don't edit generated content (`site/data/schema/*`, `site/content/reference/cli/*`) — regenerate via `task generate`.
- Schema source lives upstream in `core/` (and `catalog/`); CLI command source lives in `cli/`. Doc bugs that trace to source — fix upstream, not by patching generated output.
- Personas to keep in mind when writing docs: **Module Author** (writes CUE defs, primary audience for ref docs), **Platform Operator** (deploys modules, needs deployment guides + CLI ref), **End-user** (consumes modules, needs getting started + conceptual guides), **Contributor** (extends OPM, needs architecture + design docs).
- For OPM-specific terms, link to the [canonical glossary in opm/](https://github.com/open-platform-model/opm/blob/main/docs/glossary.md) — don't duplicate definitions here.
