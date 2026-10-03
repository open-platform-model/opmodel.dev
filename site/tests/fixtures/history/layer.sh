#!/bin/sh
# Lays the hand-written version history (docs-kit C13) onto a pulled copy of
# the fixture bundles, until the pinned opm-docs writes it itself:
#
#   layer.sh SRC DST    DST = SRC + catalog-opm/history.json, and SRC's lock
#                       with the "history" entry a pull records (C7)
#
# test-site.sh runs it on its pulled fixtures; for browser QA on the host,
# OPM_BUNDLES=<DST> task qa.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src=$1; dst=$2
rm -rf "$dst"
cp -R "$src" "$dst"
cp "$here/catalog-opm/history.json" "$dst/catalog-opm/history.json"
d=sha256:$(sha256sum "$dst/catalog-opm/history.json" | cut -c1-64)
jq --arg d "$d" '.history = [{project: "catalog-opm", digest: $d, path: "catalog-opm/history.json"}]' "$src/lock.json" > "$dst/lock.json"
