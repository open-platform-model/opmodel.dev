#!/bin/sh
# The site build. Runs inside the build image (site/Dockerfile.hugo) with the
# repo at /work/repo and each source root read-only at /src/<repo>, with no
# network (site/scripts/run-in-image.sh build). Every step fails the build.
#
# Env: SITE_DIR           the site tree to build (default: this script's site/,
#                         /work/repo/site); test-site.sh points it at a copy
#      OPM_VERSIONS       name=root ... (default v1.0=/src); each root holds <repo>/docs/site
#      OPM_REQUIRE_DATES  1: a page without a git date fails the build
#      OPM_BUILD_REFS     repo=sha ..., resolved on the host
set -eu
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
SITE_DIR=${SITE_DIR:-$(cd "$SCRIPTS/.." && pwd)}
export SITE_DIR
VERSIONS=${OPM_VERSIONS:-v1.0=/src}
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
t0=$(date +%s)
step() { printf '\n== %s\n' "$*"; }

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

step "dates, mounts, collisions"
echo "sources: ${OPM_BUILD_REFS:-unresolved}"
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-lastmod.sh" $VERSIONS
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-mounts.sh" config/production/module.toml $VERSIONS
# shellcheck disable=SC2086
sh "$SCRIPTS/check-pages.sh" pre $VERSIONS

step "hugo build ($(hugo version | cut -d' ' -f1-2))"
hugo build --gc --cleanDestinationDir --panicOnWarning --logLevel warn

step "page set, stray files, sidebar order"
# shellcheck disable=SC2086
sh "$SCRIPTS/check-pages.sh" post $VERSIONS

step "output guards"
# A Starlight aside that reached the output as text.
raw=$(find public -name '*.html' -exec grep -l -e '<p>:::' -e '^:::' {} + || true)
if [ -n "$raw" ]; then echo "DIALECT FAIL: literal ':::' published in:"; echo "$raw" | sed 's/^/  /'; exit 1; fi
echo "dialect: no raw ':::' in public/"
# Planning comments (<!-- ... -->) must reach no published text.
leak=$(find public \( -name '*.html' -o -name '*.txt' -o -name '*.md' -o -name '*.xml' -o -name '*.json' \) -exec grep -l -e '<!--' {} + || true)
if [ -n "$leak" ]; then echo "COMMENT FAIL: an HTML comment reached:"; echo "$leak" | sed 's/^/  /'; exit 1; fi
echo "comments: no HTML comment in any published text"
# Nothing is fetched from a third party at run time.
ext=$(find public -name '*.html' -exec grep -hoE '<(script|link|img|iframe|source)[^>]+(src|href)="?(https?:)?//[^" >]+' {} + | grep -vE 'rel="?canonical|(src|href)="?https://(opmodel\.dev|github\.com)' | sort -u || true)
if [ -n "$ext" ]; then echo "SUPPLY FAIL: pages load third-party URLs:"; echo "$ext" | sed 's/^/  /'; exit 1; fi
cdn=$(find public \( -name '*.html' -o -name '*.js' -o -name '*.css' \) -exec grep -lE 'cdn\.jsdelivr|unpkg\.com|cdnjs|googleapis|gstatic' {} + || true)
if [ -n "$cdn" ]; then echo "SUPPLY FAIL: CDN reference in:"; echo "$cdn" | sed 's/^/  /'; exit 1; fi
echo "supply: no CDN or third-party script, style or image URL"

echo
echo "build-all: OK in $(( $(date +%s) - t0 )) s -> $SITE_DIR/public ($(find public -type f | wc -l | tr -d ' ') files)"
