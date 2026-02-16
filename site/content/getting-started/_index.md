---
title: Getting Started
weight: 1
---

Welcome to the Open Platform Model documentation.

## What is OPM?

The Open Platform Model (OPM) is a declarative platform model for describing applications and their infrastructure requirements. It provides a type-safe, composable way to define:

- **Resources** - Deployable components like containers, volumes, and config
- **Traits** - Behaviors like scaling, health checks, and routing
- **Blueprints** - Patterns like stateless workloads, databases, and daemons
- **Modules** - Complete applications composed of components and policies

## Installation

```bash
# Install the OPM CLI
go install github.com/open-platform-model/cli/cmd/opm@latest

# Verify installation
opm version
```

## Your First Module

Create a new module:

```bash
opm mod init ./my-app
cd my-app
```

This generates a basic module structure with a sample component.

## Next Steps

- [Core Concepts](/docs/guides/core-concepts/) - Understand the OPM model
- [Module Authoring](/docs/guides/module-authoring/) - Write your first real module
- [CLI Reference](/docs/reference/cli/) - Explore CLI commands
- [Definition Reference](/docs/reference/definitions/) - Browse available definitions
