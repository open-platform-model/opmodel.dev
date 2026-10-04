# The docs bundles, the site versions and the unversioned sections a build or
# the dev server reads. Sourced (never run) by build-all.sh and serve.sh, in
# SITE_DIR, with SITE_DIR set and CALLER naming the caller (build-all, serve),
# which every error message names. POSIX sh. Sets and exports:
#
#   CAT_DIR CAT_FROM                       the docs bundles opm-docs pull unpacked, with their lock
#   CATALOGS                               1 when the lock names a Catalogs tab bundle (the build
#                                          has the Catalogs section), else empty
#   VERSIONS DEFAULT                       the site versions, in weight order, and the default one
#   ENH_DIR ENH_REF ENH_SHA ENH_HOW ENH_DIGEST   the enhancements section (empty ENH_DIR: none)
#
# and writes .gen/versions.tsv, "<name>\t<label>\t<weight>\t<default>" per
# version in weight order, which gen-mounts.sh and gen-stamp.sh read.
#
# The docs bundles (docs-kit C7): every page the site publishes outside
# site/content/ comes from a docs bundle, so a build always reads a lock.
#   OPM_BUNDLES set (tests, the edge build, an author's saved tree;
#     run-in-image.sh mounts it read-only)  -> that directory; CAT_FROM=OPM_BUNDLES;
#                                              the config check is skipped
#   otherwise                               -> .bundles/, which must hold the lock
#                                              pulled for bundles.cue; CAT_FROM=bundles
# A directory without lock.json, and a lock whose config is not the sha256 of
# bundles.cue's bytes, fail, naming task bundles:pull.
#
# The site versions: the lock's docs entries name them (each entry's "site",
# from bundles.cue `versions`; docs-kit C16), and versions.conf (or
# OPM_VERSIONS_CONF, a path relative to SITE_DIR: the two-version test)
# gives each its display keys, [version "<name>"] label, weight and default.
# The build fails when the two name different versions, on any other section
# or key, a key set twice, a missing or empty label or one holding a quote, a
# backslash or a tab, a weight that is not a positive integer, two versions
# with one weight, a default that is not true or false, or not exactly one
# default (site/tests/checks/versions-conf-*).
#
# The enhancements section (site/enhancements/), unversioned, comes from its
# section bundle (docs-kit C21): the lock entry whose root is /enhancements/
# (pulled at edge; site/bundles.cue sections). Without such an entry there is
# no section. gen-stamp.sh, gen-mounts.sh and check-pages.sh read the ENH_*
# values: ENH_DIR the bundle tree, ENH_SHA the commit it was built from,
# ENH_REF its tag (edge), ENH_DIGEST its digest (empty for a local bundle)
# and ENH_HOW a line for the stamp.

sections_fail() { echo "$CALLER: $*" >&2; exit 1; }

# --- The docs bundles ------------------------------------------------------------
if [ -n "${OPM_BUNDLES:-}" ]; then
  CAT_DIR=$OPM_BUNDLES; CAT_FROM=OPM_BUNDLES
  [ -f "$CAT_DIR/lock.json" ] || sections_fail "OPM_BUNDLES=$CAT_DIR holds no lock.json; point it at a directory opm-docs pull wrote"
else
  CAT_DIR=$SITE_DIR/.bundles; CAT_FROM=bundles
  [ -f bundles.cue ] || sections_fail "site/bundles.cue does not exist; the site reads every source page from the docs bundles it names"
  [ -f "$CAT_DIR/lock.json" ] || sections_fail "site/.bundles/ holds no lock.json; run task bundles:pull"
  want=sha256:$(sha256sum bundles.cue | cut -c1-64)
  have=$(jq -r '.config // ""' "$CAT_DIR/lock.json") || sections_fail "site/.bundles/lock.json is not JSON; run task bundles:pull"
  [ "$have" = "$want" ] || sections_fail "site/.bundles/lock.json was pulled for another site/bundles.cue (lock config $have, bundles.cue $want); run task bundles:pull"
fi
CATALOGS=""
jq -e '[.bundles[]? | select(.root | startswith("/catalogs/"))] | length > 0' "$CAT_DIR/lock.json" >/dev/null 2>&1 && CATALOGS=1
export CAT_DIR CAT_FROM CATALOGS

# --- The site versions -------------------------------------------------------------
VCONF=${OPM_VERSIONS_CONF:-versions.conf}
[ -f "$VCONF" ] || sections_fail "$VCONF does not exist: it gives every site version its label, weight and default"
inlock=$(jq -r '[.docs // [] | .[] | .site // empty] | unique | .[]' "$CAT_DIR/lock.json") ||
  sections_fail "$CAT_DIR/lock.json is not JSON; run task bundles:pull"
