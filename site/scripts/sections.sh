# The versions and the unversioned sections a build or the dev server reads.
# Sourced (never run) by build-all.sh and serve.sh, in SITE_DIR, with
# SITE_DIR set and CALLER naming the caller (build-all, serve), which every
# error message names. POSIX sh. Sets and exports:
#
#   VERSIONS DEFAULT                       the versions, in weight order, and the default one
#   ENH_TREE ENH_PATHS ENH_REF ENH_SHA ENH_HOW   the enhancements section (empty ENH_TREE: none)
#
# The versions: an explicit OPM_VERSIONS (the first is the default), else the
# resolved .versions/versions.tsv (a source = main version reads /src in
# place, an anchored or a line one its archive in .versions/<v>/), else
# v1.0=/src.
#
# The enhancements section (site/enhancements/), unversioned: in manifest mode
# the archive materialise.sh wrote for versions.tsv's "# section enhancements"
# line, at the SHA it names; in explicit mode the enhancements/ beside the
# default version's repositories (/src/enhancements, which run-in-image.sh
# mounts; a fixture workspace's own), read in place, when it holds INDEX.md,
# at the commit OPM_BUILD_REFS names for it. Otherwise there is no section.
# gen-stamp.sh, gen-mounts.sh and check-pages.sh read the ENH_* values;
# ENH_PATHS is materialise.sh's list of every path at that SHA.

sections_fail() { echo "$CALLER: $*" >&2; exit 1; }

if [ -n "${OPM_VERSIONS:-}" ]; then
  VERSIONS=$OPM_VERSIONS; DEFAULT=${VERSIONS%%=*}
elif [ -f .versions/versions.tsv ]; then
  VERSIONS=$(awk -F'\t' -v S="$SITE_DIR" '/^#/ { next } !($1 in seen) { seen[$1]; printf "%s%s=%s", (n++ ? " " : ""), $1, ($5 == "main" ? "/src" : S "/.versions/" $1) }' .versions/versions.tsv)
  DEFAULT=$(awk -F'\t' '!/^#/ && $4 == "true" { print $1; exit }' .versions/versions.tsv)
else
  VERSIONS=v1.0=/src; DEFAULT=v1.0
fi
export VERSIONS DEFAULT

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
    [ -f "$ENH_TREE/INDEX.md" ] || sections_fail "versions.tsv names the enhancements section at $ENH_SHA, but $ENH_TREE holds no INDEX.md; run task versions:prepare"
  fi
fi
export ENH_TREE ENH_PATHS ENH_REF ENH_SHA ENH_HOW
