# Proposal: drop-docgen-placeholders-yield

## Why

The owner decided on 2026-10-02 that reference pages are generated in the repository that owns their source (cli, opm-operator, catalog_opm, core) and committed there. The site's `docgen` tool, which still read the retired v0 `../catalog`, has no job left. And the RESERVED check refuses exactly the pages cli and core are about to publish at `/docs/reference/cli/` and `/docs/reference/definitions/`.

## What Changes

- Remove `docgen`: `cmd/`, `internal/`, `go.mod`, `go.sum`, the Go and `generate*` tasks, and Go in CI. `task check` is `openspec:check`.
- Replace RESERVED with placeholders: a site page whose front matter holds `placeholder: true` yields to a source page at the same path. `gen-mounts.sh` leaves it out of the content mount in each version where a source page exists; `check-pages.sh` drops it from A1 there. The two Reference stubs become placeholders, so cli and core can merge in any order.
- README, AGENTS, CONSTITUTION, TODO and `openspec/config.yaml` stop describing `docgen`.

## Before / After

```text
Before                                       After
cmd/docgen, internal/, go.mod                (gone)
check: fmt, vet, openspec, test              check: openspec
RESERVED FAIL on a source page under         content/docs/reference/{cli,definitions}/_index.md
  docs/reference/{cli,definitions}/            placeholder: true -> yields to a source page
```

## Impact

Site pipeline only. A source page at a placeholder's path now publishes instead of failing the build.
