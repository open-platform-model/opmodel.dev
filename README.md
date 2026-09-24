# opmodel.dev

Documentation site for the Open Platform Model, built with Astro, Starlight and the [Black](https://github.com/adrian-ub/starlight-theme-black) theme.

## Overview

This repository contains:

- **`cmd/docgen/`** - Go tool for generating documentation from CUE definitions and CLI commands
- **`internal/`** - Internal packages for CUE schema extraction and cobra doc generation
- **`site/`** - Astro site: content, component overrides, version build scripts, and the Docker build image

The documentation pipeline extracts high-fidelity schema information from the [catalog](https://github.com/open-platform-model/catalog) CUE definitions and CLI command metadata from the [cli](https://github.com/open-platform-model/cli) to produce a comprehensive, searchable documentation site.

## Architecture

```
CUE Catalog → docgen schema → JSON → Astro content loader (planned) → Static site
CLI Commands → docgen cli → Markdown → Starlight → Static site
Hand-written guides → Starlight → Static site
```

Each site version is built on its own under `/<version>/`, from the content listed for it in `site/versions.config.mjs`. A version switch in the header keeps the reader on the same page when it exists in the other version, and pages in older versions carry a banner pointing at the latest.

See [RFC-0006](https://github.com/open-platform-model/cli/blob/main/docs/rfc/0006-documentation-generation.md) for the full design.

## Prerequisites

- Go 1.22+ (for `docgen`)
- Docker (the site's Node toolchain and npm packages live only in its build image)
- [Task](https://taskfile.dev/)

## Quick Start

```bash
# Install Go dependencies
task deps

# Build the docgen tool
task build:docgen

# Generate documentation (requires ../catalog to exist)
task generate

# Start the dev server (latest version, live reload) on http://localhost:4321/
task serve

# Build every version, then serve them all on http://localhost:4321/
task build
task preview
```

The site is built to `site/dist/`. The first run builds the Docker image, which takes about a minute.

## Directory Structure

```
opmodel.dev/
├── cmd/docgen/            # Documentation generator tool
├── internal/
│   ├── cuedoc/            # CUE schema extraction
│   └── cobradoc/          # Cobra CLI doc generation
├── site/                  # Astro + Starlight site
│   ├── Dockerfile              # Build image
│   ├── astro.config.mjs
│   ├── versions.config.mjs     # Site versions and their content sources
│   ├── content/                # Authored pages
│   │   ├── index.mdx           # Landing page
│   │   └── docs/
│   │       ├── getting-started/
│   │       ├── guides/
│   │       └── reference/
│   │           ├── definitions/    # Generated from CUE (planned)
│   │           └── cli/            # Generated from cobra (planned)
│   ├── scripts/                # Version prepare, stage, build and serve
│   ├── src/                    # Version switch and banner overrides
│   └── data/
│       └── schema/             # Generated JSON
├── Taskfile.yml
└── README.md
```

## Tasks

```bash
task deps              # Install Go dependencies
task image             # Build the site's Docker build image
task build:docgen      # Build the docgen tool
task generate:schema   # Generate schema JSON from catalog
task generate:cli      # Generate CLI reference markdown
task generate          # Generate all documentation
task serve             # Dev server for the latest version
task build             # Build every site version into site/dist/
task preview           # Serve the built site, every version
task clean             # Clean generated files
task fmt               # Format Go code
task vet               # Vet Go code
task test              # Run tests
task check             # Run all checks
```

## Implementation Status

- [x] Repository scaffolded
- [x] Go module initialized
- [x] Astro + Starlight site with the Black theme, built in Docker
- [x] Versioned builds with a version switch and an outdated-version banner
- [x] Taskfile build pipeline
- [x] Basic content pages
- [ ] `docgen schema` implementation (CUE extraction)
- [ ] `docgen cli` implementation (cobra doc generation)
- [ ] Astro content loader for the generated schema JSON
- [ ] Components for definition rendering
- [ ] Real site versions from the source repositories' tags (`versions.config.mjs` holds a demo entry)
- [ ] CI/CD pipeline
- [ ] Deployment to opmodel.dev

## Contributing

See the main [OPM documentation](https://github.com/open-platform-model) for contribution guidelines.

## License

Apache 2.0
