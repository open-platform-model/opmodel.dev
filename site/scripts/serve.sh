#!/bin/sh
# Dev server, inside the build image (site/scripts/run-in-image.sh serve). A
# source = main or explicit version (OPM_VERSIONS=v1.0=/src, live editing)
# reads every source repo's docs/site/ in place from /src/<repo> (read-only),
# so edits and new pages appear without a restart; an anchored or line
# version serves its archives in .versions/<v>/. The container publishes
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
# The versions and the unversioned sections, as build-all.sh reads them:
# scripts/sections.sh.
CALLER=serve
# shellcheck source=sections.sh
. "$SCRIPTS/sections.sh"

sh "$SCRIPTS/check-overrides.sh"
# Which repositories each version reads from a docs bundle (build-all.sh).
sh "$SCRIPTS/gen-catalogs.sh"
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-docs-bundles.sh" $VERSIONS
dirs=""
for pair in $VERSIONS; do
  v=${pair%%=*}; root=${pair#*=}
  fromb=" $(jq -r --arg v "$v" '.versions[$v] // {} | [.[].tree] | join(" ")' data/opm/docs-bundles.json) "
  for r in $REPOS; do
    case "$fromb" in *" $r "*) ;; *) dirs="$dirs $root/$r/docs/site" ;; esac
  done
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
