#!/bin/sh
# Dev server, inside the build image (site/scripts/run-in-image.sh serve). It
# reads every source repo's docs/site/ in place from /src/<repo> (read-only),
# so edits and new pages appear without a restart. The container publishes
# only 127.0.0.1:${SITE_PORT:-1313}; one SIGINT stops it (tini forwards it to
# the process group, and hugo runs as the shell's exec).
#
# Env: SITE_DIR, OPM_VERSIONS (an explicit version set; unset: the versions
#      task versions:prepare resolved into .versions/versions.tsv), SITE_PORT
#      (the host port, for the base URL).
set -eu
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
SITE_DIR=${SITE_DIR:-$(cd "$SCRIPTS/.." && pwd)}
export SITE_DIR
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
# The versions, as build-all.sh reads them: an explicit OPM_VERSIONS, else the
# resolved .versions/versions.tsv (a source = main version reads /src in
# place, an anchored one its archive in .versions/<v>/), else v1.0=/src.
if [ -n "${OPM_VERSIONS:-}" ]; then
  VERSIONS=$OPM_VERSIONS
elif [ -f .versions/versions.tsv ]; then
  VERSIONS=$(awk -F'\t' -v S="$SITE_DIR" '/^#/ { next } !($1 in seen) { seen[$1]; printf "%s%s=%s", (n++ ? " " : ""), $1, ($5 == "main" ? "/src" : S "/.versions/" $1) }' .versions/versions.tsv)
else
  VERSIONS=v1.0=/src
fi

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
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-stamp.sh" $VERSIONS
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-mounts.sh" config/development/module.toml $VERSIONS
port=${SITE_PORT:-1313}
exec hugo server --renderToMemory --bind 0.0.0.0 --port 1313 \
  --baseURL "http://127.0.0.1:$port/" --appendPort=false --logLevel info
