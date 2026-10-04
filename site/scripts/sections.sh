# The versions and the unversioned sections a build or the dev server reads.
# Sourced (never run) by build-all.sh and serve.sh, in SITE_DIR, with
# SITE_DIR set and CALLER naming the caller (build-all, serve), which every
# error message names. POSIX sh. Sets and exports:
#
#   VERSIONS DEFAULT                       the versions, in weight order, and the default one
#   ENH_DIR ENH_REF ENH_SHA ENH_HOW ENH_DIGEST   the enhancements section (empty ENH_DIR: none)
#   CAT_DIR CAT_FROM                       the Catalogs section's docs bundles (empty CAT_DIR: none)
#
# The versions: an explicit OPM_VERSIONS (the first is the default), else the
# resolved .versions/versions.tsv (a source = main version reads /src in
# place, an anchored or a line one its archive in .versions/<v>/), else
# v1.0=/src.
#
# The enhancements section (site/enhancements/), unversioned, comes from its
# section bundle (docs-kit C21): the lock entry of CAT_DIR/lock.json whose
# root is /enhancements/ (pulled at edge; site/bundles.cue sections), set
# below once CAT_DIR is known. Without such an entry there is no section.
# gen-stamp.sh, gen-mounts.sh and check-pages.sh read the ENH_* values:
# ENH_DIR the bundle tree, ENH_SHA the commit it was built from, ENH_REF its
# tag (edge), ENH_DIGEST its digest (empty for a local bundle) and ENH_HOW a
# line for the stamp.

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

# The Catalogs section (site/catalogs/): the docs bundles opm-docs pull
# unpacked, with their lock.json (docs-kit C7). Which directory, and whether
# the build requires one (openspec add-catalogs-tab, design Decision 2):
#   OPM_BUNDLES set (tests, an author's saved tree; run-in-image.sh mounts
#     it read-only)              -> that directory; required; the config
#                                   check is skipped; CAT_FROM=OPM_BUNDLES
#   manifest mode with bundles.cue -> .bundles/; required; CAT_FROM=manifest
#   explicit mode                -> .bundles/ when it holds lock.json, else
#                                   no section; CAT_FROM=explicit
#   manifest mode, no bundles.cue -> no section
# A required directory without lock.json, and a lock whose config is not the
# sha256 of bundles.cue's bytes, fail, naming task bundles:pull.
CAT_DIR=""; CAT_FROM=""
if [ -n "${OPM_BUNDLES:-}" ]; then
  CAT_DIR=$OPM_BUNDLES; CAT_FROM=OPM_BUNDLES
  [ -f "$CAT_DIR/lock.json" ] || sections_fail "OPM_BUNDLES=$CAT_DIR holds no lock.json; point it at a directory opm-docs pull wrote"
else
  if [ -z "${OPM_VERSIONS:-}" ] && [ -f .versions/versions.tsv ]; then
    if [ -f bundles.cue ]; then
      CAT_DIR=$SITE_DIR/.bundles; CAT_FROM=manifest
      [ -f "$CAT_DIR/lock.json" ] || sections_fail "site/bundles.cue names the Catalogs tabs, but site/.bundles/ holds no lock.json; run task bundles:pull"
    fi
  elif [ -f .bundles/lock.json ]; then
    CAT_DIR=$SITE_DIR/.bundles; CAT_FROM=explicit
  fi
  if [ -n "$CAT_DIR" ]; then
    [ -f bundles.cue ] || sections_fail "site/.bundles/lock.json exists, but site/bundles.cue does not; run task bundles:pull, or remove site/.bundles/"
    want=sha256:$(sha256sum bundles.cue | cut -c1-64)
    have=$(jq -r '.config // ""' "$CAT_DIR/lock.json") || sections_fail "site/.bundles/lock.json is not JSON; run task bundles:pull"
    [ "$have" = "$want" ] || sections_fail "site/.bundles/lock.json was pulled for another site/bundles.cue (lock config $have, bundles.cue $want); run task bundles:pull"
  fi
fi
export CAT_DIR CAT_FROM

ENH_DIR=""; ENH_REF=""; ENH_SHA=""; ENH_HOW=""; ENH_DIGEST=""
if [ -n "$CAT_DIR" ]; then
  e=$(jq -c '[.bundles[]? | select(.root == "/enhancements/")] | if length > 1 then error("two") else .[0] // empty end' "$CAT_DIR/lock.json" 2>/dev/null) ||
    sections_fail "$CAT_DIR/lock.json names more than one /enhancements/ bundle"
  if [ -n "$e" ]; then
    d=$(printf '%s' "$e" | jq -r '.dir // ""')
    case "$d" in ''|/*|*..*) sections_fail "$CAT_DIR/lock.json: the enhancements entry's dir \"$d\" is not a path under the lock's directory" ;; esac
    ENH_DIR=$CAT_DIR/$d
    ENH_REF=$(printf '%s' "$e" | jq -r '.tag // .segment')
    ENH_SHA=$(printf '%s' "$e" | jq -r '.commit // ""')
    ENH_DIGEST=$(printf '%s' "$e" | jq -r 'if .local then "" else .digest end')
    ENH_HOW="bundle $(printf '%s' "$e" | jq -r 'if .local then "local" else .digest end')"
    [ -f "$ENH_DIR/manifest.json" ] || sections_fail "$ENH_DIR holds no manifest.json; run task bundles:pull"
  fi
fi
export ENH_DIR ENH_REF ENH_SHA ENH_HOW ENH_DIGEST
