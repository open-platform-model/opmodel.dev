# Design: drop-docgen-placeholders-yield

## Placeholders yield per version

The content mount is shared by every version. A placeholder yielded in some versions only is excluded from the shared mount and mounted again, alone, for the versions without a source page. With no placeholder yielded the mount is unchanged.

## Durable decisions

- The site generates no pages; generated reference lives in its owning repository. Recorded in `AGENTS.md`, `CONSTITUTION.md` (I-III) and `openspec/config.yaml`.
- A `placeholder: true` site page yields to a source page at its path, and is deleted once every version has one. Recorded in `AGENTS.md` (Placeholders) and the headers of `gen-mounts.sh` and `check-pages.sh`.
