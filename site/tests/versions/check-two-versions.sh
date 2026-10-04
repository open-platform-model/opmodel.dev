#!/bin/sh
# The two-version regression test (task versions:test, which task test:site
# runs). Host side: POSIX sh, grep, awk and jq.
#
# It builds two site versions from docs bundles, as a release of a second
# version would: v1.0 from the real docs bundles of the last task
# bundles:pull (site/.bundles/_versions/v1.0/, and the real Enhancements
# section bundle, which those pages link), and v0.9 from the fixture docs
# bundles (site/tests/fixtures/bundles/_versions/v1.0/) relabelled as v0.9,
# with the fixture Catalogs tab, which does not move with catalog_opm's
# releases. two-versions.conf gives both their display keys
# (OPM_VERSIONS_CONF).
#
# This test never writes site/public/, which CI uploads and the deploy
# publishes, nor the real build's site/.check/<version>/: it builds into
# site/.check/versions-test/public/ with its nav-order.txt files in
# site/.check/versions-test/check/ (build-all.sh --public, --check), and it
# fails if anything under site/public/ or site/.check/ outside versions-test/
# changed while it ran. It does overwrite the generated inputs every build
# shares (site/config/<env>/, site/data/opm/, site/.gen/); the next build
# regenerates them.
#
#   sh site/tests/versions/check-two-versions.sh
#
# The build runs in the build image through run-in-image.sh's own functions
# (sourced with mode "tag"), so it gets the same image, host steps and mounts
# as task build. Then every assertion prints "ok" or "FAIL"; any FAIL exits 1.
set -eu
export LC_ALL=C
# shellcheck disable=SC2166 # [ a -a b ] keeps each assertion on one line
HERE=$(cd "$(dirname "$0")" && pwd -P)
SITE=$(cd "$HERE/../.." && pwd -P)
OUT=$SITE/.check/versions-test
P=$OUT/public
C=$OUT/check
LOG=$OUT/build.log
pass=0; fail=0
ok() { echo "ok   $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail + 1)); }
check() { name=$1; shift; if "$@"; then ok "$name"; else bad "$name" "${why:-assertion false}"; fi; why=""; }
why=""

# --- The bundles: real v1.0, fixture v0.9 ----------------------------------------
RB=$SITE/.bundles
FB=$SITE/tests/fixtures/bundles
[ -f "$RB/lock.json" ] && [ -d "$RB/_versions/v1.0" ] && jq -e '[.docs // [] | .[] | select(.site == "v1.0")] | length > 0' "$RB/lock.json" >/dev/null || {
  echo "check-two-versions: $RB holds no docs bundles for v1.0; run task bundles:pull first" >&2
  exit 1
}
[ -f "$RB/enhancements/edge/manifest.json" ] || {
  echo "check-two-versions: $RB holds no enhancements section bundle; run task bundles:pull first" >&2
  exit 1
}
mkdir -p "$OUT"
rm -rf "$P" "$C" "$OUT/bundles"
marker=$OUT/.started; : > "$marker"
B=$OUT/bundles
cp -R "$FB" "$B"
rm -rf "$B/_versions" "$B/enhancements"
mkdir -p "$B/_versions"
cp -R "$RB/_versions/v1.0" "$B/_versions/v1.0"
cp -R "$FB/_versions/v1.0" "$B/_versions/v0.9"
cp -R "$RB/enhancements" "$B/enhancements"
jq --slurpfile r "$RB/lock.json" '
    .docs = ([$r[0].docs[] | select(.site == "v1.0")]
      + [.docs[] | select(.site == "v1.0") | .site = "v0.9" | .dir = ("_versions/v0.9/" + .project)])
  | .bundles = ([.bundles[] | select(.root != "/enhancements/")] + [$r[0].bundles[] | select(.root == "/enhancements/")])' \
  "$FB/lock.json" > "$B/lock.json"

# --- The build, into .check/versions-test/ ------------------------------------
OPM_BUNDLES=$B; export OPM_BUNDLES
if ! sh -c '. "$0" >/dev/null
  bundles; image >/dev/null; host_steps
  # shellcheck disable=SC2086
  run --network none --env "OPM_SITE_COMMIT=$SITE" --env OPM_VERSIONS_CONF=tests/versions/two-versions.conf $CAT \
    --entrypoint sh "$(tag)" /work/repo/site/scripts/build-all.sh --public .check/versions-test/public --check .check/versions-test/check' \
  "$SITE/scripts/run-in-image.sh" tag > "$LOG" 2>&1; then
  tail -n 30 "$LOG"
  echo "check-two-versions: FAILED, the two-version build failed (log: $LOG)"
  exit 1
fi
grep -E '^(v[0-9.]+: [0-9]+ pages|build-all: OK)' "$LOG" | sed 's/^/build: /'
DB=$SITE/data/opm/docs-bundles.json
ST=$P/build-stamp.json

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
foreign=$(for v in v1.0 v0.9; do grep -o '<loc>[^<]*' "$P/$v/sitemap.xml" | grep -v "^<loc>https://opmodel.dev/$v/" | grep -v '^<loc>https://opmodel.dev/catalogs/' | sed "s/^/$v: /"; done | head -n 3)
why="foreign URLs: $foreign"
check "each sitemap lists only its own version's URLs (and the default one the Catalogs section's)" [ -z "$foreign" -a -s "$P/v0.9/sitemap.xml" ]
why="v1.0's sitemap lacks /catalogs/opm/4.5/, or v0.9's lists a catalog page"
check "only the default version's sitemap lists the Catalogs section" sh -c 'grep -q "<loc>https://opmodel.dev/catalogs/opm/4.5/</loc>" "$1/v1.0/sitemap.xml" && ! grep -q "opmodel.dev/catalogs/" "$1/v0.9/sitemap.xml"' - "$P"
check "each version has its own llms.txt and 404.html" [ -s "$P/v1.0/llms.txt" -a -s "$P/v0.9/llms.txt" -a -s "$P/v1.0/404.html" -a -s "$P/v0.9/404.html" ]
check "the root 404.html is v1.0's" cmp -s "$P/404.html" "$P/v1.0/404.html"

why="_redirects or a /latest/ stub does not point at v1.0"
# shellcheck disable=SC2016
check "_redirects and the /latest/ stubs point at v1.0" sh -c 'grep -qx "/latest/\* /v1.0/:splat 302" "$1/_redirects" &&
  grep -q "url=/v1.0/\"" "$1/latest/index.html" && grep -q "url=/v1.0/docs/\"" "$1/latest/docs/index.html"' - "$P"

# The enhancements section belongs to no version: it publishes once, at
# /enhancements/, and every version's pages carry the tab to it, the
# non-default version's too, where its page does not exist (Hugo would warn,
# and --panicOnWarning fail the build, if a template could not take that).
why="no $P/enhancements/index.html, or a copy under a version"
check "the enhancements section publishes once, outside every version" \
  [ -f "$P/enhancements/index.html" -a ! -e "$P/v1.0/enhancements" -a ! -e "$P/v0.9/enhancements" ]
tab_bad=""
for v in v1.0 v0.9; do
  f=$P/$v/docs/index.html
  tr -d '"' < "$f" | grep -qE '<a title href=/enhancements/ class=' || tab_bad="$tab_bad $v(navbar)"
  tr -d '"' < "$f" | grep -qE '<a class=opm-sb-link href=/enhancements/><span>Enhancements' || tab_bad="$tab_bad $v(phone menu)"
  ! tr -d '"' < "$f" | grep -qE 'href=( |>)' || tab_bad="$tab_bad $v(an empty href)"
done
why="missing or broken on:$tab_bad"
check "both versions link the Enhancements tab to /enhancements/, in the navbar and the phone menu" [ -z "$tab_bad" ]

# The Catalogs section belongs to no version either: it publishes once, at
# /catalogs/, from the fixture bundles, and every version carries its tab.
why="no $P/catalogs/opm/4.5/index.html, or a copy under a version"
check "the catalogs section publishes once, outside every version" \
  [ -f "$P/catalogs/index.html" -a -f "$P/catalogs/opm/4.5/index.html" -a -f "$P/catalogs/opm/edge/index.html" -a ! -e "$P/v1.0/catalogs" -a ! -e "$P/v0.9/catalogs" ]
tab_bad=""
for v in v1.0 v0.9; do
  f=$P/$v/docs/index.html
  tr -d '"' < "$f" | grep -qE '<a title href=/catalogs/ class=' || tab_bad="$tab_bad $v(navbar)"
  tr -d '"' < "$f" | grep -qE '<a class=opm-sb-link href=/catalogs/><span>Catalogs' || tab_bad="$tab_bad $v(phone menu)"
done
why="missing on:$tab_bad"
check "both versions link the Catalogs tab to /catalogs/, in the navbar and the phone menu" [ -z "$tab_bad" ]

# The record: only bundles, by digest, and this repository's commit.
why="build-stamp.json: $(jq -c '{sources, site, refs: [.versions[] | .refs // empty]}' "$ST" 2>/dev/null)"
stamp_ok() { jq -e '(has("sources") | not) and (.site | test("^[0-9a-f]{40}$")) and ([.versions[] | has("refs") or has("kind")] | any | not)' "$ST" >/dev/null; }
check "build-stamp.json names this repository's commit and no source checkout or git ref" stamp_ok

# Each version's docs bundles: named in the stamp and the footer, every
# manifest page published in that version and in no other, Edit to main at the
# manifest's edit path (generated pages none) on both versions, View source at
# the bundle commit.
bstamp_bad=""; bpage_bad=""; bedit_bad=""; bview_bad=""
for v in v1.0 v0.9; do
  stamp=$(tr '\n' ' ' < "$P/$v/docs/index.html" | grep -o '<div class="\{0,1\}opm-build-stamp.*' | sed 's#</footer>.*##')
  printf '%s' "$stamp" | grep -q 'documents\|built from' && bstamp_bad="$bstamp_bad $v(a git list)"
  for pr in $(jq -r --arg v "$v" '.versions[$v] // {} | keys[]' "$DB"); do
    b=$(jq -c --arg v "$v" --arg p "$pr" '.versions[$v][$p]' "$DB")
    bv=$(printf '%s' "$b" | jq -r .version); bc=$(printf '%s' "$b" | jq -r .commit); brepo=$(printf '%s' "$b" | jq -r .repo)
    printf '%s' "$stamp" | grep -q "github.com/$brepo/commit/$bc" && printf '%s' "$stamp" | grep -qF "<code>$bv</code>" || bstamp_bad="$bstamp_bad $v:$pr"
    [ "$(jq -r --arg v "$v" --arg p "$pr" '.versions[$v].bundles[] | select(.project == $p) | .version' "$ST")" = "$bv" ] || bstamp_bad="$bstamp_bad $v:$pr(build-stamp.json)"
    # "-" for an empty field: read collapses runs of a whitespace IFS such as tab.
    printf '%s' "$b" | jq -r '.pages | to_entries[] | "\(.key)\t\(.value.edit | if . == "" then "-" else . end)\t\(.value.source | if . == "" then "-" else . end)"' |
      while IFS='	' read -r f edit src; do
        [ "$edit" != - ] || edit=""; [ "$src" != - ] || src=""
        u=$(printf '%s' "$f" | sed -E 's#(^|/)_index\.md$#\1#; s#\.md$#/#')
        h=$P/$v/docs/${u}index.html
        if [ ! -f "$h" ]; then echo "page $v:$pr:$u"; continue; fi
        if [ -n "$edit" ]; then grep -qF "github.com/$brepo/edit/main/$edit" "$h" || echo "edit $v:$pr:$u"
        elif grep -q 'Edit this page' "$h"; then echo "edit $v:$pr:$u (none expected)"; fi
        if [ -n "$src" ]; then grep -qF "github.com/$brepo/blob/$bc/$src" "$h" || echo "view $v:$pr:$u"; fi
      done > "$OUT/.bundle-bad"
    bpage_bad="$bpage_bad$(grep '^page ' "$OUT/.bundle-bad" | head -n 2 | cut -c6- | tr '\n' ' ')"
    bedit_bad="$bedit_bad$(grep '^edit ' "$OUT/.bundle-bad" | head -n 2 | cut -c6- | tr '\n' ' ')"
    bview_bad="$bview_bad$(grep '^view ' "$OUT/.bundle-bad" | head -n 2 | cut -c6- | tr '\n' ' ')"
  done
done
rm -f "$OUT/.bundle-bad"
why="missing:$bstamp_bad"
check "each version's stamp and build-stamp.json name its docs bundles' versions and commits, and no git list" [ -z "$bstamp_bad" ]
why="not published: $bpage_bad"
check "every page of every docs bundle publishes in its version" [ -z "$bpage_bad" ]
why="wrong: $bedit_bad"
check "a bundle page's Edit goes to main at its manifest edit path on both versions; a generated page has none" [ -z "$bedit_bad" ]
why="wrong: $bview_bad"
check "a bundle page's View source goes to its source at the bundle commit" [ -z "$bview_bad" ]

# Each version publishes its own bundles' pages: a page only v1.0's real
# bundles hold is not in v0.9.
pages_of() { jq -r --arg v "$1" '[.versions[$v][] | .pages | keys[]] | .[]' "$DB" | sed -E 's#(^|/)_index\.md$#\1#; s#\.md$#/#' | sort -u; }
pages_of v0.9 > "$OUT/.p09"
only10=$(pages_of v1.0 | comm -23 - "$OUT/.p09")
leak=$(for u in $only10; do [ ! -e "$P/v0.9/docs/${u}index.html" ] || echo "$u"; done | head -n 3)
rm -f "$OUT/.p09"
why="v1.0-only pages: $(printf '%s' "$only10" | wc -w | tr -d ' '); in v0.9 too: $leak"
check "pages only v1.0's bundles hold publish in v1.0 only" [ -n "$only10" -a -z "$leak" ]

# Site-owned pages: in both versions, with their host-side git date; Edit on
# the default version only.
undated=$(for v in v1.0 v0.9; do for f in "$P/$v/docs/concepts/index.html" "$P/$v/docs/operating/index.html"; do grep -q '<time datetime=' "$f" || echo "${f#"$P"/}"; done; done | head -n 3)
why="no date on: $undated"
check "site-owned pages have their git date in both versions" [ -z "$undated" ]
why="v1.0's concepts overview has no Edit, or v0.9's has one"
check "a site-owned page has Edit on the default version only" sh -c 'grep -q "Edit this page" "$1/v1.0/docs/concepts/index.html" && ! grep -q "Edit this page" "$1/v0.9/docs/concepts/index.html"' - "$P"

echo
echo "check-two-versions: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
