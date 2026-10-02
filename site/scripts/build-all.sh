#!/bin/sh
# The site build. Runs inside the build image (site/Dockerfile) with the
# repo at /work/repo and each source root read-only at /src/<repo>, with no
# network (site/scripts/run-in-image.sh build). Every step fails the build.
#
#   build-all.sh [--public DIR] [--check DIR]
#
# DIR is relative to SITE_DIR: the site goes to --public (default public) and
# each version's nav-order.txt to --check (default .check). The two-version
# regression test (site/tests/versions/check-two-versions.sh) builds into
# .check/versions-test/, so it never touches public/ or .check/<version>/.
#
# Env: SITE_DIR           the site tree to build (default: this script's site/,
#                         /work/repo/site); test-site.sh points it at a copy
#      OPM_VERSIONS       name=root ...: an explicit version set (fixture builds); each
#                         root holds <repo>/docs/site. Unset: the versions that
#                         task versions:prepare resolved into .versions/versions.tsv
#      OPM_REQUIRE_DATES  1: a page without a git date fails the build
#      OPM_BUILD_REFS     repo=sha ..., resolved on the host (the build stamp)
#      OPM_BASE_URL       the site's base URL for this build: an absolute http(s)
#                         URL ending in /, which may carry a path
#                         (https://example.org/docs/). Passed to hugo as
#                         --baseURL only when set; unset, hugo.toml's baseURL
#                         holds and the hugo invocation is unchanged
#
# Exports to the checks: BASE_URL, the resolved base URL, and BASE_PATH, its
# path without the trailing slash ("" at a host root, /docs under a path).
set -eu
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
SITE_DIR=${SITE_DIR:-$(cd "$SCRIPTS/.." && pwd)}
export SITE_DIR
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
t0=$(date +%s)
step() { printf '\n== %s\n' "$*"; }
fail() { echo "$*"; exit 1; }
PUBLIC=public; CHECK_DIR=.check
while [ $# -gt 0 ]; do
  case "$1" in
    --public) [ $# -ge 2 ] || fail "build-all: --public needs a directory"; PUBLIC=$2; shift 2 ;;
    --check) [ $# -ge 2 ] || fail "build-all: --check needs a directory"; CHECK_DIR=$2; shift 2 ;;
    *) fail "build-all: unknown argument $1 (--public DIR, --check DIR)" ;;
  esac
done
export PUBLIC CHECK_DIR
# The base URL: OPM_BASE_URL, else hugo.toml's baseURL. Without the trailing
# slash Hugo joins paths wrongly and silently, so the build fails first.
OPM_BASE_URL=${OPM_BASE_URL:-}
BASE_URL=${OPM_BASE_URL:-$(sed -n "s/^baseURL = '\(.*\)'\$/\1/p" config/_default/hugo.toml)}
case "$BASE_URL" in
  http://?*/|https://?*/) ;;
  *) fail "build-all: the base URL must be an absolute http(s) URL ending in / (OPM_BASE_URL, else hugo.toml's baseURL): '$BASE_URL'" ;;
