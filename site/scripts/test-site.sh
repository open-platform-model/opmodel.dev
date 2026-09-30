#!/bin/sh
# Regression tests for the site build: the fixture workspace builds green and
# renders the page dialect, the source lint rejects every form the dialect
# forbids, and every build check fails when it should. Runs in the build image
# with no network (site/scripts/run-in-image.sh test). It reads only fixtures
# under site/tests/, never a source checkout, and writes only under
# site/.check/tests/: each case runs on its own copies of the fixture
# workspace and of the site (the directories a build reads, and the top-level files), with
# SITE_DIR pointing at the copy, so a test run never touches site/public/ or a
# real build's generated config. Scratch files go to the container's own
# /tmp (mktemp), never to a host path.
#
#   site/tests/fixtures/ws/<repo>/docs/site/   the fixture workspace, in the dialect
#   site/tests/lint/<case>/                    lint cases
#   site/tests/checks/<case>/                  build-check cases
#   site/tests/dialect/                        a tree whose build must render the dialect
#
# A case directory holds any of:
#   <repo>/docs/site/...  pages laid over the copy of the fixture workspace
#   site/...              files laid over the copy of the site (site-owned pages, config)
#   setup.sh              run after the copies, with SITE and WS set to them
#   env                   KEY=VALUE lines exported for the build (checks only)
#   expect                lint: one "<path>:<line>: <message>" line per violation,
#                         none for a clean tree; checks: "+ text" lines the failed
#                         build must print and "- text" lines it must not
#
# Prints "ok" or "FAIL" per case; exits 1 on any unexpected result.
set -u
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
SITE=$(cd "$SCRIPTS/.." && pwd)
TESTS=$SITE/tests
WS=$TESTS/fixtures/ws
OUT=$SITE/.check/tests
REPOS="opm core catalog_opm cli library opm-operator"
# Only the git-dates case turns this on; CI may export it for real builds.
export OPM_REQUIRE_DATES=0
pass=0; fail=0

ok() { echo "ok   $1: $2"; pass=$((pass + 1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail + 1)); [ -z "${3:-}" ] || tail -n 15 "$3" | sed 's/^/     | /'; }

