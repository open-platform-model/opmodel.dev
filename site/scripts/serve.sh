#!/bin/sh
# Dev server, inside the build image (site/scripts/run-in-image.sh serve). It
# reads every source repo's docs/site/ in place from /src/<repo> (read-only),
# so edits and new pages appear without a restart. The container publishes
# only 127.0.0.1:${SITE_PORT:-1313}; one SIGINT stops it (tini forwards it to
# the process group, and hugo runs as the shell's exec).
#
# Env: SITE_DIR, OPM_VERSIONS (default v1.0=/src), SITE_PORT (the host port,
#      for the base URL).
set -eu
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
SITE_DIR=${SITE_DIR:-$(cd "$SCRIPTS/.." && pwd)}
export SITE_DIR
VERSIONS=${OPM_VERSIONS:-v1.0=/src}
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"

sh "$SCRIPTS/check-overrides.sh"
dirs=""
for pair in $VERSIONS; do
  root=${pair#*=}
  for r in $REPOS; do dirs="$dirs $root/$r/docs/site"; done
done
# shellcheck disable=SC2086 # the roots hold no spaces
sh "$SCRIPTS/lint-sources.sh" $dirs
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-lastmod.sh" $VERSIONS
sh "$SCRIPTS/gen-stamp.sh"
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-mounts.sh" config/development/module.toml $VERSIONS
port=${SITE_PORT:-1313}
exec hugo server --renderToMemory --bind 0.0.0.0 --port 1313 \
  --baseURL "http://127.0.0.1:$port/" --appendPort=false --logLevel info
