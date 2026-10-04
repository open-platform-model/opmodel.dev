#!/bin/sh
# The "Last updated" dates of the site-owned pages (site/content/), on the
# host, before the build container starts (run-in-image.sh build and serve,
# and the two-version test, run it). git cannot read a worktree's history
# inside the container (its .git file names a host path the container does
# not mount), so the build's only git call happens here, on this repository
# alone: every other page is a docs bundle page, dated by its manifest
# (opm/source.html). POSIX sh and git.
#
#   gen-site-dates.sh
#
# Writes site/data/opm/lastmod.json:
#   { "opmodel.dev/site/content/<path>": "<ISO date of the last commit that touched it>", ... }
# A page git cannot date (not committed yet, or a shallow clone without its
# history) gets no key; check-site-dates.sh, in the build, counts it and,
# with OPM_REQUIRE_DATES=1 (CI), fails the build.
set -eu
SITE=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$SITE"
mkdir -p data/opm
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
n=0; miss=0
for f in $(find content -type f -name '*.md' | sort); do
  d=$(git log -1 --format=%cI -- "$f" 2>/dev/null || true)
  if [ -n "$d" ]; then printf '%s\t%s\n' "opmodel.dev/site/$f" "$d" >> "$tmp"; n=$((n + 1)); else miss=$((miss + 1)); fi
done
jq -R -s '[split("\n")[] | select(length > 0) | split("\t") | {key: .[0], value: .[1]}] | from_entries' "$tmp" > data/opm/lastmod.json
echo "gen-site-dates: $n site-owned pages dated, $miss without a git date"
