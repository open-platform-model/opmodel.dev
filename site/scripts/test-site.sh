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
#   site/tests/fixtures/bundles/               docs bundles (catalog-opm 4.4, 4.5, edge) and
#                                              the lock an all-local opm-docs pull writes over
#                                              them; the tests first re-pull them offline with
#                                              the pinned opm-docs and fail unless the result is
#                                              byte-identical, then every site copy holds that
#                                              pulled tree as .bundles/, with
#                                              tests/fixtures/bundles.cue as bundles.cue
#   site/tests/fixtures/ws/enhancements/       a small enhancements repository (a live
#                                              entry, an archived one and the 0000
#                                              template), read in place as explicit mode
#                                              reads /src/enhancements
#   site/tests/subpath/env                     the base URL the fixture workspace also
#                                              builds under (a two-segment path)
#   site/tests/lint/<case>/                    lint cases
#   site/tests/checks/<case>/                  build-check cases
#   site/tests/dialect/                        a tree whose build must render the dialect
#
# A case directory holds any of:
#   <repo>/docs/site/...  pages laid over the copy of the fixture workspace
#   enhancements/...      files laid over the copy of its enhancements tree
#   site/...              files laid over the copy of the site (site-owned pages, config)
#   setup.sh              run after the copies, with SITE and WS set to them
#   env                   KEY=VALUE lines exported for the build (checks only);
#                         CASE_MANIFEST=1 builds without OPM_VERSIONS (manifest mode)
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
# A case sets a base URL only through its own env file; CI's Pages build
# exports one for real builds.
unset OPM_BASE_URL
pass=0; fail=0

ok() { echo "ok   $1: $2"; pass=$((pass + 1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail + 1)); [ -z "${3:-}" ] || tail -n 15 "$3" | sed 's/^/     | /'; }

