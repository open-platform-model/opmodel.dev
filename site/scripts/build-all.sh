#!/bin/sh
# The site build. Runs inside the build image (site/Dockerfile) with the
# repo at /work/repo and each source root read-only at /src/<repo>, with no
# network (site/scripts/run-in-image.sh build). Every step fails the build.
#
# Env: SITE_DIR           the site tree to build (default: this script's site/,
#                         /work/repo/site); test-site.sh points it at a copy
#      OPM_VERSIONS       name=root ... (default v1.0=/src); each root holds <repo>/docs/site
#      OPM_REQUIRE_DATES  1: a page without a git date fails the build
#      OPM_BUILD_REFS     repo=sha ..., resolved on the host (the build stamp)
set -eu
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
SITE_DIR=${SITE_DIR:-$(cd "$SCRIPTS/.." && pwd)}
export SITE_DIR
VERSIONS=${OPM_VERSIONS:-v1.0=/src}
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
t0=$(date +%s)
step() { printf '\n== %s\n' "$*"; }
fail() { echo "$*"; exit 1; }
# The default version: /latest/ and / point at it.
DEFAULT=$(sed -n "s/^defaultContentVersion *= *['\"]\(.*\)['\"] *$/\1/p" config/_default/hugo.toml)
[ -n "$DEFAULT" ] || fail "build-all: no defaultContentVersion in config/_default/hugo.toml"

step "drift guard: overridden theme files unchanged upstream"
sh "$SCRIPTS/check-overrides.sh"

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
sh "$SCRIPTS/gen-stamp.sh"
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-mounts.sh" config/production/module.toml $VERSIONS
# shellcheck disable=SC2086
sh "$SCRIPTS/check-pages.sh" pre $VERSIONS

step "hugo build ($(hugo version | cut -d' ' -f1-2))"
hugo build --gc --cleanDestinationDir --panicOnWarning --logLevel warn

step "page set, stray files, sidebar order"
# shellcheck disable=SC2086
sh "$SCRIPTS/check-pages.sh" post $VERSIONS

step "root files and search, per version"
[ -f "public/$DEFAULT/404.html" ] || fail "ROOT FAIL: public/$DEFAULT/404.html was not built"
printf '/ /latest/ 302\n/latest/* /%s/:splat 302\n' "$DEFAULT" > public/_redirects
printf '<!doctype html><meta charset="utf-8"><meta name="robots" content="noindex"><meta http-equiv="refresh" content="0; url=/latest/"><title>Open Platform Model</title><a href="/latest/">/latest/</a>\n' > public/index.html
cp "public/$DEFAULT/404.html" public/404.html
cp data/opm/build.json public/build-stamp.json
for pair in $VERSIONS; do
  v=${pair%%=*}
  pagefind --site "public/$v" --root-selector 'main#content > .content' \
    --exclude-selectors '.hextra-page-context-menu, .opm-type-badge, .hextra-code-copy-btn, figure svg' \
    --quiet
  printf '%s: pagefind %s pages, %s\n' "$v" "$(find "public/$v/pagefind/fragment" -type f | wc -l | tr -d ' ')" "$(du -sh "public/$v/pagefind" | cut -f1)"
done

step "output guards"
# Check 12: the redirect files and root files are present.
for f in _redirects index.html 404.html robots.txt latest/index.html build-stamp.json; do
  [ -s "public/$f" ] || fail "REDIRECT FAIL: public/$f is missing"
done
grep -qxF '/ /latest/ 302' public/_redirects || fail "REDIRECT FAIL: public/_redirects does not send / to /latest/"
echo "redirects: _redirects, root index.html, 404.html, robots.txt and the /latest/ stubs present"
# Check 9: a Starlight aside that reached the output as text.
raw=$(find public -name '*.html' -exec grep -l -e '<p>:::' -e '^:::' {} + || true)
[ -z "$raw" ] || fail "DIALECT FAIL: literal ':::' published in:
$(echo "$raw" | sed 's/^/  /')"
echo "dialect: no raw ':::' in public/"
# Check 10: planning comments (<!-- ... -->) reach no published text.
leak=$(find public \( -name '*.html' -o -name '*.txt' -o -name '*.md' -o -name '*.xml' -o -name '*.json' \) -exec grep -l -e '<!--' {} + || true)
[ -z "$leak" ] || fail "COMMENT FAIL: an HTML comment reached:
$(echo "$leak" | sed 's/^/  /')"
echo "comments: no HTML comment in any published text"
# Check 11: nothing is fetched from a third party at run time.
ext=$(find public -name '*.html' -exec grep -hoE '<(script|link|img|iframe|source)[^>]+(src|href)="?(https?:)?//[^" >]+' {} + | grep -vE 'rel="?canonical|(src|href)="?https://(opmodel\.dev|github\.com)' | sort -u || true)
[ -z "$ext" ] || fail "SUPPLY FAIL: pages load third-party URLs:
$(echo "$ext" | sed 's/^/  /')"
cdn=$(find public \( -name '*.html' -o -name '*.js' -o -name '*.css' \) -exec grep -lE 'cdn\.jsdelivr|unpkg\.com|cdnjs|googleapis|gstatic' {} + || true)
[ -z "$cdn" ] || fail "SUPPLY FAIL: CDN reference in:
$(echo "$cdn" | sed 's/^/  /')"
echo "supply: no CDN or third-party script, style or image URL"

step "summary"
for pair in $VERSIONS; do
  v=${pair%%=*}
  echo "$v: $(find "public/$v" -name index.html ! -path "public/$v/pagefind/*" | wc -l | tr -d ' ') pages"
done
echo "build-all: OK in $(( $(date +%s) - t0 )) s -> $SITE_DIR/public ($(find public -type f | wc -l | tr -d ' ') files, $(du -sh public | cut -f1))"
