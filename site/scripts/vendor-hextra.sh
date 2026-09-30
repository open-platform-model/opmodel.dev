#!/bin/sh
# Vendor the Hextra theme into site/themes/hextra, runtime files only.
# Host side, git only (no Go, no npm): a shallow clone of the tag into a
# scratch directory outside the repo, refused unless the tag resolves to the
# pinned commit. Re-runnable; it replaces site/themes/hextra and rewrites
# site/themes/hextra.COMMIT.
#
#   sh site/scripts/vendor-hextra.sh [TAG SHA]     default: v0.13.0 adf732f...
#
# Only the runtime tree is copied. Upstream's agent files (CLAUDE.md, a
# symlink to AGENTS.md, and AGENTS.md tell agents to run npm install), its npm
# and Go tooling, examples and READMEs are never vendored.
#
# After a re-vendor, run the build: site/scripts/check-overrides.sh names every
# theme file an override copies that changed upstream. Diff it, merge the hunk
# into the override, then re-pin with check-overrides.sh --update.
set -eu
TAG=${1:-v0.13.0}
SHA=${2:-adf732f8d97cb8e149d4aba232a449d41cd9e38c}
URL=https://github.com/imfing/hextra
RUNTIME="layouts assets static i18n data theme.toml hugo.toml LICENSE"

site=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/vendor-hextra.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$TAG" "$URL" "$scratch/hextra"
head=$(git -C "$scratch/hextra" rev-parse HEAD)
if [ "$head" != "$SHA" ]; then
  echo "vendor-hextra: $TAG resolves to $head, not the pinned $SHA; refusing" >&2
  exit 1
fi
for p in $RUNTIME; do
  [ -e "$scratch/hextra/$p" ] || { echo "vendor-hextra: $p is missing upstream at $TAG" >&2; exit 1; }
done

dest=$site/themes/hextra
rm -rf "$dest"
mkdir -p "$dest"
for p in $RUNTIME; do cp -R "$scratch/hextra/$p" "$dest/"; done
printf '%s %s %s\n' "$TAG" "$SHA" "$URL" > "$site/themes/hextra.COMMIT"
echo "vendor-hextra: $TAG ($SHA) -> site/themes/hextra ($(find "$dest" -type f | wc -l | tr -d ' ') files)"
