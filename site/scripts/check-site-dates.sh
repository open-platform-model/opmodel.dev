#!/bin/sh
# Every site-owned page (content/) has its date in data/opm/lastmod.json,
# which gen-site-dates.sh writes on the host before the build. Runs in the
# build (build-all.sh, serve.sh). A page without one (not committed yet, or
# every page of a shallow clone, which gen-site-dates.sh refuses to date) is
# counted and printed; with OPM_REQUIRE_DATES=1 (CI) it fails the build.
# Without the file (a test copy of the site, which no host step dated) every
# page counts as undated.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$SITE_DIR"
F=data/opm/lastmod.json
if [ ! -f "$F" ]; then
  echo "check-site-dates: no $F (run-in-image.sh writes it on the host, gen-site-dates.sh)"
  mkdir -p data/opm; echo '{}' > "$F"
fi
jq -e 'type == "object" and all(.[]; type == "string")' "$F" >/dev/null 2>&1 || { echo "check-site-dates: $F is not an object of dates; run gen-site-dates.sh" >&2; exit 1; }
miss=$(find content -type f -name '*.md' | sort | while IFS= read -r f; do
  jq -e --arg k "opmodel.dev/site/$f" 'has($k)' "$F" >/dev/null || echo "$f"
done)
total=$(find content -type f -name '*.md' | wc -l | tr -d ' ')
n=$(printf '%s' "$miss" | grep -c . || true)
echo "check-site-dates: $((total - n)) of $total site-owned pages dated"
if [ -n "$miss" ] && [ "${OPM_REQUIRE_DATES:-0}" = 1 ]; then
  printf '%s\n' "$miss" | sed 's/^/  no date: site\//'
  echo "check-site-dates: FAILED, OPM_REQUIRE_DATES=1 and $n site-owned pages have no date"
  exit 1
fi
