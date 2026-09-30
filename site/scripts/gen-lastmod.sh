#!/bin/sh
# Last-updated dates from git, for pages Hugo mounts from other repos.
#
#   gen-lastmod.sh VERSION=ROOT [VERSION=ROOT ...]
#
# Hugo's GitInfo reads only the project's own repo and Hugo modules; plain
# directory mounts get nothing. This writes SITE_DIR/data/opm/lastmod.json:
#   { "<repo>/docs/site/<path>": {"<version>": "<ISO date>"}, ... }
# with the site-owned pages keyed "opmodel.dev/site/content/<path>".
#
# A page gets no date when git cannot answer: a worktree whose .git file
# points at a host path the container does not mount, a shallow clone, or a
# tree that is not a git repo (the fixtures). That is counted and printed;
# with OPM_REQUIRE_DATES=1 (CI) every page without a date fails the build.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
mkdir -p data/opm
tmp=$(mktemp); miss=$(mktemp); trap 'rm -f "$tmp" "$miss"' EXIT

dates() { # $1 dir, $2 key prefix, $3 version
  [ -d "$1" ] || return 0
  (cd "$1" && find . -type f -name '*.md') | sed 's|^\./||' | sort | while IFS= read -r f; do
    date=$(git -C "$1" log -1 --format=%cI -- "$f" 2>/dev/null || true)
    if [ -n "$date" ]; then printf '%s\t%s\t%s\n' "$2/$f" "$3" "$date" >> "$tmp"
    else printf '%s (version %s)\n' "$2/$f" "$3" >> "$miss"; fi
  done
}
for pair in "$@"; do
  v=${pair%%=*}; root=${pair#*=}
  dates "$SITE_DIR/content" opmodel.dev/site/content "$v"
  for r in $REPOS; do dates "$root/$r/docs/site" "$r/docs/site" "$v"; done
done

awk -F'\t' '
  { if (!($1 in seen)) { order[++n] = $1; seen[$1] = 1 } val[$1] = val[$1] (val[$1] ? "," : "") sprintf("\"%s\":\"%s\"", $2, $3) }
  END { printf "{\n"; for (i = 1; i <= n; i++) printf "  \"%s\": {%s}%s\n", order[i], val[order[i]], (i < n ? "," : ""); printf "}\n" }
' "$tmp" > data/opm/lastmod.json
echo "gen-lastmod: $(wc -l < "$tmp" | tr -d ' ') dates, $(wc -l < "$miss" | tr -d ' ') pages without a git date"
if [ -s "$miss" ] && [ "${OPM_REQUIRE_DATES:-0}" = 1 ]; then
  sed 's/^/  no git date: /' "$miss"
  echo "gen-lastmod: FAILED, OPM_REQUIRE_DATES=1 and $(wc -l < "$miss" | tr -d ' ') pages have no git date"
  exit 1
fi