esac
BASE_PATH=/${BASE_URL#*://*/}; BASE_PATH=${BASE_PATH%/}
export BASE_URL BASE_PATH
echo "build-all: base URL $BASE_URL${BASE_PATH:+ (base path $BASE_PATH)}"
# The versions, in weight order, and the default one (/latest/ and / point at
# it): an explicit OPM_VERSIONS (the first is the default), else the resolved
# .versions/versions.tsv (a source = main version reads /src, an anchored or a
# line one its archive in .versions/<v>/), else v1.0=/src.
if [ -n "${OPM_VERSIONS:-}" ]; then
  VERSIONS=$OPM_VERSIONS; DEFAULT=${VERSIONS%%=*}
elif [ -f .versions/versions.tsv ]; then
  VERSIONS=$(awk -F'\t' -v S="$SITE_DIR" '/^#/ { next } !($1 in seen) { seen[$1]; printf "%s%s=%s", (n++ ? " " : ""), $1, ($5 == "main" ? "/src" : S "/.versions/" $1) }' .versions/versions.tsv)
  DEFAULT=$(awk -F'\t' '!/^#/ && $4 == "true" { print $1; exit }' .versions/versions.tsv)
else
  VERSIONS=v1.0=/src; DEFAULT=v1.0
fi
[ -n "$VERSIONS" ] && [ -n "$DEFAULT" ] || fail "build-all: no versions to build"
echo "build-all: versions $VERSIONS (default $DEFAULT)"
# The enhancements section (site/enhancements/), unversioned: in manifest mode
# the archive materialise.sh wrote for versions.tsv's "# section enhancements"
# line, at the SHA it names; in explicit mode the enhancements/ beside the
# default version's repositories (/src/enhancements, which run-in-image.sh
# mounts; a fixture workspace's own), read in place, when it holds INDEX.md,
# at the commit OPM_BUILD_REFS names for it. Otherwise there is no section.
# gen-stamp.sh, gen-mounts.sh and check-pages.sh read the ENH_* values;
# ENH_PATHS is materialise.sh's list of every path at that SHA.
ENH_TREE=""; ENH_PATHS=""; ENH_REF=""; ENH_SHA=""; ENH_HOW=""
if [ -n "${OPM_VERSIONS:-}" ] || [ ! -f .versions/versions.tsv ]; then
  r=${VERSIONS%% *}; r=${r#*=}
  if [ -f "$r/enhancements/INDEX.md" ]; then
    ENH_TREE=$r/enhancements; ENH_REF=worktree; ENH_HOW=explicit
    if [ "$r" = /src ]; then
      for p in ${OPM_BUILD_REFS:-}; do case "$p" in enhancements=*) ENH_SHA=${p#*=} ;; esac; done
      [ "$ENH_SHA" != none ] || ENH_SHA=""
    fi
  fi
else
  line=$(awk -F'\t' '$1 == "# section" && $2 == "enhancements"' .versions/versions.tsv)
  if [ -n "$line" ]; then
    ENH_TREE=$SITE_DIR/.versions/enhancements/tree; ENH_PATHS=$SITE_DIR/.versions/enhancements/paths.txt
    ENH_REF=$(printf '%s' "$line" | cut -f3); ENH_SHA=$(printf '%s' "$line" | cut -f4); ENH_HOW=$(printf '%s' "$line" | cut -f5)
    [ -f "$ENH_TREE/INDEX.md" ] || fail "build-all: versions.tsv names the enhancements section at $ENH_SHA, but $ENH_TREE holds no INDEX.md; run task versions:prepare"
  fi
fi
export ENH_TREE ENH_PATHS ENH_REF ENH_SHA ENH_HOW
if [ -n "$ENH_TREE" ]; then echo "build-all: enhancements section from $ENH_TREE (${ENH_SHA:-no commit}, $ENH_HOW)"
else echo "build-all: no enhancements section"; fi

step "drift guard: overridden theme files unchanged upstream"
sh "$SCRIPTS/check-overrides.sh"

step "vendored files match their pins"
sh "$SCRIPTS/check-vendored.sh"

step "source lint"
dirs=""
for pair in $VERSIONS; do
  root=${pair#*=}
  for r in $REPOS; do dirs="$dirs $root/$r/docs/site"; done
done
# shellcheck disable=SC2086 # the roots hold no spaces
sh "$SCRIPTS/lint-sources.sh" $dirs

step "dates, stamp, mounts, collisions"
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-lastmod.sh" $VERSIONS
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-stamp.sh" $VERSIONS
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-mounts.sh" config/production/module.toml $VERSIONS
# shellcheck disable=SC2086
sh "$SCRIPTS/check-pages.sh" pre $VERSIONS

step "hugo build ($(hugo version | cut -d' ' -f1-2))"
if [ -n "$OPM_BASE_URL" ]; then set -- --baseURL "$OPM_BASE_URL"; else set --; fi
hugo build --gc --cleanDestinationDir --panicOnWarning --logLevel warn --destination "$PUBLIC" "$@"

step "root files and search, per version"
[ -f "$PUBLIC/$DEFAULT/404.html" ] || fail "ROOT FAIL: $PUBLIC/$DEFAULT/404.html was not built"
# _redirects is Cloudflare's; a host that ignores it (GitHub Pages) routes
# through the root index.html and the /latest/ stubs, which carry the base path.
printf '/ /latest/ 302\n/latest/* /%s/:splat 302\n' "$DEFAULT" > "$PUBLIC/_redirects"
printf '<!doctype html><meta charset="utf-8"><meta name="robots" content="noindex"><meta http-equiv="refresh" content="0; url=%s/latest/"><title>Open Platform Model</title><a href="%s/latest/">%s/latest/</a>\n' "$BASE_PATH" "$BASE_PATH" "$BASE_PATH" > "$PUBLIC/index.html"
cp "$PUBLIC/$DEFAULT/404.html" "$PUBLIC/404.html"
cp data/opm/build.json "$PUBLIC/build-stamp.json"
for pair in $VERSIONS; do
  v=${pair%%=*}
  pagefind --site "$PUBLIC/$v" --root-selector 'main#content > .content' \
    --exclude-selectors '.hextra-page-context-menu, .opm-type-badge, .hextra-code-copy-btn, figure svg' \
    --quiet
  printf '%s: pagefind %s pages, %s\n' "$v" "$(find "$PUBLIC/$v/pagefind/fragment" -type f | wc -l | tr -d ' ')" "$(du -sh "$PUBLIC/$v/pagefind" | cut -f1)"
done
# The Enhancements section has its own bundle, so the docs search never
# returns a design (layouts/_partials/scripts/search.html picks it).
if [ -n "$ENH_TREE" ]; then
  [ -f "$PUBLIC/enhancements/index.html" ] || fail "ENHANCEMENTS FAIL: $PUBLIC/enhancements/index.html was not built"
  pagefind --site "$PUBLIC/enhancements" --root-selector 'main#content > .content' \
    --exclude-selectors '.hextra-page-context-menu, .hextra-code-copy-btn, .opm-enh-status, .opm-enh-meta' \
    --quiet
  printf 'enhancements: pagefind %s pages, %s\n' "$(find "$PUBLIC/enhancements/pagefind/fragment" -type f | wc -l | tr -d ' ')" "$(du -sh "$PUBLIC/enhancements/pagefind" | cut -f1)"
fi

step "page set, stray files, sidebar order, links"
# shellcheck disable=SC2086
sh "$SCRIPTS/check-pages.sh" post $VERSIONS

step "output guards"
# Check 12: the redirect files and root files are present.
for f in _redirects index.html 404.html robots.txt latest/index.html build-stamp.json; do
  [ -s "$PUBLIC/$f" ] || fail "REDIRECT FAIL: $PUBLIC/$f is missing"
done
grep -qxF '/ /latest/ 302' "$PUBLIC/_redirects" || fail "REDIRECT FAIL: $PUBLIC/_redirects does not send / to /latest/"
echo "redirects: _redirects, root index.html, 404.html, robots.txt and the /latest/ stubs present"
# Check 9: a Starlight aside that reached the output as text.
raw=$(find "$PUBLIC" -name '*.html' -exec grep -l -e '<p>:::' -e '^:::' {} + || true)
[ -z "$raw" ] || fail "DIALECT FAIL: literal ':::' published in:
$(echo "$raw" | sed 's/^/  /')"
echo "dialect: no raw ':::' in $PUBLIC/"
# Check 10: planning comments (<!-- ... -->) reach no published text, not as a
# comment and not as visible text: a brief that Markdown escaped (a table cell
# holding "|", an indented or blank-line-split brief) shows up as &lt;!-- or
# --&gt;, or, once the typographer has turned "--" into a dash, as &lt;!&ndash;.
leak=$(find "$PUBLIC" \( -name '*.html' -o -name '*.txt' -o -name '*.md' -o -name '*.xml' -o -name '*.json' \) -exec grep -l -e '<!--' {} + || true)
# A closing --> inside <pre> or <code> is code (an arrow in an ASCII diagram,
# a Mermaid edge shown as source), so that half ignores code; an opening <!--
# counts everywhere, an indented brief rendered as a code block included.
shown=$(find "$PUBLIC" -name '*.html' -exec grep -lE -e '&lt;!(--|&ndash;|&mdash;)' {} + || true)
closing=$(find "$PUBLIC" -name '*.html' -exec grep -lE -e '(--|&ndash;|&mdash;)&gt;' {} + || true)
for f in $closing; do
  tr '\n' ' ' < "$f" | awk '{
      s = $0; out = ""
      while (match(s, /<(pre|code)[ >]/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2); out = out substr(s, 1, RSTART - 1); s = substr(s, RSTART)
        e = index(s, "</" t ">"); if (e == 0) { s = ""; break }
        s = substr(s, e + length(t) + 3)
      }
      print out s
    }' | grep -qE '(--|&ndash;|&mdash;)&gt;' && shown="$shown
$f"
done
[ -z "$leak$shown" ] || fail "COMMENT FAIL: a planning comment reached:
$(printf '%s\n%s\n' "$leak" "$shown" | sed '/^$/d; s/^/  /')"
echo "comments: no HTML comment in any published text, escaped or not"
# Check 11: nothing is loaded from another host at run time. Every URL a tag
# loads (src, srcset, poster, data, xlink:href, and href on a link other than
# rel=canonical or rel=alternate) must be relative or start with the build's
# own base URL (BASE_URL); so must every CSS url() and @import, in *.css and in
# the pages. BASE_URL is compared as a literal prefix with awk's index(), never
# inside a regex, where its dots would match any character. A plain <a href>
# loads nothing and may point anywhere.
ext=$(find "$PUBLIC" -name '*.html' | sort | while IFS= read -r f; do
  tr '\n' ' ' < "$f" | grep -oiE '<(script|link|img|iframe|source|video|audio|embed|object|track|image)([ \t][^>]*)?>' |
    awk -v F="${f#"$PUBLIC"/}" -v B="$BASE_URL" '
      {
        low = tolower($0)
        if (low ~ /^<link/ && low ~ /[ \t]rel="?(canonical|alternate)[" \t>]/) next
        s = $0
        while (match(s, /[ \t](srcset|src|href|poster|data|xlink:href)=("[^"]*"|[^ \t">]+)/)) {
          a = substr(s, RSTART + 1, RLENGTH - 1); s = substr(s, RSTART + RLENGTH)
          name = a; sub(/=.*/, "", name); v = a; sub(/^[^=]*=/, "", v); gsub(/"/, "", v)
          n = (tolower(name) == "srcset") ? split(v, parts, ",") : split(v, parts, "\n")
          for (i = 1; i <= n; i++) {
            u = parts[i]; sub(/^[ \t]+/, "", u); sub(/[ \t].*$/, "", u)
            if (u ~ /^(https?:)?\/\// && index(u, B) != 1) print "  " F ": " name "=" u
          }
        }
      }'
done | sort -u)
css=$(find "$PUBLIC" \( -name '*.css' -o -name '*.html' \) -exec grep -HoiE '(url\([ \t]*"?|@import[ \t]+"?)(https?:)?//[^")[:space:];]+' {} + |
  awk -v B="$BASE_URL" '{ u = $0; sub(/^[^:]*:/, "", u); sub(/^[^(\/]*[( \t][ \t]*"?/, "", u); if (index(u, B) != 1) print }' |
  sed "s#^$PUBLIC/#  #" | sort -u || true)
[ -z "$ext$css" ] || fail "SUPPLY FAIL: pages load from another host:
$(printf '%s\n%s\n' "$ext" "$css" | sed '/^$/d')"
cdn=$(find "$PUBLIC" \( -name '*.html' -o -name '*.js' -o -name '*.css' \) -exec grep -lE 'cdn\.jsdelivr|unpkg\.com|cdnjs|googleapis|gstatic' {} + || true)
[ -z "$cdn" ] || fail "SUPPLY FAIL: CDN reference in:
$(echo "$cdn" | sed 's/^/  /')"
echo "supply: every loaded URL is relative or under $BASE_URL; no CDN reference"

# The Enhancements section's links to a path its repository does not hold
# (layouts/enhancements/_markup/render-link.html links them to GitHub at the
# commit built and marks them): listed, not failed, since the repository owns
# the fix.
if [ -n "$ENH_TREE" ]; then
  unres=$(find "$PUBLIC/enhancements" -name '*.html' ! -path '*/pagefind/*' -exec grep -ohE 'data-opm-enh-unresolved="[^"]*"' {} + | sed 's/^data-opm-enh-unresolved="//; s/"$//' | sort -u || true)
  if [ -n "$unres" ]; then
    echo "enhancements: $(printf '%s\n' "$unres" | grep -c .) link(s) name no path in the enhancements repository at ${ENH_SHA:-its worktree}; they link to GitHub (fix them there):"
    printf '%s\n' "$unres" | sed 's/^/  /'
  else
    echo "enhancements: every repository link resolves"
  fi
fi

step "summary"
for pair in $VERSIONS; do
  v=${pair%%=*}
  echo "$v: $(find "$PUBLIC/$v" -name index.html ! -path "$PUBLIC/$v/pagefind/*" | wc -l | tr -d ' ') pages"
done
[ -z "$ENH_TREE" ] || echo "enhancements: $(find "$PUBLIC/enhancements" -name index.html ! -path "$PUBLIC/enhancements/pagefind/*" | wc -l | tr -d ' ') pages"
echo "build-all: OK in $(( $(date +%s) - t0 )) s -> $SITE_DIR/$PUBLIC ($(find "$PUBLIC" -type f | wc -l | tr -d ' ') files, $(du -sh "$PUBLIC" | cut -f1))"
