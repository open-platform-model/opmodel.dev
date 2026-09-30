#!/bin/sh
# Regression tests for the site build: the fixture workspace builds green and
# renders the page dialect, and every check fails when it should. Runs in the
# build image with no network (site/scripts/run-in-image.sh test). It reads
# only fixtures under site/tests/, never a source checkout, and writes only
# under site/.check/tests/: each case runs on its own copy of the site
# (site/ less its generated paths and tests/) with SITE_DIR pointing at it,
# so a test run never touches site/public/ or a real build's generated config.
#
#   site/tests/fixtures/ws/<repo>/docs/site/   the fixture workspace, in the dialect
#   site/tests/lint/<case>/                    a tree laid over a copy of the fixture
#                                              workspace, plus "expect": the one
#                                              violation, "<path>:<line>: <message>"
#   site/tests/checks/<case>/                  a tree laid over a copy of the fixture
#                                              workspace, plus "expect": lines "+ text"
#                                              the failed build must print and "- text"
#                                              it must not
#
# Prints "ok" or "FAIL" per case; exits 1 on any unexpected result.
set -u
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
SITE=$(cd "$SCRIPTS/.." && pwd)
TESTS=$SITE/tests
WS=$TESTS/fixtures/ws
OUT=$SITE/.check/tests
REPOS="opm core catalog_opm cli library opm-operator"
pass=0; fail=0

ok() { echo "ok   $1: $2"; pass=$((pass + 1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail + 1)); [ -z "${3:-}" ] || tail -n 15 "$3" | sed 's/^/     | /'; }

# copy_site CASE: site/ less its generated paths and tests/, at OUT/CASE/site.
copy_site() {
  d=$OUT/$1/site
  mkdir -p "$d"
  for e in "$SITE"/* "$SITE"/.[!.]*; do
    [ -e "$e" ] || continue
    case "${e##*/}" in
      public|resources|.check|.shots|.versions|.gen|tests|.hugo_build.lock|node_modules) continue ;;
    esac
    cp -R "$e" "$d/"
  done
  rm -rf "$d/config/production" "$d/config/development" "$d/data/opm"
}

# copy_ws CASE [OVERLAY]: the fixture workspace at OUT/CASE/ws, with OVERLAY's
# tree laid over it (its "expect" file left out).
copy_ws() {
  d=$OUT/$1/ws
  mkdir -p "$d"
  cp -R "$WS/." "$d/"
  if [ -n "${2:-}" ]; then cp -R "$2/." "$d/"; rm -f "$d/expect"; fi
}

roots() { for r in $REPOS; do printf ' %s/%s/docs/site' "$1" "$r"; done; }

# count PATTERN FILE: lines of grep -oE matches.
count() { grep -oE "$1" "$2" 2>/dev/null | wc -l | tr -d ' '; }

# line_of URL FILE: the line number of URL in a nav-order file, or 0.
line_of() { awk -v u="$1" '$0 == u { print NR; f = 1; exit } END { if (!f) print 0 }' "$2"; }

rm -rf "$OUT"
mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# Lint: each case has exactly the one violation its expect file names.
for c in "$TESTS"/lint/*/; do
  c=${c%/}; name=lint/${c##*/}
  copy_ws "$name" "$c"
  log=$OUT/$name/log
  # shellcheck disable=SC2046 # roots holds no spaces
  sh "$SCRIPTS/lint-sources.sh" $(roots "$OUT/$name/ws") > "$log" 2>&1; rc=$?
  want="$OUT/$name/ws/$(head -n 1 "$c/expect")"
  if [ $rc -eq 1 ] && grep -q 'opm-dialect-lint: 1 violation' "$log" && awk -v w="$want" 'index($0, w) == 1 { f = 1 } END { exit !f }' "$log"; then
    ok "$name" "$(head -n 1 "$c/expect")"
  else
    bad "$name" "expected exit 1 and exactly: $(head -n 1 "$c/expect") (exit $rc)" "$log"
  fi
done

# ---------------------------------------------------------------------------
# The fixture workspace builds green.
name=fixture
copy_site "$name"
log=$OUT/$name/log
SITE_DIR=$OUT/$name/site OPM_VERSIONS=v1.0=$WS sh "$SCRIPTS/build-all.sh" > "$log" 2>&1; rc=$?
P=$OUT/$name/site/public/v1.0
if [ $rc -eq 0 ]; then ok "$name" "the fixture workspace builds green"; else bad "$name" "the fixture build failed (exit $rc)" "$log"; fi

