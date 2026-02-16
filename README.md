# opmodel.dev

Documentation site for the Open Platform Model, built with Hugo and the Docsy theme.

## Overview

This repository contains:

- **`cmd/docgen/`** - Go tool for generating documentation from CUE definitions and CLI commands
- **`internal/`** - Internal packages for CUE schema extraction and cobra doc generation
- **`site/`** - Hugo site source with content, layouts, and configuration

The documentation pipeline extracts high-fidelity schema information from the [catalog](https://github.com/open-platform-model/catalog) CUE definitions and CLI command metadata from the [cli](https://github.com/open-platform-model/cli) to produce a comprehensive, searchable documentation site.

## Architecture

```
CUE Catalog → docgen schema → JSON → Hugo content adapters → Static site
CLI Commands → docgen cli → Markdown → Hugo → Static site
Hand-written guides → Hugo → Static site
```

See [RFC-0006](https://github.com/open-platform-model/cli/blob/main/docs/rfc/0006-documentation-generation.md) for the full design.

## Prerequisites

- Go 1.22+
- Hugo 0.126.0+ (extended version for SCSS support)
- [Task](https://taskfile.dev/) (optional, for build automation)

## Quick Start

```bash
# Install dependencies
task deps

# Build the docgen tool
task build:docgen

# Generate documentation (requires ../catalog to exist)
task generate

# Start development server
task serve

# Build production site
task build
```

The site will be built to `./public/`.

## Directory Structure

```
opmodel.dev/
├── cmd/docgen/            # Documentation generator tool
├── internal/
│   ├── cuedoc/            # CUE schema extraction
│   └── cobradoc/          # Cobra CLI doc generation
├── site/                  # Hugo site source
│   ├── hugo.toml
│   ├── content/
│   │   ├── getting-started/
│   │   ├── guides/
│   │   └── reference/
│   │       ├── definitions/    # Generated from CUE
│   │       └── cli/            # Generated from cobra
│   ├── data/
│   │   └── schema/             # Generated JSON
│   ├── layouts/
│   └── static/
├── Taskfile.yml
└── README.md
```

## Tasks

```bash
task deps              # Install dependencies
task build:docgen      # Build the docgen tool
task generate:schema   # Generate schema JSON from catalog
task generate:cli      # Generate CLI reference markdown
task generate          # Generate all documentation
task serve             # Run Hugo dev server
task build             # Build production site
task clean             # Clean generated files
task fmt               # Format Go code
task vet               # Vet Go code
task test              # Run tests
task check             # Run all checks
```

## Implementation Status

- [x] Repository scaffolded
- [x] Go module initialized
- [x] Hugo site structure created
- [x] Taskfile build pipeline
- [x] Basic content pages
- [ ] `docgen schema` implementation (CUE extraction)
- [ ] `docgen cli` implementation (cobra doc generation)
- [ ] Hugo content adapter activated
- [ ] Custom shortcodes for definition rendering
- [ ] CI/CD pipeline
- [ ] Deployment to opmodel.dev

## Contributing

See the main [OPM documentation](https://github.com/open-platform-model) for contribution guidelines.

## License

Apache 2.0
