#!/bin/sh
# The two-version regression test (task versions:test runs it after
# versions:prepare with site/tests/versions/two-versions.conf, and restores
# the real manifest afterwards). Host side: POSIX sh, grep and awk.
#
# This test never writes site/public/, which CI uploads and the deploy
# publishes, nor the real build's site/.check/<version>/: it builds into
# site/.check/versions-test/public/ with its nav-order.txt files in
# site/.check/versions-test/check/ (build-all.sh --public, --check), and it
# fails if anything under site/public/ or site/.check/ outside versions-test/
# changed while it ran. It does overwrite the generated inputs every build
# shares (site/config/<env>/, site/data/opm/); the next build regenerates them.
#
#   sh site/tests/versions/check-two-versions.sh
#
# The build runs in the build image through run-in-image.sh's own functions
# (sourced with mode "tag", as in resolve-versions.sh), so it gets the same
# source roots, mounts and image as task build. Then every assertion prints
# "ok" or "FAIL"; any FAIL exits 1.
set -eu
export LC_ALL=C
# shellcheck disable=SC2166 # [ a -a b ] keeps each assertion on one line
TAB=$(printf '\t')
HERE=$(cd "$(dirname "$0")" && pwd -P)
SITE=$(cd "$HERE/../.." && pwd -P)
M=$HERE/two-versions.conf
OUT=$SITE/.check/versions-test
P=$OUT/public
C=$OUT/check
LOG=$OUT/build.log
REPOS="opm core catalog_opm cli library opm-operator"
pass=0; fail=0
ok() { echo "ok   $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail + 1)); }
check() { name=$1; shift; if "$@"; then ok "$name"; else bad "$name" "${why:-assertion false}"; fi; why=""; }
why=""

TSV=$SITE/.versions/versions.tsv
grep -q "^v0.9$TAB" "$TSV" 2>/dev/null || {
  echo "check-two-versions: $TSV does not hold v0.9; run versions:prepare with OPM_VERSIONS_MANIFEST=site/tests/versions/two-versions.conf first" >&2
  exit 1
}

# --- The build, into .check/versions-test/ ------------------------------------
mkdir -p "$OUT"
rm -rf "$P" "$C"
marker=$OUT/.started; : > "$marker"
unset OPM_VERSIONS
if ! sh -c '. "$0" >/dev/null
  sources; image >/dev/null
  # shellcheck disable=SC2086
  run --network none --env "OPM_BUILD_REFS=$REFS" $MOUNTS --entrypoint sh "$(tag)" \
    /work/repo/site/scripts/build-all.sh --public .check/versions-test/public --check .check/versions-test/check' \
  "$SITE/scripts/run-in-image.sh" tag > "$LOG" 2>&1; then
  tail -n 30 "$LOG"
  echo "check-two-versions: FAILED, the two-version build failed (log: $LOG)"
  exit 1
fi
grep -E '^(v[0-9.]+: [0-9]+ pages|build-all: OK)' "$LOG" | sed 's/^/build: /'

# --- Assertions -----------------------------------------------------------------
changed=$(find "$SITE/public" "$SITE/.check" -path "$OUT" -prune -o -newer "$marker" -print 2>/dev/null | head -n 5)
why="written while the test ran: $changed"
check "writes neither site/public/ nor site/.check/<version>/" [ -z "$changed" ]
why="site/public/v0.9 exists"
check "site/public/ holds no v0.9" [ ! -e "$SITE/public/v0.9" ]

check "both version directories exist" [ -d "$P/v1.0" -a -d "$P/v0.9" ]

switch_ok=1
for v in v1.0 v0.9; do
  got=$(tr '\n' ' ' < "$P/$v/docs/index.html" | grep -o 'opm-version-item[^>]*><span>[^<]*' | sed 's/.*<span>//' | tr '\n' '|')
  [ "$got" = "v1.0 (beta)|v0.9 (test)|" ] || { switch_ok=0; why="${why}$v lists \"$got\"; "; }
done
check "the switch lists both labels, v1.0 (beta) first, on both versions" [ $switch_ok = 1 ]

pages09=$(find "$P/v0.9/docs" -name '*.html' | sort)
missing_bar=$(for f in $pages09; do grep -q opm-outdated "$f" || echo "${f#"$P"/}"; done | head -n 3)
bar10=$(grep -rl opm-outdated "$P/v1.0" | head -n 3 || true)
why="no bar on: $missing_bar; a bar on: $bar10"
check "the outdated bar appears on every v0.9 docs page and on no v1.0 page" [ -n "$pages09" -a -z "$missing_bar" -a -z "$bar10" ]

why="missing pagefind/pagefind.js"
check "a Pagefind index per version" [ -f "$P/v1.0/pagefind/pagefind.js" -a -f "$P/v0.9/pagefind/pagefind.js" ]
why="empty or missing check/<v>/nav-order.txt"
check "a nav-order.txt per version, in .check/versions-test/check/" [ -s "$C/v1.0/nav-order.txt" -a -s "$C/v0.9/nav-order.txt" ]

why="robots.txt: $(tr '\n' ' ' < "$P/robots.txt")"
# shellcheck disable=SC2016 # $1 expands in the inner shell
check "robots.txt names both sitemaps" sh -c 'grep -qx "Sitemap: https://opmodel.dev/v1.0/sitemap.xml" "$1" && grep -qx "Sitemap: https://opmodel.dev/v0.9/sitemap.xml" "$1"' - "$P/robots.txt"
foreign=$(for v in v1.0 v0.9; do grep -o '<loc>[^<]*' "$P/$v/sitemap.xml" | grep -v "^<loc>https://opmodel.dev/$v/" | sed "s/^/$v: /"; done | head -n 3)
why="foreign URLs: $foreign"
check "each sitemap lists only its own version's URLs" [ -z "$foreign" -a -s "$P/v0.9/sitemap.xml" ]
check "each version has its own llms.txt and 404.html" [ -s "$P/v1.0/llms.txt" -a -s "$P/v0.9/llms.txt" -a -s "$P/v1.0/404.html" -a -s "$P/v0.9/404.html" ]
check "the root 404.html is v1.0's" cmp -s "$P/404.html" "$P/v1.0/404.html"

why="_redirects or a /latest/ stub does not point at v1.0"
# shellcheck disable=SC2016
check "_redirects and the /latest/ stubs point at v1.0" sh -c 'grep -qx "/latest/\* /v1.0/:splat 302" "$1/_redirects" &&
  grep -q "url=/v1.0/\"" "$1/latest/index.html" && grep -q "url=/v1.0/docs/\"" "$1/latest/docs/index.html"' - "$P"

# The test SHAs: v0.9's refs in the manifest (cli, catalog, opm, overrides).
sha_of() {
  case "$1" in
    cli) git config --file "$M" --get version.v0.9.cli ;;
    catalog_opm) git config --file "$M" --get version.v0.9.catalog ;;
    opm) git config --file "$M" --get version.v0.9.opm ;;
    *) git config --file "$M" --get-all version.v0.9.override | awk -v r="$1" '$1 == r { print $2 }' ;;
  esac
}
stamp=$(tr '\n' ' ' < "$P/v0.9/docs/index.html" | grep -o '<div class="\{0,1\}opm-build-stamp.*' | sed 's#</footer>.*##')
stamp_bad=""; view_bad=""
for r in $REPOS; do
  s=$(sha_of "$r")
  short=$(printf '%.7s' "$s")
  printf '%s' "$stamp" | grep -q "/$r/commit/$s" && printf '%s' "$stamp" | grep -q "<code>$short</code>" || stamp_bad="$stamp_bad $r"
  grep -rlq "github.com/open-platform-model/$r/blob/$s/docs/site/" "$P/v0.9" || view_bad="$view_bad $r"
