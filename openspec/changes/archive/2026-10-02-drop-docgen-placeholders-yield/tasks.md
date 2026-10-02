# Tasks: drop-docgen-placeholders-yield

## 1. docgen

- [x] 1.1 Delete `cmd/`, `internal/`, `go.mod`, `go.sum` and the docgen checksum; drop `deps`, `build:docgen`, `generate*`, `fmt`, `vet`, `test`; `check` runs `openspec:check`.
- [x] 1.2 Drop `setup-go` from `site.yml`.
- [x] 1.3 README, AGENTS, CONSTITUTION, TODO, `openspec/config.yaml` and the `deploy-site` orchestration stop describing docgen and RESERVED.

## 2. Placeholders

- [x] 2.1 `gen-mounts.sh` excludes a yielded placeholder from the content mount, per version.
- [x] 2.2 `check-pages.sh` replaces RESERVED with the placeholder rule in A1.
- [x] 2.3 The two Reference stubs carry `placeholder: true`.
- [x] 2.4 Fixture: the fixture cli publishes `reference/cli/_index.md`; `test-site.sh` asserts it replaces the placeholder and definitions keeps its own; the reserved-prefix case is removed.
- [x] 2.5 `task build`, `task test:site`, `task check` and `task ci:lint` pass.
