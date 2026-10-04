#!/bin/sh
# Dev server, inside the build image (site/scripts/run-in-image.sh serve),
# over the docs bundles of the lock (site/.bundles/, or OPM_BUNDLES) and the
# site-owned content/, which it reloads on an edit. A source repository's
# pages are previewed through their bundle: opm-docs serve in that
# repository, or its build output pulled locally here (OPM_BUNDLES_LOCAL with
# task bundles:pull; README "Contributing"). The container publishes only
# 127.0.0.1:${SITE_PORT:-1313}; one SIGINT stops it (tini forwards it to the
# process group, and hugo runs as the shell's exec).
#
# Env: SITE_DIR, OPM_BUNDLES, OPM_VERSIONS_CONF (as for build-all.sh),
#      SITE_PORT (the host port, for the base URL).
set -eu
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
SITE_DIR=${SITE_DIR:-$(cd "$SCRIPTS/.." && pwd)}
export SITE_DIR
cd "$SITE_DIR"
# The docs bundles, the versions and the unversioned sections, as
# build-all.sh reads them: scripts/sections.sh.
CALLER=serve
# shellcheck source=sections.sh
. "$SCRIPTS/sections.sh"

sh "$SCRIPTS/check-overrides.sh"
sh "$SCRIPTS/gen-catalogs.sh"
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-docs-bundles.sh" $VERSIONS
sh "$SCRIPTS/check-site-dates.sh"
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-stamp.sh" $VERSIONS
# shellcheck disable=SC2086
sh "$SCRIPTS/gen-mounts.sh" config/development/module.toml $VERSIONS
port=${SITE_PORT:-1313}
exec hugo server --renderToMemory --bind 0.0.0.0 --port 1313 \
  --baseURL "http://127.0.0.1:$port/" --appendPort=false --logLevel info
