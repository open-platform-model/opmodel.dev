## Why

A line version builds the docs of core and catalog_opm from their release-branch head (from
`main` while `main` still releases the line), but the docs of cli, library and opm-operator from
the exact release the cli line pins. Today that works only because a docs-only commit in those
three repositories cuts a release. The release cascade hides the `docs` changelog section in
library, opm-operator and cli, so a docs-only merge there stops releasing (owner decision
2026-10-01, workspace RELEASING.md, "Pin classes"). After that, a docs fix in those three would
reach opmodel.dev only with the next unrelated release, and for library and opm-operator only
after a cli release that bumps the pin as well. The owner decided on 2026-10-02 to close that
gap here, before the docs-hiding sections of the three `prepare-release-cascade` changes merge.

## What Changes

- `site/scripts/resolve-versions.sh`: in a line version, the docs of cli, library and
  opm-operator follow the same docs rule as core and catalog_opm (release branch head, else
  `main`'s head while `main` still releases the line, else the release's own tag). The stamp
  still names the release (`ref`), and every pin is still read at the release tags, never at a
  docs head. The containment and floor checks that guard core and catalog_opm now guard all five.
- `--freeze`: a cli row whose docs are not its tag freezes by the SHA of its docs tree, with a
  comment line naming the release the stamp named.
- `site/tests/versions/test-resolve.sh`: the line cases cover the docs rule for cli, library and
  opm-operator (a release branch, `main`'s head, a tag) and the frozen round trip of a cli docs
  head.
- Comments and docs: `site/versions.conf`, `.github/workflows/site.yml`, `AGENTS.md` and
  `README.md` state the rule for all five repositories, and that a generated CLI reference
  follows the released cli, not the docs head.

No published URL, page, version or theme override changes. The pages of `/v1.0/` built from
cli, library and opm-operator move from their release tags to their `main` heads (today none of
the three has a release branch).

## Before / After

**Before** (`resolve-versions.sh --check`, v1.0 rows; `how` shortened)

```text
repo          ref            tree built (sha)        docs
cli           v1.0.0-beta.5  the tag                 tag
library       v1.0.0-beta.1  the tag                 tag
opm-operator  v1.0.0-beta.4  the tag                 tag
core          v2.0.0-beta.1  origin/main head        main
catalog_opm   opm-v4.4.4     origin/main head        main
opm           main           origin/main head        main
```

**After**

```text
repo          ref            tree built (sha)        docs
cli           v1.0.0-beta.5  origin/main head        main    ; how: line:newest v1.0.* tag; docs: main head (...)
library       v1.0.0-beta.1  origin/main head        main    ; how: pin:cli go.mod; docs: main head (...)
opm-operator  v1.0.0-beta.4  origin/main head        main    ; how: pin:cli internal/operator/manifest.go; docs: main head (...)
core          v2.0.0-beta.1  origin/main head        main
catalog_opm   opm-v4.4.4     origin/main head        main
opm           main           origin/main head        main
```

`frozen.conf`, before and after:

```ini
; before                              ; after
cli = v1.0.0-beta.5                   ; cli v1.0.0-beta.5, docs main
                                      cli = <cli main SHA>
override = library v1.0.0-beta.1 ...  override = library <library main SHA> frozen from line v1.0.0-beta.1, docs main
```

## Impact

- Files: `site/scripts/resolve-versions.sh`, `site/tests/versions/test-resolve.sh`,
  `site/versions.conf` (comment only), `.github/workflows/site.yml` (comment only), `AGENTS.md`,
  `README.md`. The build gains no input: the same six roots, the same refs fetched.
- Source repositories: none has to change a page. cli, library and opm-operator page fixes now
  reach the site at the next build from their `main` (or a future `release/vX.Y`), as core's and
  catalog_opm's do. Their `prepare-release-cascade` changes depend on this one: their
  docs-hiding sections should merge only after it.
- Published versions: `/v1.0/` (and `/latest/`) only; its stamp shows the three rows at a branch
  commit (`cli main abc1234`) instead of the tag, as core's and catalog_opm's already do.
  Documentation versioning stays 0021:OQ15; this change does not settle it.
- Depends on: nothing.

## Enhancement

None. The source is the owner decision of 2026-10-02 recorded with the release cascade
(workspace RELEASING.md, "Pin classes" and "Rollout and changes").