[ -n "$inlock" ] || sections_fail "$CAT_DIR/lock.json names no site version (no docs entries); site/bundles.cue versions names them, then run task bundles:pull"
# The file, read as a strict subset of git-config syntax (no git: the
# container cannot run git inside a worktree): blank lines, comment lines
# (; or #), [version "<name>"] headers and "key = value" lines under one.
# Each key as "<name>\t<key>\t<value>"; anything else fails, naming its line.
errf=$(mktemp)
kv=$(awk -v F="$VCONF" '
  function trim(x) { sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x); return x }
  /^[ \t]*([;#].*)?$/ { next }
  /^[ \t]*\[/ {
    if (match($0, /^[ \t]*\[version "[^"]+"\][ \t]*$/)) { v = $0; sub(/^[^"]*"/, "", v); sub(/".*$/, "", v); next }
    print F ":" NR ": " trim($0) " is not a [version \"<name>\"] section; the file holds only label, weight and default per version (the version list is site/bundles.cue versions)" > "/dev/stderr"; bad = 1; exit 1
  }
  {
    if (v == "" || index($0, "=") == 0) { print F ":" NR ": \"" trim($0) "\" is not a key = value line under a [version \"<name>\"] section" > "/dev/stderr"; bad = 1; exit 1 }
    k = trim(substr($0, 1, index($0, "=") - 1)); val = substr($0, index($0, "=") + 1)
    # An unquoted ; or # starts a comment, as in git-config syntax.
    sub(/[;#].*$/, "", val); val = trim(val)
    if (k != "label" && k != "weight" && k != "default") { print F ": version " v " has the key " k "; only label, weight and default are allowed (the version list is site/bundles.cue versions)" > "/dev/stderr"; bad = 1; exit 1 }
    if ((v SUBSEP k) in seen) { print F ": version " v " sets " k " twice" > "/dev/stderr"; bad = 1; exit 1 }
    seen[v, k]; print v "\t" k "\t" val
  }' "$VCONF" 2>"$errf") || { m=$(cat "$errf"); rm -f "$errf"; sections_fail "$m"; }
rm -f "$errf"
inconf=$(printf '%s\n' "$kv" | cut -f1 | sed '/^$/d' | sort -u)
a=$(printf '%s\n' $inlock | sort | tr '\n' ' '); b=$(printf '%s\n' $inconf | sort | tr '\n' ' ')
[ "$a" = "$b" ] || sections_fail "the lock's docs entries name the site versions ${a% }, but $VCONF names ${b% }; they must name the same (site/bundles.cue versions is the list; run task bundles:pull, or fix $VCONF)"
mkdir -p .gen
get_key() { printf '%s\n' "$kv" | awk -F'\t' -v v="$1" -v k="$2" '$1 == v && $2 == k { sub(/^[^\t]*\t[^\t]*\t/, ""); print }'; }
: > .gen/versions.tsv.tmp
for v in $inconf; do
  label=$(get_key "$v" label); weight=$(get_key "$v" weight); def=$(get_key "$v" default)
  [ -n "$label" ] || sections_fail "$VCONF: version $v has no label"
  case "$label" in *[\"\'\\]*|*"$(printf '\t')"*) sections_fail "$VCONF: version $v's label holds a quote, a backslash or a tab" ;; esac
  case "$weight" in ''|0*|*[!0-9]*) sections_fail "$VCONF: version $v's weight \"$weight\" is not a positive integer" ;; esac
  case "$def" in true) ;; ''|false) def=false ;; *) sections_fail "$VCONF: version $v's default \"$def\" is not true or false" ;; esac
  printf '%s\t%s\t%s\t%s\n' "$v" "$label" "$weight" "$def" >> .gen/versions.tsv.tmp
done
sort -t "$(printf '\t')" -k3,3n .gen/versions.tsv.tmp > .gen/versions.tsv; rm -f .gen/versions.tsv.tmp
dup=$(cut -f3 .gen/versions.tsv | uniq -d | head -n 1)
[ -z "$dup" ] || sections_fail "$VCONF: two versions have the weight $dup"
ndef=$(awk -F'\t' '$4 == "true"' .gen/versions.tsv | wc -l | tr -d ' ')
[ "$ndef" = 1 ] || sections_fail "$VCONF: $ndef versions are the default; exactly one has default = true"
VERSIONS=$(cut -f1 .gen/versions.tsv | tr '\n' ' '); VERSIONS=${VERSIONS% }
DEFAULT=$(awk -F'\t' '$4 == "true" { print $1 }' .gen/versions.tsv)
export VERSIONS DEFAULT

# --- The enhancements section ------------------------------------------------------
ENH_DIR=""; ENH_REF=""; ENH_SHA=""; ENH_HOW=""; ENH_DIGEST=""
n=$(jq '[.bundles[]? | select(.root == "/enhancements/")] | length' "$CAT_DIR/lock.json" 2>/dev/null) ||
  sections_fail "$CAT_DIR/lock.json is not JSON; run task bundles:pull"
[ "$n" -le 1 ] || sections_fail "$CAT_DIR/lock.json names $n /enhancements/ bundles; a section has one"
e=$(jq -c '[.bundles[]? | select(.root == "/enhancements/")] | .[0] // empty' "$CAT_DIR/lock.json")
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
export ENH_DIR ENH_REF ENH_SHA ENH_HOW ENH_DIGEST