# copy_site CASE: the site at OUT/CASE/site: the directories a build reads and
# the top-level files, never generated output (public/, .check/, ...), tests/
# or anything an old checkout left behind (site/dist/, site/.astro/, site/src/).
copy_site() {
  d=$OUT/$1/site
  mkdir -p "$d"
  for e in config content enhancements catalogs layouts assets static data i18n archetypes themes scripts; do
    [ -d "$SITE/$e" ] && cp -R "$SITE/$e" "$d/"
  done
  for e in "$SITE"/* "$SITE"/.[!.]*; do
    [ -f "$e" ] && cp "$e" "$d/"
  done
  rm -rf "$d/config/production" "$d/config/development" "$d/data/opm" "$d/.hugo_build.lock" "$d/.bundles"
  # The fixture docs bundles as opm-docs pulled them (BUNDLES, the
  # all-local pull below), with the bundles.cue they were pulled for, so
  # every build has the Catalogs section: explicit mode reads .bundles/ when
  # it holds lock.json.
  cp -R "$BUNDLES" "$d/.bundles"
  cp "$TESTS/fixtures/bundles.cue" "$d/bundles.cue"
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
  for r in $REPOS enhancements; do
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
    # CASE_MANIFEST=1 (a case's env file) builds in manifest mode, without
    # OPM_VERSIONS; its setup.sh writes the site copy's .versions/.
    v=v1.0=$2; [ -z "${CASE_MANIFEST:-}" ] || v=""
    SITE_DIR=$OUT/$1/site OPM_VERSIONS=$v sh "$SCRIPTS/build-all.sh"
  ) > "$OUT/$1/log" 2>&1
}

# count PATTERN FILE: the number of grep -oE matches.
count() { grep -oE "$1" "$2" 2>/dev/null | wc -l | tr -d ' '; }

# line_of URL FILE: the line number of URL in a nav-order file, or 0.
line_of() { awk -v u="$1" '$0 == u { print NR; f = 1; exit } END { if (!f) print 0 }' "$2"; }

# dq FILE: the file without double quotes, so an assertion reads the same
# whether the minifier kept an attribute's quotes or not.
dq() { tr -d '"' < "$1"; }

# refresh_of FILE: the URL a meta-refresh page sends to.
refresh_of() { grep -oE 'url=[^"> ]+' "$1" | head -n 1 | cut -c5-; }

# fixture_pull SRC DST: the all-local opm-docs pull (docs-kit C7 --local, no
# network) of every bundle tree SRC/lock.json names into DST, with
# tests/fixtures/bundles.cue; then DST must be byte-identical to SRC, lock.json
# included. Output in DST.log.
fixture_pull() {
  (
    set -e
    set -- "$1" "$2" $(jq -r '.bundles[] | "--local \(.project)@\(.segment)='"$1"'/\(.dir)"' "$1/lock.json")
    src=$1; dst=$2; shift 2
    cache=$(mktemp -d)
    rc=0; XDG_CACHE_HOME=$cache opm-docs pull --config "$TESTS/fixtures/bundles.cue" --out "$dst" --lock "$dst/lock.json" "$@" || rc=$?
    rm -rf "$cache"
    [ $rc -eq 0 ]
    diff -r "$src" "$dst"
  ) > "$2.log" 2>&1
}

rm -rf "$OUT"
mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# The fixture bundles through the real tool: the pinned opm-docs re-pulls them
# offline, validating every manifest, applying the unpack guards and linting
# each tree in bundle mode, and must write exactly the fixture tree and lock.
# Every later fixture build reads the pulled copy. A fixture edit regenerates
# lock.json with the same pull.
BUNDLES=$OUT/bundles
if fixture_pull "$TESTS/fixtures/bundles" "$BUNDLES"; then
  ok "catalogs/fixture-pull" "opm-docs $(opm-docs version | cut -d' ' -f2) pulls the fixture bundles offline, byte-identical to tests/fixtures/bundles/ (lock included)"
else
  bad "catalogs/fixture-pull" "the all-local pull failed or differs from tests/fixtures/bundles/; regenerate lock.json with it" "$BUNDLES.log"
  BUNDLES=$TESTS/fixtures/bundles
fi
# cat-fixture-drift: one edited byte (a commit in the lock) must fail it.
mkdir -p "$OUT/cat-fixture-drift"
cp -R "$TESTS/fixtures/bundles" "$OUT/cat-fixture-drift/src"
awk '!done && /"commit": "/ { c = substr($0, index($0, "\"commit\": \"") + 11, 1); sub(/"commit": "./, "\"commit\": \"" (c == "0" ? "1" : "0")); done = 1 } { print }' \
  "$TESTS/fixtures/bundles/lock.json" > "$OUT/cat-fixture-drift/src/lock.json"
if cmp -s "$TESTS/fixtures/bundles/lock.json" "$OUT/cat-fixture-drift/src/lock.json"; then
  bad "checks/cat-fixture-drift" "the case did not edit the fixture lock"
elif fixture_pull "$OUT/cat-fixture-drift/src" "$OUT/cat-fixture-drift/pulled"; then
  bad "checks/cat-fixture-drift" "a fixture lock edited by one byte still matched the pull" "$OUT/cat-fixture-drift/pulled.log"
elif grep -qF 'lock.json' "$OUT/cat-fixture-drift/pulled.log"; then
  ok "checks/cat-fixture-drift" "a fixture that is not what opm-docs pull writes fails, naming the file"
else
  bad "checks/cat-fixture-drift" "the pull failed, but not on the edited lock.json" "$OUT/cat-fixture-drift/pulled.log"
fi

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
  # Parity with docs-kit (C11): the pinned opm-docs lint over the same
  # roots, paths relative to the workspace copy, must report the same
  # violations: as many lines, each starting with one expect line (the
  # expect lines are prefixes, as for the shell lint), and exit 2 (0 clean).
  # shellcheck disable=SC2046 # repo names hold no spaces
  (cd "$OUT/$name/ws" && opm-docs lint $(for r in $REPOS; do printf ' %s/docs/site' "$r"; done)) > "$OUT/$name/opm-docs.log" 2>&1; drc=$?
  grep -E '^[^ ]+:[0-9]+: ' "$OUT/$name/opm-docs.log" > "$OUT/$name/opm-docs.out"
  if [ "$n" -eq 0 ]; then
    [ $drc -eq 0 ] && [ ! -s "$OUT/$name/opm-docs.out" ] || why="${why:+$why; }opm-docs lint: expected a clean tree (exit $drc)"
  else
    [ $drc -eq 2 ] || why="${why:+$why; }opm-docs lint: expected exit 2 (exit $drc)"
    awk 'NR == FNR { if ($0 != "") e[++ne] = $0; next } { o[++no] = $0 }
      END { if (ne != no) { print "count " no " != " ne; bad = 1 }
            for (i = 1; i <= ne; i++) { f = 0; for (j = 1; j <= no; j++) if (index(o[j], e[i]) == 1) f = 1; if (!f) { print "missing: " e[i]; bad = 1 } }
            for (j = 1; j <= no; j++) { f = 0; for (i = 1; i <= ne; i++) if (index(o[j], e[i]) == 1) f = 1; if (!f) { print "extra: " o[j]; bad = 1 } }
            exit bad }' "$c/expect" "$OUT/$name/opm-docs.out" > "$OUT/$name/opm-docs.diff" ||
      why="${why:+$why; }opm-docs lint differs: $(head -n 2 "$OUT/$name/opm-docs.diff" | tr '\n' ' ')"
  fi
  if [ "$n" -eq 0 ]; then first=clean; else first=$(head -n 1 "$c/expect"); fi
  if [ "$n" -gt 1 ]; then first="$first (+$((n - 1)) more)"; fi
  if [ -z "$why" ]; then ok "$name" "$first (shell lint and opm-docs lint)"; else bad "$name" "$why" "$log"; fi
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

  # Parameterless figure shortcodes: all seven render as drawn figures (the count
  # takes an alert standing in a figure's place as one of the seven). Every drawn
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
  if [ "$drawn" -ge 1 ] && [ $((drawn + inplace)) -eq 7 ] && [ "$labelled" -eq "$drawn" ] &&
     [ "$(count '\{\{&lt; opm/helm-and-opm &gt;\}\}' "$s")" = 1 ] && [ "$(count '\{\{&lt;' "$s")" = 1 ] && [ -z "$raw" ]; then
    ok "dialect/shortcodes" "seven opm/ shortcodes render ($drawn drawn, $inplace not drawn yet); each drawn figure is labelled by its caption; the escaped one shows as text; no raw {{< left"
  else bad "dialect/shortcodes" "figure shortcodes did not render as expected ($drawn drawn, $inplace in place, $labelled labelled)${raw:+ (raw {{< in: $raw)}"; fi

  # Inline figure SVG passes the minifier byte for byte.
  if grep -q 'component <tspan' "$s"; then ok "dialect/svg-space" "the figure keeps the space before its <tspan>"
  else bad "dialect/svg-space" "component<tspan: the minifier trimmed the figure's text"; fi

  # Order is weight, then title: in a source section and across the sections.
  # Reference is its own tab: the docs tree leaves it out, and the Reference
  # home's tree holds it in weight order.
  nav=$OUT/$name/site/.check/v1.0/nav-order.txt
  rnav=$OUT/$name/site/.check/v1.0/nav-order-reference.txt
  prev=0; order_ok=1
  for u in start concepts authoring operating extending embedding diagnostics; do
    n=$(line_of "/v1.0/docs/$u/" "$nav")
    if [ "$n" -le "$prev" ]; then order_ok=0; fi; prev=$n
  done
  z=$(line_of /v1.0/docs/start/zeta-first/ "$nav"); a=$(line_of /v1.0/docs/start/alpha-second/ "$nav")
  d=$(line_of /v1.0/docs/reference/definitions/ "$rnav"); cl=$(line_of /v1.0/docs/reference/cli/ "$rnav")
  dd=$(line_of /v1.0/docs/reference/definitions/ "$nav"); rd=$(line_of /v1.0/docs/start/ "$rnav")
  if [ $order_ok = 1 ] && [ "$z" -gt 0 ] && [ "$z" -lt "$a" ] && [ "$d" -gt 0 ] && [ "$d" -lt "$cl" ] && [ "$dd" = 0 ] && [ "$rd" = 0 ]; then
    ok "dialect/weight" "nav-order.txt: zeta-first (weight 1) before alpha-second (weight 2); sections in weight order; Reference in its own tree, definitions before cli"
  else bad "dialect/weight" "nav-order.txt or nav-order-reference.txt is not in weight order, or a tree holds the other's pages" "$nav"; fi

  # A site placeholder yields to a source page at its path, and stays where none exists.
  if grep -q 'the cli repository publishes this section page itself' "$P/docs/reference/cli/index.html" &&
     grep -q 'This page will list every definition' "$P/docs/reference/definitions/index.html"; then
    ok "placeholder" "docs/reference/cli/ comes from the fixture cli; docs/reference/definitions/ keeps the site's placeholder"
  else bad "placeholder" "a placeholder did not yield to the source page, or vanished where none exists" "$P/docs/reference/cli/index.html"; fi

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
  # the same seven, in page order: an entry of _partials/opm/figure-titles.html
  # that drifts from its shortcode's title fails here.
  page_titles=$(tr '\n' ' ' < "$P/docs/start/index.html" | sed 's#</figure>#</figure>\n#g' | awk '
    match($0, /<figure class="?opm-fig/) {
      f = substr($0, RSTART)
      if (match(f, /<title>[^<]*<\/title>/)) print substr(f, RSTART + 7, RLENGTH - 15)
    }')
  md_titles=$(sed -n 's/^_Figure: \(.*\)_$/\1/p' "$P/docs/start/index.md")
  if [ "$(printf '%s\n' "$page_titles" | grep -c .)" -eq 7 ] && [ "$page_titles" = "$md_titles" ]; then
    ok "markdown/figure-titles" "the .md output names all seven figures as the page draws them"
  else bad "markdown/figure-titles" "the .md output names the figures differently from the page:
     page: $(printf '%s' "$page_titles" | tr '\n' '|')
     .md:  $(printf '%s' "$md_titles" | tr '\n' '|')"; fi

  # The production host is indexed, and the share image keeps its production
  # URL (params.images carries no leading slash).
  if ! dq "$q" | grep -qF 'name=robots content=noindex' &&
     dq "$q" | grep -qF 'name=twitter:image content=https://opmodel.dev/images/og-default.png'; then
    ok "indexing" "the quickstart page carries no robots noindex tag; twitter:image is https://opmodel.dev/images/og-default.png"
  else bad "indexing" "the default build's quickstart page has a noindex tag, or its twitter:image moved"; fi
fi

# ---------------------------------------------------------------------------
# The Enhancements section, from the fixture's enhancements tree: unversioned
# pages at /enhancements/, the tab, repository links mapped, the exclusions.
if [ $rc -eq 0 ]; then
  E=$OUT/$name/site/public/enhancements
  log=$OUT/$name/log
  if [ -f "$E/index.html" ] && [ -f "$E/graph/index.html" ] && [ -f "$E/0001/decisions/index.html" ] &&
     [ -f "$E/0002/questions/index.html" ] && [ ! -e "$E/0000" ] && [ ! -e "$P/enhancements" ] &&
     grep -qF 'enhancements: 18 pages expected, 18 built' "$log"; then
    ok "enhancements/pages" "the section page, the graph, two entries with seven documents each, keyed by id (archive/0002 at /enhancements/0002/); no 0000 template, nothing under /v1.0/"
  else bad "enhancements/pages" "the section's page set is wrong" "$log"; fi

  why=""
  for f in "$P/docs/start/quickstart/index.html" "$E/0001/index.html"; do
    dq "$f" | grep -qE '<a title href=/enhancements/ class=' || why="${why:+$why; }no Enhancements tab in ${f#"$OUT"/}"
  done
  dq "$E/0001/index.html" | grep -qE '<a title href=/enhancements/ class=[^>]*font-medium' || why="${why:+$why; }the tab is not current on an entry"
  ! grep -q 'opm-version-label' "$E/0001/index.html" || why="${why:+$why; }an entry shows the version label"
  if [ -z "$why" ]; then ok "enhancements/tab" "every page has the Enhancements tab, current on the section; no version label there"
  else bad "enhancements/tab" "$why"; fi

  r=$(dq "$E/0001/index.html")
  why=""
  for want in 'href=/enhancements/0001/design/>the design document' 'href=/enhancements/0001/decisions/#d1>D1' \
    'href=/enhancements/0002/>the archived entry' 'href=/enhancements/>the index' 'href=/enhancements/graph/>the relationship graph' \
    'href=/enhancements/0001/decisions/>Decisions' \
    'href=https://github.com/open-platform-model/enhancements/blob/main/0001/schemas/target.cue' \
    'href=https://github.com/open-platform-model/enhancements/tree/main/0001/schemas' \
    'href=/v1.0/docs/start/>the start section'; do
    printf '%s' "$r" | grep -qF -- "$want" || why="${why:+$why; }missing: $want"
  done
  dq "$E/0002/index.html" | grep -qF 'href=/enhancements/0001/decisions/#d1>D1' || why="${why:+$why; }the archived entry's link to 0001's D1"
  dq "$E/index.html" | grep -qF 'href=/enhancements/0002/>0002' || why="${why:+$why; }the INDEX link to archive/0002"
  if [ -z "$why" ]; then ok "enhancements/links" "repository links map to section pages by id, other paths to GitHub (blob, tree), /docs/ into v1.0; a file-name label reads as its page"
  else bad "enhancements/links" "$why"; fi

  d=$E/0001/decisions/index.html
  if grep -qE 'id="?d1"?' "$d" && grep -qE 'id="?d2"?' "$d" && grep -qE 'id="?d1-a-first-decision"?' "$d"; then
    ok "enhancements/anchors" "a decision heading keeps its automatic id and gains d1, d2"
  else bad "enhancements/anchors" "no d1/d2 anchors on 0001's decisions" "$d"; fi

  why=""
  dq "$E/0001/index.html" | grep -qF 'name=robots content=noindex>' || why="the draft entry has no noindex"
  ! dq "$E/0002/index.html" | grep -qF 'content=noindex>' || why="${why:+$why; }the delivered entry has noindex"
  grep -q 'enhancements' "$P/llms.txt" "$P/sitemap.xml" && why="${why:+$why; }the section is in llms.txt or the sitemap"
  [ ! -e "$OUT/$name/site/public/latest/enhancements" ] || why="${why:+$why; }/latest/enhancements/ stubs"
  [ -f "$E/pagefind/pagefind.js" ] || why="${why:+$why; }no section Pagefind bundle"
  grep -qF 'enhancements/pagefind/' "$(find "$OUT/$name/site/public" -maxdepth 1 -name 'enhancements.*.pagefind.*js' | head -n 1)" 2>/dev/null || why="${why:+$why; }the section's search adapter does not load its bundle"
  grep -q 'Edit this page' "$E/0001/index.html" && why="${why:+$why; }an entry has an edit link"
  dq "$E/0001/index.html" | grep -qF 'class=opm-enh-status role=note data-pagefind-ignore=all data-status=draft' || why="${why:+$why; }no draft banner"
  if [ -z "$why" ]; then ok "enhancements/exclusions" "draft noindex, delivered indexed; out of llms.txt, the sitemap and /latest/; own search bundle; a status banner, no edit link"
  else bad "enhancements/exclusions" "$why"; fi

  why=""
  grep -rqF 'quokkabrief' "$E" && why="a planning comment reached the section"
  grep -qF 'author --&gt; platform' "$d" || why="${why:+$why; }the ASCII arrow is missing from the code block"
  grep -qE '<h1[^>]*>Enhancement 0001' "$E/0001/index.html" && why="${why:+$why; }the source title line was kept"
  if [ -z "$why" ]; then ok "enhancements/content" "comments and the title line stripped; an escaped --> in a code block passes the comment check"
  else bad "enhancements/content" "$why"; fi

  # A mermaid fence in the section is drawn: in a focusable, labelled
  # scroller, at its natural size, and only that page loads the vendored
  # Mermaid, fingerprinted with SRI; no other page loads it.
  why=""
  r=$(dq "$E/0001/index.html")
  printf '%s' "$r" | grep -qF '<div class=opm-enh-diagram tabindex=0 role=region aria-label=Diagram><pre class=mermaid>' || why="no focusable diagram scroller"
  printf '%s' "$r" | grep -qF '%%{init: {&#34;flowchart&#34;: {&#34;useMaxWidth&#34;: false}' || why="${why:+$why; }no useMaxWidth false directive"
  printf '%s' "$r" | grep -qE '<script defer src=/lib/mermaid/mermaid\.min\.581ed7d74bd9048d0e3a91363927d72ef22942d7722546b27f7cc29e35390eb8\.js integrity=sha256-[^ ]+ crossorigin=anonymous>' || why="${why:+$why; }the page does not load the pinned Mermaid with SRI"
  others=$(find "$OUT/$name/site/public" -name '*.html' -exec grep -lF 'lib/mermaid/' {} + | grep -vxF "$E/0001/index.html" | grep -vxF "$E/graph/index.html")
  [ -z "$others" ] || why="${why:+$why; }pages without a fence load Mermaid: $others"
  if [ -z "$why" ]; then ok "enhancements/diagrams" "a fence is drawn in a focusable scroller at natural size; only pages with a fence load the pinned Mermaid, with SRI"
  else bad "enhancements/diagrams" "$why"; fi
fi

# ---------------------------------------------------------------------------
# The Catalogs section, from the fixture bundles: unversioned pages at
# /catalogs/<name>/<segment>/, one tree per segment, the tab, the stamp.
if [ $rc -eq 0 ]; then
  K=$OUT/$name/site/public/catalogs
  log=$OUT/$name/log
  why=""
  for f in index.html opm/4.4/index.html opm/4.4/traits/backup-v1alpha1/index.html opm/4.4/resources/volumes/index.html \
    opm/4.5/index.html opm/4.5/traits/expose/index.html opm/edge/index.html opm/edge/policies/retention/index.html; do
    [ -f "$K/$f" ] || why="${why:+$why; }no $f"
  done
  [ ! -e "$K/opm/4.5/traits/backup-v1alpha1" ] || why="${why:+$why; }4.5 has 4.4's older apiVersion page"
  [ ! -e "$P/catalogs" ] || why="${why:+$why; }the section published under /v1.0/"
  grep -qF 'catalogs: 27 pages and 9 alias stubs expected, 36 built' "$log" || why="${why:+$why; }check-pages did not count 27 catalog pages and 9 stubs"
  if [ -z "$why" ]; then ok "catalogs/pages" "/catalogs/ and every page of 4.4, 4.5 and edge, each segment its own tree; nothing under /v1.0/"
  else bad "catalogs/pages" "$why" "$log"; fi

  why=""
  m=$K/opm/4.4/traits/backup/index.html
  for f in "$P/docs/start/quickstart/index.html" "$m" "$OUT/$name/site/public/enhancements/0001/index.html"; do
    nav=$(dq "$f" | grep -oE '<a title href=/(v1.0/docs/|v1.0/docs/reference/|catalogs/|enhancements/) ' | sed -E 's#.*href=([^ ]*) #\1#' | tr '\n' ' ')
    [ "$nav" = "/v1.0/docs/ /v1.0/docs/reference/ /catalogs/ /enhancements/ " ] || why="${why:+$why; }${f#"$OUT"/} navbar: $nav"
  done
  dq "$m" | grep -qE '<a title href=/catalogs/ class=[^>]*font-medium' || why="${why:+$why; }the tab is not current on a member"
  dq "$K/index.html" | grep -qE '<a title href=/catalogs/ class=[^>]*font-medium' || why="${why:+$why; }the tab is not current on /catalogs/"
  ! dq "$m" | grep -qE '<a title href=/v1.0/docs/ class=[^>]*font-medium' || why="${why:+$why; }Docs is current on a member"
  ! grep -q 'opm-version-label' "$m" || why="${why:+$why; }a member shows the site version label"
  [ ! -e "$OUT/$name/site/public/latest/catalogs" ] || why="${why:+$why; }/latest/catalogs/ stubs"
  if [ -z "$why" ]; then ok "catalogs/tab" "Docs, Reference, Catalogs, Enhancements in that order; Catalogs current on every catalog page; no version label, no /latest/ stub"
  else bad "catalogs/tab" "$why"; fi

  why=""
  r=$(dq "$m")
  for want in 'href=/catalogs/opm/4.4/resources/volumes/>Volumes' 'href=/catalogs/opm/4.4/#contract-levels>contract levels' \
    'href=/v1.0/docs/concepts/>what enforces a rule' \
    'href=https://github.com/open-platform-model/catalog_opm/blob/dbefd8645e236dd07060772eaa5857c926b0b44f/opm/traits/v1alpha2/backup.cue' \
    'class=hextra-badge opm-type-badge' '<span>opm catalog 4.4</span>'; do
    printf '%s' "$r" | grep -qF -- "$want" || why="${why:+$why; }missing: $want"
  done
  ! grep -q 'Edit this page' "$m" || why="${why:+$why; }a member has an edit link"
  nav=$OUT/$name/site/.check/catalogs/nav-order-catalogs-4.4.txt
  [ "$(grep -c '^/catalogs/opm/' "$nav")" -gt 0 ] && ! grep -qE '^/catalogs/opm/(4\.5|edge)/' "$nav" || why="${why:+$why; }4.4's sidebar holds another segment: $nav"
  [ "$(line_of /catalogs/opm/4.4/blueprints/ "$nav")" -lt "$(line_of /catalogs/opm/4.4/resources/ "$nav")" ] &&
    [ "$(line_of /catalogs/opm/4.4/resources/ "$nav")" -lt "$(line_of /catalogs/opm/4.4/traits/ "$nav")" ] || why="${why:+$why; }4.4's kinds are not in weight order"
  grep -qF '](https://opmodel.dev/catalogs/opm/4.4/resources/volumes/)' "$K/opm/4.4/traits/backup/index.md" || why="${why:+$why; }the .md output does not link absolute"
  if [ -z "$why" ]; then ok "catalogs/content" "own-segment and /docs/ links resolve; View source at the bundle commit, no edit link; type badge; footer names catalog and segment; the sidebar is the segment's, kinds in weight order"
  else bad "catalogs/content" "$why"; fi

  # The switch: newest minor first, edge last; the same page where the
  # segment has it, else the nearest parent, else the landing.
  items() { dq "$1" | grep -oE 'role=menuitem href=[^ >]+[^>]*data-segment=[^ >]+' | sed -E 's#role=menuitem href=([^ >]+).*data-segment=([^ >]+)#\2=\1#' | tr '\n' ' '; }
  why=""
  got=$(items "$K/opm/4.4/traits/backup-v1alpha1/index.html")
  [ "$got" = "4.5=/catalogs/opm/4.5/traits/ 4.4=/catalogs/opm/4.4/traits/backup-v1alpha1/ edge=/catalogs/opm/edge/traits/ " ] || why="4.4 backup-v1alpha1: $got"
  got=$(items "$K/opm/4.5/traits/expose/index.html")
  [ "$got" = "4.5=/catalogs/opm/4.5/traits/expose/ 4.4=/catalogs/opm/4.4/traits/ edge=/catalogs/opm/edge/traits/expose/ " ] || why="${why:+$why; }4.5 expose: $got"
  got=$(items "$K/opm/edge/policies/retention/index.html")
  [ "$got" = "4.5=/catalogs/opm/4.5/ 4.4=/catalogs/opm/4.4/ edge=/catalogs/opm/edge/policies/retention/ " ] || why="${why:+$why; }edge retention: $got"
  r=$(dq "$K/opm/4.4/traits/backup-v1alpha1/index.html")
  printf '%s' "$r" | grep -qF 'aria-label=Catalog version: opm 4.4' || why="${why:+$why; }the button does not name opm 4.4"
  printf '%s' "$r" | grep -qE 'data-segment=4.5 class=opm-version-item[^>]*><span>4.5</span><span class=opm-version-tag>latest</span><span class=opm-version-hint>parent page</span>' || why="${why:+$why; }4.5 is not marked latest and parent page"
  dq "$K/opm/edge/index.html" | grep -qF '<span>main (unreleased)</span>' || why="${why:+$why; }edge is not labelled main (unreleased)"
  if [ -z "$why" ]; then ok "catalogs/switch" "4.5, 4.4, main (unreleased) in that order; same page, else the nearest parent (traits/), else the landing; newest marked latest"
  else bad "catalogs/switch" "$why"; fi

  # Indexing: only the newest minor of each major is indexed, in llms.txt
  # and in the sitemap (with the manifest's lastmod); 4.4 and edge are not.
  why=""
  for f in "$K/index.html" "$K/opm/4.5/index.html" "$K/opm/4.5/traits/backup/index.html"; do
    ! dq "$f" | grep -qF 'name=robots content=noindex' || why="${why:+$why; }${f#"$K"/} has noindex"
  done
  for f in "$K/opm/4.4/index.html" "$K/opm/4.4/traits/backup/index.html" "$K/opm/edge/index.html" "$K/opm/edge/traits/expose/index.html"; do
    dq "$f" | grep -qF 'name=robots content=noindex>' || why="${why:+$why; }${f#"$K"/} has no noindex"
  done
  grep -qF '](https://opmodel.dev/catalogs/opm/4.5/traits/backup/)' "$P/llms.txt" || why="${why:+$why; }llms.txt lacks 4.5 backup"
  ! grep -qE 'catalogs/opm/(4\.4|edge)/' "$P/llms.txt" || why="${why:+$why; }llms.txt lists 4.4 or edge"
  tr -d '\n ' < "$P/sitemap.xml" | grep -qF '<loc>https://opmodel.dev/catalogs/opm/4.5/traits/backup/</loc><lastmod>2026-09-28T08:30:00' || why="${why:+$why; }the sitemap lacks 4.5 backup with its lastmod"
  tr -d '\n ' < "$P/sitemap.xml" | grep -qF '<loc>https://opmodel.dev/catalogs/</loc><lastmod>2026-09-28T08:30:00' || why="${why:+$why; }the sitemap lacks /catalogs/ with 4.5's lastmod (not edge's)"
  [ "$(grep -n '^## ' "$P/llms.txt" | sed 's/^[0-9]*:## //' | tr '\n' '|')" = "Documentation|Catalogs|" ] || why="${why:+$why; }llms.txt does not list Documentation, then Catalogs"
  ! grep -qE 'catalogs/opm/(4\.4|edge)/' "$P/sitemap.xml" || why="${why:+$why; }the sitemap lists 4.4 or edge"
  if [ -z "$why" ]; then ok "catalogs/indexing" "/catalogs/ and 4.5 indexed, in llms.txt after the docs and in the sitemap (manifest lastmod, edge's never); 4.4 and edge noindex and in neither"
  else bad "catalogs/indexing" "$why"; fi

  # Aliases: _redirects lines and meta-refresh stubs to the newest minor;
  # none to edge.
  R=$OUT/$name/site/public
  why=""
  for l in '/catalogs/opm/ /catalogs/opm/4.5/ 302' '/catalogs/opm/4/ /catalogs/opm/4.5/ 302' '/catalogs/opm/4/* /catalogs/opm/4.5/:splat 302'; do
    grep -qxF "$l" "$R/_redirects" || why="${why:+$why; }_redirects lacks: $l"
  done
  ! grep -q edge "$R/_redirects" || why="${why:+$why; }_redirects names edge"
  [ "$(sed -n 2p "$R/_redirects")" = '/latest/* /v1.0/:splat 302' ] || why="${why:+$why; }the /latest/ line moved"
  [ "$(refresh_of "$K/opm/index.html")" = /catalogs/opm/4.5/ ] || why="${why:+$why; }/catalogs/opm/ stub"
  [ "$(refresh_of "$K/opm/4/index.html")" = /catalogs/opm/4.5/ ] || why="${why:+$why; }/catalogs/opm/4/ stub"
  [ "$(refresh_of "$K/opm/4/traits/backup/index.html")" = /catalogs/opm/4.5/traits/backup/ ] || why="${why:+$why; }/catalogs/opm/4/traits/backup/ stub"
  grep -qF 'content="noindex"' "$K/opm/4/traits/backup/index.html" || why="${why:+$why; }a stub without noindex"
  [ ! -e "$K/opm/4/policies" ] && [ ! -e "$K/opm/4/traits/backup-v1alpha1" ] || why="${why:+$why; }a stub for a page the newest minor lacks"
  if [ -z "$why" ]; then ok "catalogs/aliases" "/catalogs/opm/ and /catalogs/opm/4/... go to 4.5 as _redirects lines and noindex stubs; nothing goes to edge"
  else bad "catalogs/aliases" "$why"; fi

  # Search: each segment has its own Pagefind bundle, and a catalog page's
  # adapter loads its segment's.
  why=""
  for sg in 4.4 4.5 edge; do
    [ -f "$K/opm/$sg/pagefind/pagefind.js" ] || why="${why:+$why; }no Pagefind bundle in $sg"
    a=$(find "$R" -maxdepth 1 -name "catalogs-opm-$sg.*.pagefind.*js" | head -n 1)
    grep -qF "catalogs/opm/$sg/pagefind/" "$a" 2>/dev/null || why="${why:+$why; }$sg's search adapter does not load its bundle"
  done
  if [ -z "$why" ]; then ok "catalogs/search" "4.4, 4.5 and edge each have a Pagefind bundle, and their pages' search loads it"
  else bad "catalogs/search" "$why"; fi

  # Docs pages link the tab through the bare root and the major alias; the
  # site writes the newest 4.x minor's URL, and the .md output the alias.
  why=""
  r=$(dq "$P/docs/concepts/catalog-links/index.html")
  for want in 'href=/catalogs/opm/4.5/>opm catalog' 'href=/catalogs/opm/4.5/>newest 4.x' 'href=/catalogs/opm/4.5/traits/backup/#spec>the backup trait'; do
    printf '%s' "$r" | grep -qF -- "$want" || why="${why:+$why; }missing: $want"
  done
  grep -qF '](https://opmodel.dev/catalogs/opm/4/traits/backup/#spec)' "$P/docs/concepts/catalog-links.md" || why="${why:+$why; }the .md output does not link the absolute alias"
  if [ -z "$why" ]; then ok "catalogs/docs-links" "/catalogs/opm/ and /catalogs/opm/4/... resolve to /catalogs/opm/4.5/..., fragment kept; the .md output keeps the alias, absolute"
  else bad "catalogs/docs-links" "$why"; fi

  st=$OUT/$name/site/public/build-stamp.json
  got=$(jq -r '.sections.catalogs | "\(.from) \(.frozen) \(.lock | test("^sha256:[0-9a-f]{64}$")) \([.bundles[] | "\(.project)/\(.segment)/\(.version)/\(.local)"] | join(","))"' "$st" 2>/dev/null)
  if [ "$got" = "explicit false true catalog-opm/4.5/4.5.0/true,catalog-opm/4.4/4.4.5/true,catalog-opm/edge/edge/true" ] &&
     [ "$(jq -r '.sections.enhancements.ref' "$st")" = worktree ]; then
    ok "catalogs/stamp" "build-stamp.json's sections.catalogs records from, not frozen, the lock digest and every bundle (local); sections.enhancements kept"
  else bad "catalogs/stamp" "sections.catalogs is \"$got\"" "$st"; fi
fi

# ---------------------------------------------------------------------------
# Manifest mode (no OPM_VERSIONS, a resolved .versions/versions.tsv, as
# task build runs) with bundles.cue and a lock pulled for it: the section is
# required and read from site/.bundles/, CAT_FROM manifest.
name=catalogs/manifest
copy_site "$name"
mkdir -p "$OUT/$name/site/.versions/v1.0"
cp -R "$WS/." "$OUT/$name/site/.versions/v1.0/"
rm -rf "$OUT/$name/site/.versions/v1.0/enhancements"
printf 'v1.0\tv1.0 (manifest)\t1\ttrue\tanchored\n' > "$OUT/$name/site/.versions/versions.tsv"
# As a frozen pull leaves it: the marker run-in-image.sh writes.
echo site/bundles.frozen.json > "$OUT/$name/site/.bundles/frozen"
(SITE_DIR=$OUT/$name/site sh "$SCRIPTS/build-all.sh") > "$OUT/$name/log" 2>&1; rc=$?
st=$OUT/$name/site/public/build-stamp.json
if [ $rc -eq 0 ] && grep -qF "build-all: catalogs section from $OUT/$name/site/.bundles (manifest)" "$OUT/$name/log" &&
   [ "$(jq -r '.sections.catalogs | "\(.from) \(.frozen)"' "$st")" = "manifest true" ] && [ -f "$OUT/$name/site/public/catalogs/opm/4.5/index.html" ]; then
  ok "$name" "manifest mode with bundles.cue and its lock builds the section from site/.bundles/ (manifest); a frozen pull's marker shows as "frozen": true"
else bad "$name" "the manifest-mode build failed or did not read site/.bundles/ (exit $rc)" "$OUT/$name/log"; fi

# ---------------------------------------------------------------------------
# The fixture workspace without docs bundles: no Catalogs section and no tab.
name=no-catalogs
copy_site "$name"; copy_ws "$name"
rm -rf "$OUT/$name/site/.bundles" "$OUT/$name/site/bundles.cue" "$OUT/$name/ws/core/docs/site/concepts/catalog-links.md"
build "$name" "$OUT/$name/ws"; rc=$?
P=$OUT/$name/site/public/v1.0
if [ $rc -ne 0 ]; then bad "$name" "the build without bundles failed (exit $rc)" "$OUT/$name/log"
else
  why=""
  [ ! -e "$OUT/$name/site/public/catalogs" ] || why="public/catalogs exists"
  ! dq "$P/docs/start/quickstart/index.html" | grep -qF 'href=/catalogs/' || why="${why:+$why; }a Catalogs tab"
  ! grep -q '^/catalogs/' "$OUT/$name/site/public/_redirects" || why="${why:+$why; }_redirects has catalog lines"
  if [ -z "$why" ]; then ok "$name" "no section, no tab, no catalog _redirects lines"
  else bad "$name" "$why" "$OUT/$name/log"; fi
fi

# ---------------------------------------------------------------------------
# The fixture workspace under a two-segment base path (tests/subpath/env): the
# build is green with the crawl's base-path rules, and every URL a reader, a
# crawler or the search palette meets carries /opm/docs/.
name=subpath
copy_site "$name"
build "$name" "$WS" "$TESTS/subpath/env"; rc=$?
log=$OUT/$name/log
R=$OUT/$name/site/public
P=$R/v1.0
B=https://pages.example/opm/docs
if [ $rc -eq 0 ]; then ok "$name" "the fixture workspace builds green under $B/"; else bad "$name" "the subpath build failed (exit $rc)" "$log"; fi

if [ $rc -eq 0 ]; then
  if [ "$(refresh_of "$R/index.html")" = /opm/docs/latest/ ] && dq "$R/index.html" | grep -qF 'href=/opm/docs/latest/>' &&
     grep -qxF '/ /latest/ 302' "$R/_redirects"; then
    ok "$name/root" "the root index.html refreshes and links to /opm/docs/latest/; _redirects still sends / to /latest/"
  else bad "$name/root" "the root index.html does not lead to /opm/docs/latest/, or _redirects changed" "$R/index.html"; fi

  if [ "$(refresh_of "$R/latest/index.html")" = /opm/docs/v1.0/ ] &&
     [ "$(refresh_of "$R/latest/docs/start/quickstart/index.html")" = /opm/docs/v1.0/docs/start/quickstart/ ]; then
    ok "$name/latest" "the /latest/ stubs refresh to /opm/docs/v1.0/..."
  else bad "$name/latest" "a /latest/ stub does not refresh into /opm/docs/v1.0/"; fi

  if dq "$R/404.html" | grep -qF 'href=/opm/docs/v1.0/docs/>Go to the docs'; then
    ok "$name/404" "the root 404.html leads to /opm/docs/v1.0/docs/"
  else bad "$name/404" "the root 404.html's Go to the docs link is not /opm/docs/v1.0/docs/"; fi

  adapter=$(find "$R" -maxdepth 1 -name 'v1.0.*.pagefind.*js' | head -n 1)
  if [ -n "$adapter" ] && grep -qF '/opm/docs/v1.0/pagefind/' "$adapter" && dq "$adapter" | grep -qF 'baseUrl:/opm/docs/v1.0/'; then
    ok "$name/search" "the Pagefind adapter loads /opm/docs/v1.0/pagefind/ and passes baseUrl /opm/docs/v1.0/"
  else bad "$name/search" "the Pagefind adapter (${adapter:-not found}) misses the bundle path or baseUrl under /opm/docs/"; fi

  cssroot=$(find "$R" -name '*.css' -exec grep -lE "url\([\"']?/" {} + 2>/dev/null)
  if [ -z "$cssroot" ] && grep -qF '"start_url": "./"' "$R/site.webmanifest" && ! grep -qE '":[[:space:]]*"/' "$R/site.webmanifest"; then
    ok "$name/assets" "no CSS url() is root-relative; site.webmanifest's start_url is ./ and no value starts with /"
  else bad "$name/assets" "a root-relative asset URL: ${cssroot:-site.webmanifest}"; fi

  jsroot=$(find "$R" -name '*.js' ! -path '*/pagefind/*' -exec grep -lE "['\"\`]/(v[0-9]|latest|docs|pagefind|css|js|fonts|images)" {} + 2>/dev/null)
  if [ -z "$jsroot" ]; then ok "$name/js" "no published script holds a root-path string literal"
  else bad "$name/js" "root-path string literal in: $jsroot"; fi

  q=$P/docs/start/quickstart/index.html
  why=""
  dq "$q" | grep -qF "rel=canonical href=$B/v1.0/docs/start/quickstart/" || why="canonical"
  dq "$q" | grep -qF "property=og:url content=$B/v1.0/docs/start/quickstart/" || why="${why:+$why, }og:url"
  dq "$q" | grep -qF "property=og:image content=$B/images/og-default.png" || why="${why:+$why, }og:image"
  dq "$q" | grep -qF "name=twitter:image content=$B/images/og-default.png" || why="${why:+$why, }twitter:image"
  dq "$q" | grep -qF "itemprop=image content=$B/images/og-default.png" || why="${why:+$why, }itemprop image"
  grep -qxF "Site: $B/" "$P/llms.txt" || why="${why:+$why, }llms.txt Site"
  if [ -z "$why" ]; then ok "$name/absolute" "canonical, og:url, og:image, twitter:image, itemprop image and llms.txt carry $B/"
  else bad "$name/absolute" "not under $B/: $why"; fi

  if grep -qF "]($B/v1.0/docs/concepts/fixture-concept/#why)" "$P/docs/start/quickstart.md"; then
    ok "$name/markdown" "quickstart.md links to $B/v1.0/docs/concepts/fixture-concept/#why"
  else bad "$name/markdown" "quickstart.md does not link under $B/v1.0/"; fi

  pages=$(find "$P" -name index.html ! -path "$P/pagefind/*" | sort)
  unmarked=$(printf '%s\n' "$pages" | while IFS= read -r f; do dq "$f" | grep -qF 'name=robots content=noindex, nofollow' || echo "$f"; done)
  if [ -n "$pages" ] && [ -z "$unmarked" ]; then
    ok "$name/noindex" "all $(printf '%s\n' "$pages" | wc -l | tr -d ' ') version pages carry the robots noindex tag"
  else bad "$name/noindex" "version pages without the robots noindex tag: $(printf '%s' "$unmarked" | head -n 3 | tr '\n' ' ')"; fi

  if cmp -s "$OUT/$name/site/.check/v1.0/nav-order.txt" "$OUT/fixture/site/.check/v1.0/nav-order.txt"; then
    ok "$name/nav" "nav-order.txt holds the same site-root paths as the fixture build"
  else bad "$name/nav" "nav-order.txt differs from the fixture build's" "$OUT/$name/site/.check/v1.0/nav-order.txt"; fi
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
  # A NOTE whose bold title line is Direction is a direction note: labelled
  # Direction, its title line not repeated, in the opm-direction box; the
  # other note on the page stays a Note. Its /enhancements/ links resolve to
  # the unversioned section, in the page and as absolute URLs in its .md.
  g=$OUT/$name/site/public/v1.0/docs/start/direction/index.html
  why=""
  r=$(dq "$g" | tr '\n' ' ')
  [ "$(printf '%s' "$r" | grep -o 'class=opm-direction' | wc -l | tr -d ' ')" = 1 ] || why="not exactly one opm-direction box"
  printf '%s' "$r" | grep -qE 'class=opm-direction> *<div data-alert=note class=hextra-alert> *<p class=hextra-alert-title>.*<span class=hextra-alert-title-text>Direction</span></p> *<div class=hextra-alert-content> *<p>Enhancement 0001' || why="${why:+$why; }the direction note is not labelled Direction with its body first"
  printf '%s' "$r" | grep -qF '<strong>Direction</strong>' && why="${why:+$why; }the Direction title line is repeated"
  printf '%s' "$r" | grep -qE 'hextra-alert-title-text>Note</span></p> *<div class=hextra-alert-content> *<p><strong>Not a direction</strong>' || why="${why:+$why; }the ordinary note changed"
  for want in 'href=/enhancements/0001/>Fixture Live Entry' 'href=/enhancements/0001/decisions/#d1>first decision' 'href=/enhancements/>all enhancements'; do
    printf '%s' "$r" | grep -qF -- "$want" || why="${why:+$why; }missing: $want"
  done
  grep -qF '](https://opmodel.dev/enhancements/0001/decisions/#d1)' "${g%/index.html}.md" || why="${why:+$why; }the .md output does not link https://opmodel.dev/enhancements/0001/decisions/#d1"
  if [ -z "$why" ]; then ok "$name/direction" "a Direction note is labelled Direction in its own box, the plain note stays Note; /enhancements/ links resolve, absolute in the .md"
  else bad "$name/direction" "$why" "$g"; fi
  # Chroma marks a Name with class n: the field after each "" must be one.
  cue=$(tr -d '\n' < "$f")
  after='&#34;&#34;</span></span></span><span class="\{0,1\}line"\{0,1\}><span class="\{0,1\}cl"\{0,1\}>	<span class="\{0,1\}n"\{0,1\}>'
  if printf '%s' "$cue" | grep -q "${after}replicas</span>" && printf '%s' "$cue" | grep -q "${after}name</span>" &&
     ! grep -q OPMEMPTYSTRING "$f"; then
    ok "$name/cue" "the line after a CUE \"\" is tokenised as a name; no placeholder is left"
  else bad "$name/cue" "the CUE \"\" swallowed the lines after it"; fi
fi

# ---------------------------------------------------------------------------
# The dialect tree as two versions: the Enhancements section lives in the
# default version's page tree only, and a source link into it resolves to the
# same unversioned URL from the other version too.
name=dialect-two-versions
copy_site "$name"; copy_ws "$name"; overlay "$name" "$TESTS/dialect"
(SITE_DIR=$OUT/$name/site OPM_VERSIONS="v1.0=$OUT/$name/ws v0.9=$OUT/$name/ws" sh "$SCRIPTS/build-all.sh") > "$OUT/$name/log" 2>&1; rc=$?
if [ $rc -ne 0 ]; then bad "$name" "the two-version dialect build failed (exit $rc)" "$OUT/$name/log"
else
  why=""
  for v in v1.0 v0.9; do
    g=$OUT/$name/site/public/$v/docs/start/direction/index.html
    dq "$g" | grep -qF 'href=/enhancements/0001/decisions/#d1>first decision' || why="${why:+$why; }$v does not link /enhancements/0001/decisions/#d1"
  done
  [ ! -e "$OUT/$name/site/public/v0.9/enhancements" ] || why="${why:+$why; }the section published under v0.9"
  if [ -z "$why" ]; then ok "$name/enhancement-links" "a source link into the section resolves to /enhancements/... from the default and the other version"
  else bad "$name/enhancement-links" "$why"; fi
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
