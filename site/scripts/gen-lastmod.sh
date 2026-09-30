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
# Manifest mode (.versions/versions.tsv exists and OPM_VERSIONS is unset): the
# dates come from .versions/<version>/lastmod.tsv, which materialise.sh wrote
# on the host, where git works in a worktree; this runs no git. Explicit mode
# (OPM_VERSIONS set, or no versions.tsv): git log per page, here in the
# container. Either way it walks every mounted page, and a page without a date
# is counted and printed: in explicit mode git cannot answer for a worktree
# (its .git file points at a host path the container does not mount), a
# shallow clone, or a tree that is not a git repo (the fixtures); in manifest
# mode a page that is not committed yet has no row. With OPM_REQUIRE_DATES=1
# (CI) every page without a date fails the build.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
mkdir -p data/opm
tmp=$(mktemp); miss=$(mktemp); trap 'rm -f "$tmp" "$miss"' EXIT
if [ -z "${OPM_VERSIONS:-}" ] && [ -f .versions/versions.tsv ]; then mode=manifest; else mode=explicit; fi

dates() { # $1 dir, $2 key prefix, $3 version
  [ -d "$1" ] || return 0
  if [ "$mode" = manifest ]; then
    # Every page's key, joined with the version's host-side rows.
    (cd "$1" && find . -type f -name '*.md') | sed 's|^\./||' | sort | awk -F'\t' -v P="$2" -v V="$3" -v T=".versions/$3/lastmod.tsv" '
      BEGIN { while ((getline l < T) > 0) { split(l, f, "\t"); d[f[1]] = f[3] } }
      { k = P "/" $0; if (k in d) print k "\t" V "\t" d[k]; else print k " (version " V ")" > "/dev/stderr" }' >> "$tmp" 2>> "$miss"
    return 0
  fi
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
echo "gen-lastmod: $(wc -l < "$tmp" | tr -d ' ') dates, $(wc -l < "$miss" | tr -d ' ') pages without a git date ($mode mode)"
if [ -s "$miss" ] && [ "${OPM_REQUIRE_DATES:-0}" = 1 ]; then
  sed 's/^/  no git date: /' "$miss"
  echo "gen-lastmod: FAILED, OPM_REQUIRE_DATES=1 and $(wc -l < "$miss" | tr -d ' ') pages have no git date"
  exit 1
fi