# copy_site CASE: the site at OUT/CASE/site: the directories a build reads and
# the top-level files, never generated output (public/, .check/, ...), tests/
# or anything an old checkout left behind (site/dist/, site/.astro/, site/src/).
copy_site() {
  d=$OUT/$1/site
  mkdir -p "$d"
  for e in config content layouts assets static data i18n archetypes themes scripts; do
    [ -d "$SITE/$e" ] && cp -R "$SITE/$e" "$d/"
  done
  for e in "$SITE"/* "$SITE"/.[!.]*; do
    [ -f "$e" ] && cp "$e" "$d/"
  done
  rm -rf "$d/config/production" "$d/config/development" "$d/data/opm" "$d/.hugo_build.lock"
  return 0
}

# copy_ws CASE: the fixture workspace at OUT/CASE/ws.
copy_ws() {
  mkdir -p "$OUT/$1/ws"
  cp -R "$WS/." "$OUT/$1/ws/"
}

# overlay CASE DIR: lay DIR's repo trees over the workspace copy and its site/
# tree over the site copy, then run its setup.sh.
overlay() {
  for r in $REPOS; do
    [ -d "$2/$r" ] && cp -R "$2/$r" "$OUT/$1/ws/"
  done
  if [ -d "$2/site" ]; then cp -R "$2/site/." "$OUT/$1/site/"; fi
  if [ -f "$2/setup.sh" ]; then SITE=$OUT/$1/site WS=$OUT/$1/ws sh "$2/setup.sh"; fi
  return 0
}

roots() { for r in $REPOS; do printf ' %s/%s/docs/site' "$1" "$r"; done; }

# build CASE ROOT [ENVFILE]: build-all.sh on the case's site copy, into its log.
build() {
  (
    # shellcheck disable=SC1090 # the case's own env file
    if [ -n "${3:-}" ] && [ -f "$3" ]; then set -a; . "$3"; set +a; fi
    SITE_DIR=$OUT/$1/site OPM_VERSIONS=v1.0=$2 sh "$SCRIPTS/build-all.sh"
  ) > "$OUT/$1/log" 2>&1
}

# count PATTERN FILE: the number of grep -oE matches.
count() { grep -oE "$1" "$2" 2>/dev/null | wc -l | tr -d ' '; }

# line_of URL FILE: the line number of URL in a nav-order file, or 0.
line_of() { awk -v u="$1" '$0 == u { print NR; f = 1; exit } END { if (!f) print 0 }' "$2"; }

rm -rf "$OUT"
mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# Lint: each case prints exactly the violations its expect file names, each
# with its file and line, and exits 1 (0 for a clean tree).
for c in "$TESTS"/lint/*/; do
  c=${c%/}; name=lint/${c##*/}
  copy_ws "$name"; overlay "$name" "$c"
  log=$OUT/$name/log
  # shellcheck disable=SC2046 # roots holds no spaces
  sh "$SCRIPTS/lint-sources.sh" $(roots "$OUT/$name/ws") > "$log" 2>&1; rc=$?
  n=$(grep -c . "$c/expect")
  why=""
  if [ "$n" -eq 0 ]; then
    [ $rc -eq 0 ] || why="expected a clean tree (exit $rc)"
  else
    [ $rc -eq 1 ] || why="expected exit 1 (exit $rc)"
    grep -q "^opm-dialect-lint: $n violation(s)$" "$log" || why="${why:+$why; }expected exactly $n violation(s)"
    while IFS= read -r e; do
      awk -v w="$OUT/$name/ws/$e" 'index($0, w) == 1 { f = 1 } END { exit !f }' "$log" || why="${why:+$why; }missing: $e"
    done < "$c/expect"
  fi
  if [ "$n" -eq 0 ]; then first=clean; else first=$(head -n 1 "$c/expect"); fi
  if [ "$n" -gt 1 ]; then first="$first (+$((n - 1)) more)"; fi
  if [ -z "$why" ]; then ok "$name" "$first"; else bad "$name" "$why" "$log"; fi
done

# ---------------------------------------------------------------------------
# The fixture workspace builds green and renders the dialect.
name=fixture
copy_site "$name"
build "$name" "$WS"; rc=$?
log=$OUT/$name/log
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

  # Parameterless figure shortcodes: all six render as drawn figures (the count
  # takes an alert standing in a figure's place as one of the six). Every drawn
  # figure's svg[role=img] carries its caption as its accessible label. The
  # escaped example shows as text, and no shortcode is left unexpanded.
  s=$P/docs/start/index.html
  raw=$(find "$P" -name '*.html' -exec grep -l '{{<' {} + 2>/dev/null)
  drawn=$(count '<figure class="?opm-fig' "$s")
  inplace=$(count 'data-alert=' "$s")
  labelled=$(tr '\n' ' ' < "$s" | sed 's#</figure>#</figure>\n#g' | awk '
    /<figure class="?opm-fig/ && /role="?img/ {
      l = $0; sub(/.*aria-label="/, "", l); sub(/".*/, "", l)
      if (match($0, /<figcaption>[^<]*<\/figcaption>/) && l != "" && l == substr($0, RSTART + 12, RLENGTH - 25)) n++
    }
    END { print n + 0 }')
  if [ "$drawn" -ge 1 ] && [ $((drawn + inplace)) -eq 6 ] && [ "$labelled" -eq "$drawn" ] &&
     [ "$(count '\{\{&lt; opm/helm-and-opm &gt;\}\}' "$s")" = 1 ] && [ "$(count '\{\{&lt;' "$s")" = 1 ] && [ -z "$raw" ]; then
    ok "dialect/shortcodes" "six opm/ shortcodes render ($drawn drawn, $inplace not drawn yet); each drawn figure is labelled by its caption; the escaped one shows as text; no raw {{< left"
  else bad "dialect/shortcodes" "figure shortcodes did not render as expected ($drawn drawn, $inplace in place, $labelled labelled)${raw:+ (raw {{< in: $raw)}"; fi

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

  # The landing's primary button leads to the Start here section of its own
  # version, not to the docs root (a relative href resolves against /v1.0/).
  cta=$(tr '\n' ' ' < "$P/index.html" | grep -oE '<a [^>]*href="?[^" >]+"?[^>]*>Get started</a>' | sed -nE 's/.*href="?([^" >]+).*/\1/p' | head -n 1)
  case "$cta" in /*) target=$cta ;; *) target=/v1.0/$cta ;; esac
  if [ "$target" = /v1.0/docs/start/ ] && [ -f "$P/docs/start/index.html" ]; then
    ok "landing" "Get started leads to /v1.0/docs/start/ (href $cta)"
  else bad "landing" "Get started leads to ${target:-nothing}, not /v1.0/docs/start/"; fi

  # Markdown outputs (Copy page): links point into the version, figures show
  # their title, and no shortcode is left outside a code fence.
  mdbad=$(find "$OUT/$name/site/public" -name '*.md' | sort | while IFS= read -r m; do
    awk -v F="${m#"$OUT/$name/site/public/"}" '
      /^ ? ? ?(```|~~~)/ { f = !f; next }
      !f && /[{][{][<%]/ { print "  " F ": " $0 }
      /[]][(]\/docs\// || /^ ? ? ?[[][^]]+[]]:[ \t]*\/docs\// { print "  " F ": " $0 }' "$m"
  done)
  if [ -z "$mdbad" ] && grep -q '^_Figure: From module to running objects_$' "$P/docs/start/index.md" &&
     grep -qF '](https://opmodel.dev/v1.0/docs/concepts/fixture-concept/#why)' "$P/docs/start/quickstart.md"; then
    ok "markdown" "the .md outputs link into /v1.0/, show figure titles, and hold no shortcode outside a code fence"
  else bad "markdown" "a Markdown output still holds /docs/ links or shortcodes:
$mdbad"; fi

  # The Markdown outputs name each figure as the page draws it. The fixture's
  # start page calls every figure shortcode once, so the titles its figures draw
  # (their svg <title>) and its .md output's "_Figure: <title>_" lines must be
  # the same six, in page order: an entry of _partials/opm/figure-titles.html
  # that drifts from its shortcode's title fails here.
  page_titles=$(tr '\n' ' ' < "$P/docs/start/index.html" | sed 's#</figure>#</figure>\n#g' | awk '
    match($0, /<figure class="?opm-fig/) {
      f = substr($0, RSTART)
      if (match(f, /<title>[^<]*<\/title>/)) print substr(f, RSTART + 7, RLENGTH - 15)
    }')
  md_titles=$(sed -n 's/^_Figure: \(.*\)_$/\1/p' "$P/docs/start/index.md")
  if [ "$(printf '%s\n' "$page_titles" | grep -c .)" -eq 6 ] && [ "$page_titles" = "$md_titles" ]; then
    ok "markdown/figure-titles" "the .md output names all six figures as the page draws them"
  else bad "markdown/figure-titles" "the .md output names the figures differently from the page:
     page: $(printf '%s' "$page_titles" | tr '\n' '|')
     .md:  $(printf '%s' "$md_titles" | tr '\n' '|')"; fi
fi

# ---------------------------------------------------------------------------
# Dialect: every alert type with a bold title line becomes a Hextra alert, and
# the line after a CUE "" is tokenised, not swallowed by a string
# (layouts/_markup/render-codeblock-cue.html).
name=dialect
copy_site "$name"; copy_ws "$name"; overlay "$name" "$TESTS/dialect"
build "$name" "$OUT/$name/ws"; rc=$?
f=$OUT/$name/site/public/v1.0/docs/start/dialect/index.html
if [ $rc -ne 0 ]; then bad "$name" "the dialect build failed (exit $rc)" "$OUT/$name/log"
else
  why=""
  for t in note tip important warning caution; do
    T=$(printf '%s' "$t" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')
    [ "$(count "data-alert=\"?$t\"? class=\"?hextra-alert\"?" "$f")" = 1 ] || why="${why:+$why; }no $t alert"
    grep -q "hextra-alert-content\"\{0,1\}><p><strong>$T title</strong></p><p>The $t body.</p>" "$f" || why="${why:+$why; }$t alert lost its bold title"
  done
  if grep -q '\[!' "$f"; then why="${why:+$why; }a literal [! is left"; fi
  if [ -z "$why" ]; then ok "$name/alerts" "NOTE, TIP, IMPORTANT, WARNING and CAUTION render as Hextra alerts with their bold title"
  else bad "$name/alerts" "$why"; fi
  # Chroma marks a Name with class n: the field after each "" must be one.
  cue=$(tr -d '\n' < "$f")
  after='&#34;&#34;</span></span></span><span class="\{0,1\}line"\{0,1\}><span class="\{0,1\}cl"\{0,1\}>	<span class="\{0,1\}n"\{0,1\}>'
  if printf '%s' "$cue" | grep -q "${after}replicas</span>" && printf '%s' "$cue" | grep -q "${after}name</span>" &&
     ! grep -q OPMEMPTYSTRING "$f"; then
    ok "$name/cue" "the line after a CUE \"\" is tokenised as a name; no placeholder is left"
  else bad "$name/cue" "the CUE \"\" swallowed the lines after it"; fi
fi

# ---------------------------------------------------------------------------
# Checks: each case's build fails the way its expect file says.
for c in "$TESTS"/checks/*/; do
  c=${c%/}; name=checks/${c##*/}
  copy_site "$name"; copy_ws "$name"; overlay "$name" "$c"
  build "$name" "$OUT/$name/ws" "$c/env"; rc=$?
  log=$OUT/$name/log
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