done
why="the stamp misses:$stamp_bad"
check "the v0.9 stamp names the six test SHAs" [ -z "$stamp_bad" -a -n "$stamp" ]
why="no View source link at the test SHA for:$view_bad"
check "v0.9 View source links carry the test SHAs" [ -z "$view_bad" ]

edit09=$(grep -rl -e 'Edit this page' -e '/edit/main/' "$P/v0.9" | head -n 3 || true)
why="an edit link on: $edit09"
check "v0.9 pages have no Edit this page link" [ -z "$edit09" ]
noedit10=$(grep -rl opm-page-meta "$P/v1.0/docs" | while IFS= read -r f; do grep -q "Edit this page" "$f" || echo "${f#"$P"/}"; done | head -n 3)
why="no edit link on: $noedit10"
check "v1.0 pages have an Edit this page link" [ -z "$noedit10" -a -n "$(grep -rl 'Edit this page' "$P/v1.0/docs" | head -n 1)" ]

undated=$(for f in $pages09; do case "$f" in */404.html) continue ;; esac; grep -q '<time datetime=' "$f" || echo "${f#"$P"/}"; done | head -n 3)
why="no date on: $undated"
check "v0.9 pages have dates" [ -z "$undated" ]
site_keys=$(grep '^  "opmodel.dev/site/content/' "$SITE/data/opm/lastmod.json" || true)
one_version=$(printf '%s\n' "$site_keys" | awk 'NF && !(/"v1.0":/ && /"v0.9":/)')
why="site-owned keys without both versions: $(printf '%s' "$one_version" | head -n 2)"
check "data/opm/lastmod.json holds site-owned keys for both versions" [ -n "$site_keys" -a -z "$one_version" ]

echo
echo "check-two-versions: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
