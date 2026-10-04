#!/bin/sh
# The "Last updated" dates of the site-owned pages (site/content/), on the
# host, before the build container starts (run-in-image.sh build and serve,
# and the two-version test, run it). git cannot read a worktree's history
# inside the container (its .git file names a host path the container does
# not mount), so the build's only git call happens here, on this repository
# alone: every other page is a docs bundle page, dated by its manifest
# (opm/source.html). POSIX sh, git and jq.
#
#   gen-site-dates.sh
#
# Writes site/data/opm/lastmod.json:
#   { "opmodel.dev/site/content/<path>": "<ISO date of the last commit that touched it>", ... }
# A page git cannot date (not committed yet) gets no key. A shallow clone
# gets no key at all: there git would date every page by the one commit it
# has, a wrong date that looks right. check-site-dates.sh, in the build,
# counts the pages without a key and, with OPM_REQUIRE_DATES=1 (CI, whose
# checkout fetches the full history), fails the build.
set -eu
SITE=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$SITE"
mkdir -p data/opm
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null || echo false)" = true ]; then
  echo '{}' > data/opm/lastmod.json
  echo "gen-site-dates: this is a shallow clone, whose history cannot date a page; no site-owned page is dated (fetch the full history: git fetch --unshallow)"
  exit 0
fi
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
find content -type f -name '*.md' | sort | while IFS= read -r f; do
  d=$(git -c log.showSignature=false log -1 --format=%cI -- "$f" 2>/dev/null || true)
  [ -z "$d" ] || printf '%s\t%s\n' "opmodel.dev/site/$f" "$d"
done > "$tmp"
jq -R -s '[split("\n")[] | select(length > 0) | split("\t") | {key: .[0], value: .[1]}] | from_entries' "$tmp" > data/opm/lastmod.json
n=$(grep -c . "$tmp" || true); total=$(find content -type f -name '*.md' | wc -l | tr -d ' ')
echo "gen-site-dates: $n of $total site-owned pages dated, $((total - n)) without a git date"