if [ $rc -eq 0 ]; then
  # GitHub alerts with a bold title line become Hextra alerts; no marker is left.
  q=$P/docs/start/quickstart/index.html
  if [ "$(count 'data-alert="?tip"? class="?hextra-alert"?' "$q")" = 1 ] && [ "$(count 'data-alert="?note"? class="?hextra-alert"?' "$q")" = 1 ] &&
     grep -q 'hextra-alert-content"\{0,1\}><p><strong>Deploying your own module</strong></p>' "$q" &&
     grep -q 'hextra-alert-content"\{0,1\}><p><strong>Two paragraphs</strong></p><p>The first paragraph of the note.</p><p>The second paragraph' "$q" &&
     ! grep -q '\[!' "$q"; then
    ok "dialect/alerts" "TIP and NOTE render as Hextra alerts with the bold title line; no [! left"
  else bad "dialect/alerts" "quickstart alerts did not render as Hextra alerts with their bold title" "$q"; fi

  # Parameterless figure shortcodes: one drawn figure, five stubs, the escaped
  # example as text, and no unexpanded shortcode anywhere.
  s=$P/docs/start/index.html
  raw=$(find "$P" -name '*.html' -exec grep -l '{{<' {} + 2>/dev/null)
  if [ "$(count '<figure class="?opm-fig' "$s")" = 1 ] && [ "$(count 'role="?img"? aria-label=' "$s")" -ge 1 ] &&
     [ "$(count 'Figure pending' "$s")" = 5 ] && [ "$(count 'The figure <em>[^<]+</em> is being redrawn' "$s")" = 5 ] &&
     [ "$(count '\{\{&lt; opm/helm-and-opm &gt;\}\}' "$s")" = 1 ] && [ "$(count '\{\{&lt;' "$s")" = 1 ] && [ -z "$raw" ]; then
    ok "dialect/shortcodes" "six opm/ shortcodes render (1 figure, 5 stubs); the escaped one shows as text; no raw {{< left"
  else bad "dialect/shortcodes" "figure shortcodes did not render as expected${raw:+ (raw {{< in: $raw)}"; fi

  # Inline figure SVG passes the minifier byte for byte.
  if grep -q 'component <tspan' "$s"; then ok "dialect/svg-space" "the figure keeps the space before its <tspan>"
  else bad "dialect/svg-space" "component<tspan: the minifier trimmed the figure's text"; fi

  # Order is weight, then title: in a source section and across the sections.
  nav=$OUT/$name/site/.check/v1.0/nav-order.txt
  prev=0; order_ok=1
  for u in start concepts authoring operating extending embedding reference diagnostics; do
    n=$(line_of "/v1.0/docs/$u/" "$nav")
    if [ "$n" -le "$prev" ]; then order_ok=0; fi; prev=$n
  done
  z=$(line_of /v1.0/docs/start/zeta-first/ "$nav"); a=$(line_of /v1.0/docs/start/alpha-second/ "$nav")
  d=$(line_of /v1.0/docs/reference/definitions/ "$nav"); cl=$(line_of /v1.0/docs/reference/cli/ "$nav")
  if [ $order_ok = 1 ] && [ "$z" -gt 0 ] && [ "$z" -lt "$a" ] && [ "$d" -gt 0 ] && [ "$d" -lt "$cl" ]; then
    ok "dialect/weight" "nav-order.txt: zeta-first (weight 1) before alpha-second (weight 2); sections in weight order"
  else bad "dialect/weight" "nav-order.txt is not in weight order" "$nav"; fi

  # Root-absolute links resolve through the link hook in the current version.
  if grep -q 'href="\{0,1\}/v1.0/docs/concepts/fixture-concept/#why"\{0,1\}>the fixture concept</a>' "$q" &&
     grep -q 'href="\{0,1\}/v1.0/docs/start/"\{0,1\}>the start section</a>' "$q"; then
    ok "dialect/links" "/docs/concepts/fixture-concept/#why -> /v1.0/docs/concepts/fixture-concept/#why; a reference-style link resolves too"
  else bad "dialect/links" "root-absolute links did not resolve to /v1.0/docs/..."; fi

  # Planning comments reach no published text, llms.txt included.
  leak=$(find "$OUT/$name/site/public" \( -name '*.html' -o -name '*.txt' -o -name '*.md' -o -name '*.xml' -o -name '*.json' \) -exec grep -l -e '<!--' -e quokkabrief {} + 2>/dev/null)
  if [ -z "$leak" ] && grep -q 'Brief only.*: A planned page whose body is only its planning comment\.$' "$P/llms.txt"; then
    ok "comments" "no brief in any text output; llms.txt prints the description"
  else bad "comments" "a planning comment reached: ${leak:-llms.txt}" "$P/llms.txt"; fi
fi

# ---------------------------------------------------------------------------
# Checks: each case's build fails the way its expect file says.
for c in "$TESTS"/checks/*/; do
  c=${c%/}; name=checks/${c##*/}
  copy_site "$name"; copy_ws "$name" "$c"
  log=$OUT/$name/log
  SITE_DIR=$OUT/$name/site OPM_VERSIONS=v1.0=$OUT/$name/ws sh "$SCRIPTS/build-all.sh" > "$log" 2>&1; rc=$?
  why=""
  [ $rc -ne 0 ] || why="the build passed"
  while IFS= read -r e; do
    t=${e#? }
    case "$e" in
      "+ "*) grep -qF -- "$t" "$log" || why="${why:+$why; }missing: $t" ;;
      "- "*) ! grep -qF -- "$t" "$log" || why="${why:+$why; }unexpected: $t" ;;
    esac
  done < "$c/expect"
  if [ -z "$why" ]; then ok "$name" "failed as expected: $(grep -m1 '^+ ' "$c/expect" | cut -c3-)"
  else bad "$name" "$why" "$log"; fi
done

echo
echo "test-site: $pass passed, $fail failed"
[ $fail -eq 0 ]
