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
# The versions, as build-all.sh reads them: an explicit OPM_VERSIONS, else the
# resolved .versions/versions.tsv (a source = main version reads /src in
# place, an anchored or a line one its archive in .versions/<v>/), else
# v1.0=/src.
if [ -n "${OPM_VERSIONS:-}" ]; then
  VERSIONS=$OPM_VERSIONS
elif [ -f .versions/versions.tsv ]; then
  VERSIONS=$(awk -F'\t' -v S="$SITE_DIR" '/^#/ { next } !($1 in seen) { seen[$1]; printf "%s%s=%s", (n++ ? " " : ""), $1, ($5 == "main" ? "/src" : S "/.versions/" $1) }' .versions/versions.tsv)
else
  VERSIONS=v1.0=/src
fi
# The enhancements section (site/enhancements/), unversioned: in manifest mode
# the archive materialise.sh wrote for versions.tsv's "# section enhancements"
# line, at the SHA it names; in explicit mode the enhancements/ beside the
# default version's repositories (/src/enhancements, which run-in-image.sh
# mounts; a fixture workspace's own), read in place, when it holds INDEX.md,
# at the commit OPM_BUILD_REFS names for it. Otherwise there is no section.
# gen-stamp.sh and gen-mounts.sh read the ENH_* values;
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
    [ -f "$ENH_TREE/INDEX.md" ] || { echo "serve: versions.tsv names the enhancements section at $ENH_SHA, but $ENH_TREE holds no INDEX.md; run task versions:prepare" >&2; exit 1; }
  fi
fi
export ENH_TREE ENH_PATHS ENH_REF ENH_SHA ENH_HOW

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
