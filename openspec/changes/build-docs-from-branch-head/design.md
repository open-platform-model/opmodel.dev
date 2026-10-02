## Context

`resolve-versions.sh` resolves a line version in `resolve_line`. cli comes from the newest tag
of `cli-line`; library, core and opm-operator from that tag's pins (`resolve_pins`, which reads
cli `go.mod`, cli `internal/operator/manifest.go` and library `opm/schema/loader.go` at the
release SHAs). Only core (and catalog_opm) then go through `release_docs`, which picks the docs
tree with `docs_source` and checks it with `release_problems`. cli, library and opm-operator
are checked with `check_ref` and built at their tag.

All five released repositories tag `vX.Y.Z[-pre]` without a prefix (catalog_opm uses `opm-`),
so `docs_source` and `release_docs` already work for cli, library and opm-operator unchanged.
None of the three has a `release/*` branch today, and each `main` still releases `v1.0`, so
their docs resolve to `main`'s head (rule 2).

Files under `site/` touched: `scripts/resolve-versions.sh`, `tests/versions/test-resolve.sh`,
`versions.conf` (comment). Outside `site/`: `.github/workflows/site.yml` (comment), `AGENTS.md`,
`README.md`. No layout, override, mount, vendored file or pinned tool changes. The layouts
(`_partials/opm/source.html`, `_partials/opm/build-stamp.html`) already treat any row whose
`docs` is `main` or `release/*` as a branch (edit link to that branch, stamp shows branch and
commit), so they need no change.

## Goals / Non-Goals

**Goals:**

- A docs-only merge to cli, library or opm-operator reaches the published site at the next
  build, with no release, exactly as one to core or catalog_opm does.
- The stamp keeps naming the releases, and every pin keeps being read at a release.

**Non-Goals:**

- Generating the CLI reference (docgen `cli` is still a stub; that is the generated-reference
  change).
- Changing the anchored kind, overrides, the `sources-main` job or the version set.
- Settling how the docs are versioned against releases (0021:OQ15).

## Decisions

### One docs rule for every released repository

`resolve_line` sends cli, library and opm-operator through `release_docs`, the function core
already uses, with the empty tag prefix:

```sh
# cli: csha stays the tag, where resolve_pins reads the pins
release_docs cli "" "$cref" "$csha" "newest tag of line $cl"
report "$lv" cli "" "$rd_problems"
[ -z "$rd_sha" ] || lrow cli "$cref" "$rd_sha" "line:newest $cl.* tag; docs: $rd_rule" "$rd_docs"

# library, opm-operator, core: one branch instead of core-only plus check_ref
release_docs "$r" "" "$ref" "$sha" "$rule"
report "$lv" "$r" "" "$rd_problems"
[ -z "$rd_sha" ] || lrow "$r" "$ref" "$rd_sha" "$how; docs: $rd_rule" "$rd_docs"
```

`release_problems` then applies to all five: the release the stamp names must contain its
floor, and a branch head the docs come from must contain that release. The override "no longer
needed" test for a replaced library or opm-operator row uses `release_docs` too, as core's does.

Alternative considered: a per-repository switch in `versions.conf` (`docs-from = head`). Rejected
(Principle V): every released repository now has the same release policy for docs, so a single
rule is simpler than a key nobody would set differently.

### Pins stay at the releases

`resolve_pins` runs before `release_docs` and reads at `csha` (the cli tag) and the library
release SHA. `release_docs` only sets `rd_*`, so moving the cli and library docs trees cannot
move a pin. The test `line-cli-main` proves it: cli `main` pins library v2.3.0 while the tag
pins v2.1.0, and the row is v2.1.0.

### A cli frozen by its docs SHA

`frozen.conf` must rebuild the same six trees. A cli row whose docs are not its tag freezes as
`cli = <docs SHA>`, preceded by a comment naming the release (`; cli v1.0.0-beta.5, docs main`).
An anchored version reads no pin when library, core and opm-operator are all overridden, which
`freeze` always writes, so the anchor's pins at that SHA are never consulted. library and
opm-operator rows freeze by SHA like core's (`frozen from line <tag>, docs <branch>`).

Alternative considered: freeze `cli = <tag>` plus a new docs-tree key. Rejected: a new grammar
key for the recovery path only, while the SHA already reproduces the build.

### The generated CLI reference follows the released cli

When docgen generates the CLI reference, it MUST generate from the cli release the stamp names
(the row's `ref`, a tag), never from the docs tree (`sha`). The reference documents the binary a
reader installs; a command merged to `main` but not released would otherwise appear in the
reference of a version that cannot run it. The hand-written cli pages move to the docs head;
the generated reference does not. This lands in AGENTS.md now, because nothing enforces it
until the generated-reference change exists.

## Research & Decisions

### Can the existing docs rule serve cli, library and opm-operator?

**Context**: core's rule was written for core and catalog_opm.
**Explored**: tag naming in the six repositories (`git tag -l`: cli, library and opm-operator
tag `v1.0.0-beta.N` with no prefix, like core) and remote branches (no `release/*` in any of
the three). Ran the patched resolver on the real roots: all six rows resolve, cli, library and
opm-operator docs at `main` head with rule "main still releases v1.0", and `--freeze` followed
by `--check` of the frozen block resolves the same six SHAs (`test-resolve.sh`
`real-line-frozen`).
**Decision**: reuse `release_docs` with the empty prefix.
**Rationale**: no new code path, and the containment and floor checks come for free.

## Risks / Trade-offs

- [The site documents unreleased behaviour: `main` of cli, library or opm-operator may carry
  merged but unreleased features] -> Same trade-off core and catalog_opm already make. A repo
  that needs its docs to match a release cuts `release/vX.Y`, and the rule reads that branch.
- [When `main` moves to the next minor without a `release/v1.0` branch, rule 3 falls back to
  the release tag, and the docs lag returns for `v1.0`] -> Cut `release/v1.0` when `main` leaves
  the line; the README docs rule says so.
- [A cli docs head that fails a check (no `docs/site`, a branch that misses the release) now
  fails the line, where before only the tag was checked] -> Recovery is unchanged: anchor at the
  last good `frozen.conf` block. A docs fix on `main` repairs it without a release.
- [A frozen cli is a SHA, so a future generated reference built from a frozen version would see
  a docs SHA, not the tag] -> The comment line names the release; the generated-reference
  change must read it or freeze differently (open question).

## Durable decisions

- In a line version, the docs of every released repository (cli, library, opm-operator, core,
  catalog_opm) follow one docs rule; the stamp names the release and pins are read at releases.
  Lands in `AGENTS.md` (Site versions) and `README.md` (Site versions).
- A generated CLI reference is generated from the cli release the stamp names (`ref`), never
  from the docs tree. Lands in `AGENTS.md` (Reserved sections).
- A cli frozen from a line whose docs are not its tag is frozen by SHA with a comment naming
  the release. Lands in `README.md` (Site versions, frozen manifest paragraph).

## Open Questions

- How the generated-reference change finds the cli release in an anchored version frozen from
  a line (read the `; cli <tag>` comment, or freeze a separate key). It does not change this
  change's approach.
