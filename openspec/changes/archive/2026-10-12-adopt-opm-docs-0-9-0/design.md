## Context

`opm-docs` 0.9.0 reads the OpenSpec layout and refuses a live old-layout folder ("entry 0000 is a live old-layout folder"). The v2 fixture bundle was built by an unreleased `opm-docs` (`0.0.0-dev`) and overlaid on the pulled fixture, because the pinned tool could not re-pull it. The pin now reads v2, which is the step the header of `regen-enhancements-v2.sh` planned.

## Research & Decisions

### Fixture source
**Context**: the old source had live legacy entries 0000 and 0001.
**Explored**: building the v2 source with 0.9.0 reproduces `bundles-v2/enhancements/edge/` byte for byte, except `manifest.json` `tool` and the by-hand progress of 0042.
**Decision**: use the v2 source as `ws/enhancements/`; keep the old 0001 and 0002 as `archive/0001` and `archive/0002`; drop the 0000 template.
**Rationale**: the cross-links, anchors, Mermaid fences, stripped comments and the draft banner that tests read stay covered, with the least test change. 0.9.0 accepts a legacy entry only under `archive/`.

### Progress of 0042
**Context**: the draft 0042 carries tasks in its data (1 of 4) to prove a draft shows no Progress row, but its source has no `tasks.md`.
**Decision**: `regen-enhancements.sh` sets it with `jq` after the build.
**Rationale**: a `tasks.md` would add a page and change the page counts; the regen stays reproducible.

### Tests
**Decision**: the `enhancements-v2` build case is renamed `enhancements-openspec` and loses the overlay. Page counts read 60 expected, 66 built (6 alias stubs).

## Files and inputs

The build gains no input and loses the v2 overlay helper `use_enhancements_v2`. The pinned tool changes in `site/Dockerfile`.

## Risks / Trade-offs

- No schema v1 fixture remains -> accepted; the pinned tool cannot write one.
- A wrong checksum -> the image build fails, nothing else.

## Durable decisions

- The fixture source holds OpenSpec-layout entries and archived legacy entries only -> `AGENTS.md` and `README.md`.
