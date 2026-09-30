#!/bin/sh
# Writes SITE_DIR/data/opm/build.json, the build stamp, from OPM_BUILD_REFS
# ("repo=sha ...", resolved on the host by run-in-image.sh; a root that is not
# its own git checkout is "none"):
#   { "sources": { "opm": "<sha>", ... } }
# layouts/_partials/opm/build-stamp.html shows it in the footer, and
# build-all.sh publishes it as public/build-stamp.json. Unset (test-site.sh),
# the stamp lists no source.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$SITE_DIR"
mkdir -p data/opm
{
  printf '{\n  "sources": {'
  sep=''
  for pair in ${OPM_BUILD_REFS:-}; do
    repo=${pair%%=*}; sha=${pair#*=}
    case "$sha" in
      none) ;;
      *[!0-9a-f]*|'') echo "gen-stamp: $repo: not a commit SHA: $sha" >&2; exit 1 ;;
    esac
    printf '%s\n    "%s": "%s"' "$sep" "$repo" "$sha"
    sep=,
  done
  [ -z "$sep" ] || printf '\n  '
  printf '}\n}\n'
} > data/opm/build.json
echo "gen-stamp: data/opm/build.json ($(grep -c '": "' data/opm/build.json | tr -d ' ') sources)"
