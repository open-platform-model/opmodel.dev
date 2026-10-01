#!/bin/sh
# resolve-versions: the versions manifest (site/versions.conf) -> the refs and
# SHAs every site version documents. Host side: git cannot read a worktree's
# history inside the build container, so this runs before it (task
# versions:prepare). POSIX sh, git and awk.
#
#   resolve-versions.sh              resolve and check every version, then write
#                                    site/.versions/versions.tsv and site/.versions/frozen.conf
#                                    for the build; with OPM_VERSIONS set (explicit mode) only
#                                    remove stale ones
#   resolve-versions.sh --check      resolve and check every version, print the table, write nothing
#   resolve-versions.sh --freeze     resolve and check every version, print the frozen manifest
#                                    (frozen.conf), write nothing
#   resolve-versions.sh --pins REF   print the library, core and opm-operator refs that cli REF
#                                    pins; no docs/site or floor check
#   resolve-versions.sh --fetch      fetch every tag and branch of the six roots from origin
#                                    (task versions:fetch); never moves or deletes a tag
#
# Environment:
#   OPM_VERSIONS_MANIFEST  the manifest (default site/versions.conf); never
#                          site/.versions/frozen.conf itself, which write mode rewrites
#   OPM_VERSIONS           set by a caller that owns the version set (fixture builds)
#   OPM_WS, OPM_SRC_WORKTREE, OPM_SRC_<REPO>
#                          the source roots, resolved by run-in-image.sh exactly as for a build
#
# A version has one of three kinds, chosen by its keys:
#   main      "source = main": every root at its checked-out HEAD, read in place
#             (tests and local live editing).
#   anchored  "cli = <tag or SHA>" is the anchor, bumped by commit: library
#             comes from cli go.mod, core from library opm/schema/loader.go
#             DefaultSchemaModule, opm-operator from cli
#             internal/operator/manifest.go PinnedOperatorVersion; catalog and
#             opm are explicit.
#   line      "cli-line = vX.Y" and "catalog-line = opm-vN", resolved again on
#             every build: cli is the newest vX.Y.* tag by SemVer precedence,
#             prereleases included; library, opm-operator and core are exactly
#             what that tag pins; catalog_opm is the newest opm-vN.* tag; opm
#             is the head of main. The docs of core and catalog_opm come from
#             release/<prefix>vX.Y (X.Y: the minor of the release the stamp
#             names) when that branch exists, else from main's head while main
#             still releases X.Y, else from that release's own tag.
# cli/hack/platform/ is a test fixture and never read. An override
# (<repo> <ref> <reason>) replaces one row, never cli. In a line version it is
# only for a row that fails: the row it replaces is still resolved and
# checked, and the run fails once that row passes again. Every tree built must
# be a commit, hold docs/site and contain its repository's dialect floor; in a
# line version the release the stamp names for core and catalog_opm must
# contain its floor too, and a branch head its docs come from must contain it.
#
# Line mode reads tags and the remote-tracking refs refs/remotes/origin/main
# and refs/remotes/origin/release/<prefix>vX.Y, never a local branch or HEAD,
# and assumes that origin is the upstream open-platform-model repository (it
# does not check the URL). It refuses a shallow root and a root without
# refs/remotes/origin/main. It never fetches; --fetch does, with explicit
# refspecs (the tag one without +), an empty --refmap= so every configured
# remote.origin.fetch mapping is ignored, --no-prune --no-prune-tags
# --no-tags and --no-write-fetch-head, so no git config can make it move or
# delete a tag or a local branch, and it writes nothing in a worktree.
#
# Every row records the ref the stamp names, the SHA of the tree built, how it
# was found, and where that tree came from (docs: tag, sha, main,
# release/<prefix>vX.Y, or worktree for source = main); the "# site" line
# records the opmodel.dev commit. frozen.conf is the same build as an anchored
# manifest: a row whose docs is a tag by its tag name, every other row by SHA.
#
# Failures print one line each, "<version>: <repo> <ref>: <reason>" (in a line
# version the ref names the rule that chose it), all of them, and then the run
# exits 1.
set -euf
export LC_ALL=C
REPOS="opm core catalog_opm cli library opm-operator"
LIB=github.com/open-platform-model/library
TAB=$(printf '\t')
NL='
'
SCRIPTS=$(cd "$(dirname "$0")" && pwd -P)
SITE=$(cd "$SCRIPTS/.." && pwd -P)
OUT=$SITE/.versions/versions.tsv
FROZEN=$SITE/.versions/frozen.conf

usage() { sed -n '2,/^# A version has/p' "$0" | sed '$d' >&2; exit 2; }
mode="write"; pinref=""
case "${1:-}" in
  "") ;;
  --check) mode=check ;;
  --freeze) mode=freeze ;;
  --fetch) mode=fetch ;;
  --pins) mode=pins; pinref=${2:-}; [ -n "$pinref" ] || usage ;;
  *) usage ;;
esac

manifest=${OPM_VERSIONS_MANIFEST:-$SITE/versions.conf}
case "$manifest" in /*) ;; *) manifest=$(pwd -P)/$manifest ;; esac
# The frozen manifest is never an input: write mode would rewrite it on
# success and remove it on failure. Refused by path, before it is read and
# before the trap below is set.
case "$mode" in write|check|freeze)
  mdir=$(cd "$(dirname "$manifest")" 2>/dev/null && pwd -P) || mdir=$(dirname "$manifest")
  if [ "$mdir/$(basename "$manifest")" = "$FROZEN" ]; then
    echo "resolve-versions: $FROZEN is the generated frozen manifest, which this run rewrites; copy it outside site/.versions/ first" >&2
    exit 1
  fi ;;
esac
# In write mode a failed run, at any step, leaves no versions.tsv and no
# frozen.conf behind, so no build can read a stale or half-written version list.
if [ "$mode" = write ]; then trap '[ $? -eq 0 ] || rm -f "$OUT" "$OUT.tmp" "$FROZEN" "$FROZEN.tmp"' EXIT; fi

if [ "$mode" = write ] && [ -n "${OPM_VERSIONS:-}" ]; then
  rm -f "$OUT" "$FROZEN"
  echo "resolve-versions: OPM_VERSIONS is set ($OPM_VERSIONS): explicit mode, nothing to resolve"
  exit 0
fi

# --- Source roots -----------------------------------------------------------
# run-in-image.sh owns the rule (OPM_SRC_<REPO>, else OPM_WS/<repo>/.claude/
# worktrees/OPM_SRC_WORKTREE, else OPM_WS/<repo>) and its check (the root
# exists and holds docs/site, naming OPM_SRC_<REPO> when not). It is sourced
# in a subshell with mode "tag", which only prints the image tag (discarded);
# sources() then leaves MOUNTS (-v <root>:/src/<repo>:ro ...) and REFS
# (<repo>=<HEAD SHA>, or none for a root that is not its own git top level).
table=$(sh -c '. "$0" >/dev/null
  sources
  for m in $MOUNTS; do [ "$m" = -v ] || printf "root %s\n" "$m"; done
  for p in $REFS; do printf "top %s\n" "$p"; done' "$SCRIPTS/run-in-image.sh" tag) || {
  echo "resolve-versions: the source roots above are missing; set OPM_SRC_<REPO> (or OPM_WS, OPM_SRC_WORKTREE)" >&2
  exit 1
}
root_of() { printf '%s\n' "$table" | awk -v r="$1" '$1 == "root" { m = $2; sub(/:\/src\/.*/, "", m); d = $2; sub(/.*:\/src\//, "", d); sub(/:ro$/, "", d); if (d == r) print m }'; }
top_of() { printf '%s\n' "$table" | awk -v r="$1" '$1 == "top" { split($2, a, "="); if (a[1] == r) print a[2] }'; }
var_of() { printf 'OPM_SRC_%s' "$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')"; }

# Root checks, before any ref is read: a root must be its own git top level.
# A root inside another repository would silently resolve that repository.
if [ "$mode" = pins ]; then need="cli library"; else need=$REPOS; fi
rootbad=""
for r in $need; do
  if [ "$(top_of "$r")" = none ]; then
    rootbad="$rootbad$r: root $(root_of "$r"): not its own git top level (it sits inside another repository, or in none); set $(var_of "$r") to a checkout or worktree of $r. A fixture workspace is built in explicit mode instead, with OPM_VERSIONS=v1.0=/src, which skips resolution$NL"
  fi
done
if [ -n "$rootbad" ]; then printf '%s' "$rootbad" >&2; exit 1; fi

# --- Fetch -------------------------------------------------------------------
# With refspecs on the command line, git still applies every configured
# remote.origin.fetch as an extra mapping, with its own +: a configured
# +refs/heads/*:refs/heads/* would force-reset each local branch that is not
# checked out. The empty --refmap= makes git ignore every configured refspec,
# so only the two below run. The tag refspec has no +, so git refuses to move
# a local tag that differs upstream ("would clobber existing tag", exit 1)
# while every other ref still updates; --no-prune --no-prune-tags beat
# fetch.prune and fetch.pruneTags; --no-write-fetch-head leaves no FETCH_HEAD
# in a worktree. Remote-tracking refs update forcibly, as in any fetch; no
# local branch is created or moved.
if [ "$mode" = fetch ]; then
  failed=""
  for r in $REPOS; do
    root=$(root_of "$r")
    echo "resolve-versions: fetching $r ($root)"
    if git -C "$root" fetch --no-write-fetch-head --no-prune --no-prune-tags --no-tags --refmap= origin \
      '+refs/heads/*:refs/remotes/origin/*' 'refs/tags/*:refs/tags/*'; then :
    else failed="$failed$NL  $r: $root"; fi
  done
  if [ -n "$failed" ]; then
    echo "resolve-versions: --fetch failed in:$failed" >&2
    echo "resolve-versions: \"would clobber existing tag\" means a local tag differs from origin's; tags are immutable, so never force it: report it" >&2
    exit 1
  fi
  echo "resolve-versions: fetched the tags and branches of every root; no tag moved or deleted"
  exit 0
fi

# --- Refs --------------------------------------------------------------------
# is_ref_text REF: the characters a tag or SHA may use here (the ref lands in
# TOML, JSON and URLs unquoted-safe).
is_ref_text() { case "$1" in ''|*[!A-Za-z0-9._/+-]*) return 1 ;; esac; }
is_sha() { printf '%s' "$1" | grep -Eq '^[0-9a-f]{40}$'; }
commit_of() { git -C "$1" rev-parse --verify --quiet "$2^{commit}" 2>/dev/null; }
short() { printf '%.7s' "$1"; }

# anchor REPO REF: the SHA of a fixed ref (a tag, or a full 40-hex SHA), else
# print the reason and return 1. Never a branch, HEAD, a pattern or a short SHA.
anchor() {
  root=$(root_of "$1")
  if ! is_ref_text "$2"; then echo "not a tag or a full SHA (characters outside A-Z a-z 0-9 . _ / + -)"; return 1; fi
  if is_sha "$2"; then
    commit_of "$root" "$2" || { echo "not a commit in $root"; return 1; }
  elif commit_of "$root" "refs/tags/$2" >/dev/null; then
    if [ "$1" = catalog_opm ]; then
      case "$2" in opm-v*|k8s-v*) ;; *) echo "a catalog tag is opm-v* or k8s-v*"; return 1 ;; esac
    fi
    commit_of "$root" "refs/tags/$2"
  else
    echo "a moving or unknown ref: an anchor is a tag or a full 40-hex SHA, never a branch, HEAD, a pattern or a short SHA (no tag refs/tags/$2 in $root)"
    return 1
  fi
}

# pinned REPO VERSION: the SHA of the release tag VERSION, else the reason.
pinned() {
  root=$(root_of "$1")
  if ! is_ref_text "$2"; then echo "not a release tag"; return 1; fi
  if printf '%s' "$2" | grep -Eq '[0-9]{14}-[0-9a-f]{12}$'; then echo "a Go pseudo-version, not a release"; return 1; fi
  commit_of "$root" "refs/tags/$2" || { echo "no tag $2 in $root (fetch its tags)"; return 1; }
}

# pin_library CLI_SHA: the library version cli go.mod requires, else the reason.
pin_library() {
  mod=$(git -C "$(root_of cli)" show "$1:go.mod" 2>/dev/null) || { echo "no go.mod"; return 1; }
  got=$(printf '%s\n' "$mod" | awk -v LIB="$LIB" '
    { sub(/\/\/.*/, "") }
    blk != "" && /^[ \t]*\)/ { blk = ""; next }
    /^(require|replace)[ \t]*\([ \t]*$/ { blk = $0; sub(/[ \t]*\(.*/, "", blk); next }
    { if (blk != "") $0 = blk " " $0 }
    $1 == "replace" && $2 == LIB { print "replace" }
    $1 == "require" && $2 == LIB { print "require " $3 }')
  case "$got" in
    *replace*) echo "go.mod replaces $LIB"; return 1 ;;
    "require "*) v=${got#require }; case "$v" in *"$NL"*|'') echo "more than one require line for $LIB in go.mod"; return 1 ;; esac; echo "$v" ;;
    *) echo "no require line for $LIB in go.mod"; return 1 ;;
  esac
}

# pin_const REPO SHA FILE NAME PREFIX: the version in `NAME = "PREFIXvX"`,
# matched by its text, never by its line number.
pin_const() {
  src=$(git -C "$(root_of "$1")" show "$2:$3" 2>/dev/null) || { echo "no $3"; return 1; }
  vals=$(printf '%s\n' "$src" | sed -nE "s#(^|.*[^A-Za-z0-9_])$4[[:space:]]*=[[:space:]]*\"$5([^\"]*)\".*#\\2#p")
  case "$vals" in
    '') echo "no $4 = \"$5...\" in $3"; return 1 ;;
    *"$NL"*) echo "more than one $4 in $3"; return 1 ;;
  esac
  echo "$vals"
}

# resolve_pins CLI_REF CLI_SHA VERSION OVERRIDES: one line per derived repo,
# "<repo>\t<ref>\t<sha>\t<how>", or "!<line>" for a failure. A failing pin
# whose version was read also prints "?<repo>\t<ref>\t<how>" (a line version
# names it as the row its override replaces). OVERRIDES holds
# "<repo>\t<ref>\t<reason>" lines; an overridden pin is not read.
resolve_pins() {
  cref=$1; csha=$2; ver=$3; ovr=$4
  ov() { printf '%s\n' "$ovr" | awk -F'\t' -v r="$1" '$1 == r { print $2 "\t" $3 }'; }
  # library
  o=$(ov library)
  if [ -n "$o" ]; then
    lref=${o%%"$TAB"*}
    if lsha=$(anchor library "$lref"); then echo "library${TAB}$lref${TAB}$lsha${TAB}override:${o#*"$TAB"}"; else echo "!$ver: library $lref: $lsha"; lsha=""; fi
  elif lref=$(pin_library "$csha"); then
    if lsha=$(pinned library "$lref"); then echo "library${TAB}$lref${TAB}$lsha${TAB}pin:cli go.mod"
    else echo "!$ver: library $lref: $lsha (pinned in cli go.mod at cli $cref); pin a release there, or add override = library <ref> <reason>"; echo "?library${TAB}$lref${TAB}pin:cli go.mod"; lsha=""; fi
  else
    echo "!$ver: library (no pin): $lref (cli go.mod at cli $cref); add override = library <ref> <reason>"; lref=""; lsha=""
  fi
  # core, read at the effective library ref
  o=$(ov core)
  if [ -n "$o" ]; then
    kref=${o%%"$TAB"*}
    if ksha=$(anchor core "$kref"); then echo "core${TAB}$kref${TAB}$ksha${TAB}override:${o#*"$TAB"}"; else echo "!$ver: core $kref: $ksha"; fi
  elif [ -z "$lsha" ]; then
    echo "!$ver: core (no pin): the library ref did not resolve, so its DefaultSchemaModule cannot be read; add override = core <ref> <reason>"
  elif kref=$(pin_const library "$lsha" opm/schema/loader.go DefaultSchemaModule 'opmodel\.dev/core@'); then
    if printf '%s' "$kref" | grep -Eq '^v[0-9]+$'; then
      echo "!$ver: core $kref: DefaultSchemaModule names only a major (opmodel.dev/core@$kref) in library opm/schema/loader.go at library $lref; add override = core <ref> <reason>"
    elif ksha=$(pinned core "$kref"); then echo "core${TAB}$kref${TAB}$ksha${TAB}pin:library opm/schema/loader.go"
    else echo "!$ver: core $kref: $ksha (pinned in library opm/schema/loader.go at library $lref); add override = core <ref> <reason>"; echo "?core${TAB}$kref${TAB}pin:library opm/schema/loader.go"; fi
  else
    echo "!$ver: core (no pin): $kref (library at $lref); add override = core <ref> <reason>"
  fi
  # opm-operator
  o=$(ov opm-operator)
  if [ -n "$o" ]; then
    pref=${o%%"$TAB"*}
    if psha=$(anchor opm-operator "$pref"); then echo "opm-operator${TAB}$pref${TAB}$psha${TAB}override:${o#*"$TAB"}"; else echo "!$ver: opm-operator $pref: $psha"; fi
  elif pref=$(pin_const cli "$csha" internal/operator/manifest.go PinnedOperatorVersion ''); then
    if psha=$(pinned opm-operator "$pref"); then echo "opm-operator${TAB}$pref${TAB}$psha${TAB}pin:cli internal/operator/manifest.go"
    else echo "!$ver: opm-operator $pref: $psha (pinned in cli internal/operator/manifest.go at cli $cref); add override = opm-operator <ref> <reason>"; echo "?opm-operator${TAB}$pref${TAB}pin:cli internal/operator/manifest.go"; fi
  else
    echo "!$ver: opm-operator (no pin): $pref (cli at $cref); add override = opm-operator <ref> <reason>"
  fi
}

if [ "$mode" = pins ]; then
  csha=$(anchor cli "$pinref") || csha=$(commit_of "$(root_of cli)" "$pinref") || {
    echo "cli $pinref: not a commit in $(root_of cli)" >&2; exit 1; }
  rows=$(resolve_pins "$pinref" "$csha" "pins" "")
  printf '# repo\tref\tsha\thow\ncli\t%s\t%s\tanchor\n' "$pinref" "$csha"
  printf '%s\n' "$rows" | grep -v '^[!?]' || true
  if printf '%s\n' "$rows" | grep -q '^!'; then printf '%s\n' "$rows" | sed -n 's/^!//p' >&2; exit 1; fi
  exit 0
fi

# --- Release lines ---------------------------------------------------------------
# semver_max PREFIX: of the tag names on stdin, every one PREFIXvX.Y.Z[-pre],
# print the highest by SemVer 2.0.0 precedence (section 11): major, minor and
# patch compare numerically; a release outranks its own prereleases;
# prerelease identifiers compare left to right, numeric ones numerically and
# below alphanumeric ones, which compare in ASCII order; a shorter set ranks
# lower when it is a prefix of a longer one. So v1.0.0 > v1.0.0-rc.1 >
# v1.0.0-beta.10 > v1.0.0-beta.2, and v1.0.1-beta.1 > v1.0.0. Never sort
# release tags with sort -V or a plain git tag --sort=-v:refname: both rank
# v1.0.0 below v1.0.0-beta.4. git's versionsort.suffix=- order is right only
# while every prerelease uses "-", so the tests use it as an oracle only.
semver_max() {
  awk -v P="$1" '
    function num(a, b) {
      sub(/^0+/, "", a); sub(/^0+/, "", b)
      if (length(a) != length(b)) return length(a) < length(b) ? -1 : 1
      if ((a "") == (b "")) return 0
      return ((a "") < (b "")) ? -1 : 1
    }
    function pre(a, b,   na, nb, pa, pb, i, x, y, xn, yn) {
      if ((a "") == (b "")) return 0
      if (a == "") return 1
      if (b == "") return -1
      na = split(a, pa, "."); nb = split(b, pb, ".")
      for (i = 1; i <= na && i <= nb; i++) {
        x = pa[i] ""; y = pb[i] ""
        if (x == y) continue
        xn = (x ~ /^[0-9]+$/); yn = (y ~ /^[0-9]+$/)
        if (xn && yn) return num(x, y)
        if (xn) return -1
        if (yn) return 1
        return (x < y) ? -1 : 1
      }
      return (na < nb) ? -1 : (na > nb ? 1 : 0)
    }
    function cmp(a, b,   ca, cb, pa, pb, va, vb, i, c) {
      a = substr(a, length(P) + 2); b = substr(b, length(P) + 2)
      ca = a; pa = ""; if (index(a, "-")) { ca = substr(a, 1, index(a, "-") - 1); pa = substr(a, index(a, "-") + 1) }
      cb = b; pb = ""; if (index(b, "-")) { cb = substr(b, 1, index(b, "-") - 1); pb = substr(b, index(b, "-") + 1) }
      split(ca, va, "."); split(cb, vb, ".")
      for (i = 1; i <= 3; i++) { c = num(va[i], vb[i]); if (c) return c }
      return pre(pa, pb)
    }
    NF { if (best == "" || cmp($0, best) > 0) best = $0 }
    END { if (best != "") print best }'
}
# line_re PREFIX LINE: the ERE of a line's tags, never a glob, so v1.50.0 is not
# in v1.5, opm-v40.0.0 not in opm-v4, and neither k8s-v* nor catalog_opm's
# unprefixed legacy tags are in an opm-v line. LINE is X.Y (a minor) or X (a major).
line_re() {
  case "$2" in
    *.*) printf '^%sv%s\\.%s\\.[0-9]+(-[0-9A-Za-z.-]+)?$' "$1" "${2%%.*}" "${2#*.}" ;;
    *) printf '^%sv%s\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$' "$1" "$2" ;;
  esac
}
# release_re PREFIX: the ERE of every PREFIXvX.Y.Z[-pre] release tag.
release_re() { printf '^%sv[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$' "$1"; }
# line_tags ROOT PREFIX LINE: the tags of the line; newest_in_line: the highest of them.
line_tags() { git -C "$1" tag -l | grep -E "$(line_re "$2" "$3")" || true; }
newest_in_line() { nl_tag=$(line_tags "$1" "$2" "$3" | semver_max "$2"); [ -n "$nl_tag" ] || return 1; echo "$nl_tag"; }
# main_head ROOT: the SHA of refs/remotes/origin/main; never HEAD or a local branch.
main_head() { commit_of "$1" refs/remotes/origin/main; }
# minor_of PREFIX REF: X.Y of the release tag REF (PREFIXvX.Y.Z[-pre]), else fail.
minor_of() {
  printf '%s\n' "$2" | grep -Eq "$(release_re "$1")" || return 1
  mo_v=${2#"$1"v}; mo_x=${mo_v%%.*}; mo_v=${mo_v#*.}; echo "$mo_x.${mo_v%%.*}"
}

# docs_source REPO PREFIX X.Y REF: where the docs of release REF (in minor X.Y)
# come from, "<docs>\t<sha>\t<rule>\t<short rule>". The first rule that applies:
#   1. refs/remotes/origin/release/PREFIXvX.Y exists: its head;
#   2. the newest PREFIXv<semver> tag merged into refs/remotes/origin/main is in
#      X.Y (main still releases the line): main's head;
#   3. otherwise main is past the line and no branch was cut: REF's own commit,
#      never a newer patch of the line, so the tree is always the named release.
# Only the exact derived branch name is read: a stale or unrelated tracking ref
# is never consulted, and release/k8s-v* never is.
docs_source() {
  ds_root=$(root_of "$1"); ds_b=release/$2v$3
  if ds_sha=$(commit_of "$ds_root" "refs/remotes/origin/$ds_b"); then
    printf '%s\t%s\t%s\t%s\n' "$ds_b" "$ds_sha" "$ds_b head" "$ds_b head"; return 0
  fi
  ds_new=$(git -C "$ds_root" tag -l --merged refs/remotes/origin/main | grep -E "$(release_re "$2")" | semver_max "$2")
  if [ -n "$ds_new" ] && [ "$(minor_of "$2" "$ds_new")" = "$3" ]; then
    printf 'main\t%s\t%s\t%s\n' "$(main_head "$ds_root")" "main head (no $ds_b; main still releases $2v$3)" "main head"; return 0
  fi
  printf 'tag\t%s\t%s\t%s\n' "$(commit_of "$ds_root" "refs/tags/$4")" "$4 (main is past $2v$3, no $ds_b)" "its tag"
}

# --- The manifest ------------------------------------------------------------
[ -f "$manifest" ] || { echo "resolve-versions: no manifest at $manifest" >&2; exit 1; }
cfg() { git config --file "$manifest" "$@"; }
keys=$(cfg --name-only --list) || { echo "resolve-versions: $manifest is not valid git-config syntax (see the line above)" >&2; exit 1; }
count() { cfg --null --get-all "$1" 2>/dev/null | tr -cd '\000' | wc -c | tr -d ' '; }
lines() { cfg --get-all "$1" 2>/dev/null | wc -l | tr -d ' '; }
# one KEY: the single value of KEY (empty when absent); a newline inside it counts as bad text.
one() { cfg --get "$1" 2>/dev/null || true; }
# has VERSION KEY: the version sets KEY.
has() { [ "$(count "version.$1.$2")" -gt 0 ]; }
bad_text() { case "$1" in *"$TAB"*|*\'*|*\"*|*\\*|*"$NL"*) return 0 ;; esac; return 1; }
errs=""
err() { errs="$errs$*$NL"; }

# Grammar: every key is known.
versions=""
while IFS= read -r k; do
  [ -n "$k" ] || continue
  sec=${k%%.*}; rest=${k#*.}; key=${k##*.}; sub=${rest%.*}
  if [ "$rest" = "$key" ]; then err "$(basename "$manifest"): unknown key \"$k\""; continue; fi
  case "$sec.$key" in
    repo.floor) case " $REPOS " in *" $sub "*) ;; *) err "$(basename "$manifest"): unknown key \"$k\" (repositories: $REPOS)" ;; esac ;;
    version.label|version.weight|version.default|version.source|version.cli|version.catalog|version.opm|version.override|version.cli-line|version.catalog-line)
      case " $versions " in *" $sub "*) ;; *) versions="$versions${versions:+ }$sub" ;; esac ;;
    *) err "$(basename "$manifest"): unknown key \"$k\"" ;;
  esac
done <<EOF
$keys
EOF

for r in $REPOS; do
  n=$(count "repo.$r.floor")
  f=$(one "repo.$r.floor")
  if [ "$n" -ne 1 ]; then err "repo $r: floor: exactly one floor is required ($n found)"
  elif ! is_sha "$f"; then err "repo $r: floor $f: not a full 40-hex SHA"
  elif ! commit_of "$(root_of "$r")" "$f" >/dev/null; then err "repo $r: floor $f: not a commit in $(root_of "$r") (fetch it)"
  fi
done

# A version's kind comes from its keys: source makes it main, cli-line makes
# it line, anything else is anchored. A key that its kind excludes is a named
# error, never silently ignored.
[ -n "$versions" ] || err "$(basename "$manifest"): no [version \"...\"] section"
defaults=""; mains=""; linevs=""; weights=""
for v in $versions; do
  if ! printf '%s' "$v" | grep -Eq '^v[0-9]+\.[0-9]+$'; then err "version $v: the name is a URL segment and must be vN.N"; fi
  for k in label weight default source cli catalog opm cli-line catalog-line; do
    if [ "$(count "version.$v.$k")" -gt 1 ]; then err "version $v: more than one $k"; fi
  done
  label=$(one "version.$v.label")
  if [ -z "$label" ]; then err "version $v: label is required"
  elif bad_text "$label" || [ "$(lines "version.$v.label")" -gt 1 ]; then err "version $v: label \"$label\" holds a tab, ', \" or \\ or a line break"; fi
  w=$(one "version.$v.weight")
  if ! printf '%s' "$w" | grep -Eq '^[1-9][0-9]*$'; then err "version $v: weight \"$w\" must be a positive integer"
  else
    case " $weights " in *" $w "*) err "version $v: weight $w is taken by another version" ;; esac
    weights="$weights $w"
  fi
  if [ "$(count "version.$v.default")" -gt 0 ]; then
    d=$(cfg --type=bool --get "version.$v.default" 2>/dev/null) || { err "version $v: default must be true or false"; d=false; }
    [ "$d" = false ] || defaults="$defaults $v"
  fi
  if has "$v" source; then
    kind=main
    s=$(one "version.$v.source")
    if [ "$s" != main ]; then err "version $v: source \"$s\": the only source is main"; fi
    mains="$mains $v"
    for k in cli catalog opm override cli-line catalog-line; do
      if has "$v" "$k"; then err "version $v: source = main excludes $k"; fi
    done
  elif has "$v" cli-line; then
    kind=line
    linevs="$linevs $v"
    for k in cli catalog opm; do
      if has "$v" "$k"; then err "version $v: cli-line excludes $k: a line version resolves cli, catalog and opm from their lines"; fi
    done
    cl=$(one "version.$v.cli-line")
    if ! printf '%s' "$cl" | grep -Eq '^v[0-9]+\.[0-9]+$'; then err "version $v: cli-line \"$cl\": not a cli minor line vX.Y (for example v1.0)"; fi
    if ! has "$v" catalog-line; then err "version $v: cli-line needs catalog-line = opm-vN, the opm catalog major (for example opm-v4)"
    else
      gl=$(one "version.$v.catalog-line")
      if printf '%s' "$gl" | grep -Eq '^opm-v[0-9]+$'; then :
      elif printf '%s' "$gl" | grep -Eq '^opm-v[0-9]+\.[0-9]+'; then
        gmaj=${gl#opm-v}; err "version $v: catalog-line \"$gl\": a minor; the catalog line is the opm catalog major (opm-v${gmaj%%.*}), which follows every minor"
      elif printf '%s' "$gl" | grep -Eq '^k8s-v'; then err "version $v: catalog-line \"$gl\": only the opm catalog line opm-vN is followed; the k8s catalog pages follow its tree"
      else err "version $v: catalog-line \"$gl\": not an opm catalog major opm-vN (for example opm-v4)"; fi
    fi
  else
    kind=anchored
    for k in cli catalog opm; do
      if ! has "$v" "$k"; then err "version $v: $k is required in an anchored version (or set source = main, or cli-line and catalog-line)"; fi
    done
    if has "$v" catalog-line; then err "version $v: catalog-line needs cli-line: an anchored version names catalog = <tag or SHA> instead"; fi
  fi
  seen=""
  ovals=$(cfg --get-all "version.$v.override" 2>/dev/null || true)
  if [ "$(lines "version.$v.override")" -ne "$(count "version.$v.override")" ]; then err "version $v: an override holds a line break"; fi
  while IFS= read -r o; do
    [ -n "$o" ] || continue
    orepo=${o%% *}; rest=${o#"$orepo"}; rest=${rest# }; oref=${rest%% *}; reason=${rest#"$oref"}; reason=${reason# }
    case " $REPOS " in *" $orepo "*) ;; *) err "version $v: override \"$o\": unknown repository $orepo"; continue ;; esac
    if [ "$orepo" = cli ]; then
      if [ "$kind" = line ]; then err "version $v: override \"$o\": cli follows cli-line and is never overridden; to hold it, move the version back to anchored (README \"Site versions\")"
      else err "version $v: override \"$o\": cli is the anchor; set cli instead"; fi
      continue
    fi
    if [ -z "$oref" ] || [ -z "$reason" ]; then err "version $v: override $orepo ${oref:-(no ref)}: write override = $orepo <ref> <reason>; the reason is required"; continue; fi
    if bad_text "$reason"; then err "version $v: override $orepo $oref: the reason holds a tab, ', \" or \\"; fi
    case " $seen " in *" $orepo "*) err "version $v: more than one override for $orepo" ;; esac
    seen="$seen $orepo"
  done <<EOF
$ovals
EOF
done
# shellcheck disable=SC2086 # split on purpose (set -f: no globbing)
set -- $defaults
[ $# -eq 1 ] || err "$(basename "$manifest"): exactly one version is the default (default = true); found ${#}${defaults:+:$defaults}"
# shellcheck disable=SC2086
set -- $mains
[ $# -le 1 ] || err "$(basename "$manifest"): at most one version has source = main; found:$mains"

# A line version reads tags and remote-tracking refs, which a shallow root
# lacks and a root without refs/remotes/origin/main has never fetched.
for v in $linevs; do
  for r in $REPOS; do
    root=$(root_of "$r")
    if [ "$(git -C "$root" rev-parse --is-shallow-repository 2>/dev/null || true)" = true ]; then
      err "$v: $r: root $root: a shallow clone; a line version needs full history and tags (fetch-depth: 0)"
    fi
    if ! main_head "$root" >/dev/null; then
      err "$v: $r: root $root: no refs/remotes/origin/main; a line version reads remote-tracking refs (task versions:fetch)"
    fi
  done
done

if [ -n "$errs" ]; then
  printf '%s' "$errs" >&2
  echo "resolve-versions: $manifest: $(printf '%s' "$errs" | grep -c .) problem(s)" >&2
  exit 1
fi

# --- Checks ----------------------------------------------------------------------
# floor_problem ROOT FLOOR SHA, docs_problem ROOT SHA KIND: why the tree at SHA
# cannot build, or nothing.
floor_problem() {
  if git -C "$1" merge-base --is-ancestor "$2" "$3" 2>/dev/null; then :
  else
    fp_rc=$?
    if [ $fp_rc -eq 1 ]; then echo "older than its floor $2 (the page-dialect merge); no ref before it builds"
    else echo "cannot compare with its floor $2 in $1"; fi
  fi
}
docs_problem() {
  if [ "$3" = main ]; then
    if [ ! -d "$1/docs/site" ]; then echo "no docs/site in $1"; fi
  elif [ -z "$(git -C "$1" ls-tree -d --name-only "$2" docs/site 2>/dev/null)" ]; then
    echo "no docs/site at this ref"
  fi
}
# tree_problems REPO SHA KIND: both, one per line.
tree_problems() { docs_problem "$(root_of "$1")" "$2" "$3"; floor_problem "$(root_of "$1")" "$(one "repo.$1.floor")" "$2"; }
# report VERSION REPO PREFIX PROBLEMS: one error per problem, "VERSION: REPO PREFIXproblem".
report() {
  while IFS= read -r rp_l; do
    if [ -n "$rp_l" ]; then err "$1: $2 $3$rp_l"; fi
  done <<EOF
$4
EOF
}
# check_ref VERSION REPO REFTEXT SHA KIND: the tree built holds docs/site and contains the floor.
check_ref() { report "$1" "$2" "$3: " "$(tree_problems "$2" "$4" "$5")"; }
# release_problems REPO REF RSHA DOCS DSHA SHORT RELTEXT: the problems of a core
# or catalog_opm row in a line version, one "<ref text>: <reason>" per line.
# Under docs_source rule 3 the tree is the release itself, checked once; under
# rules 1 and 2 the branch head is checked, the release the stamp names must
# contain its floor too, and the head must contain the release.
release_problems() {
  if [ "$4" = tag ]; then
    tree_problems "$1" "$5" line | awk -v p="$2 ($7; docs $6): " 'NF { print p $0 }'
  else
    rp_t="$4 $(short "$5") (docs for $2)"
    tree_problems "$1" "$5" line | awk -v p="$rp_t: " 'NF { print p $0 }'
    floor_problem "$(root_of "$1")" "$(one "repo.$1.floor")" "$3" | awk -v p="$2 ($7; docs $6): " 'NF { print p $0 }'
    if git -C "$(root_of "$1")" merge-base --is-ancestor "$3" "$5" 2>/dev/null; then :
    else echo "$rp_t: does not contain $2, the release the stamp names"; fi
  fi
}
# release_docs REPO PREFIX REF RSHA RELTEXT: where the docs of the release REF
# (at RSHA) come from, into rd_docs, rd_sha, rd_rule and rd_short, and its
# problems, one per line, into rd_problems (rd_sha empty when REF is no
# PREFIXvX.Y.Z[-pre], whose minor names no line). RELTEXT names the rule that
# chose REF, for the error text.
release_docs() {
  rd_docs=""; rd_sha=""; rd_rule=""; rd_short=""; rd_problems=""
  if ! rd_xy=$(minor_of "$2" "$3"); then
    rd_problems="$3 ($5): not a release $2vX.Y.Z[-pre], so its docs line cannot be derived; add override = $1 <ref> <reason>"
    return 0
  fi
  rd_ds=$(docs_source "$1" "$2" "$rd_xy" "$3")
  rd_docs=$(printf '%s' "$rd_ds" | cut -f1); rd_sha=$(printf '%s' "$rd_ds" | cut -f2)
  rd_rule=$(printf '%s' "$rd_ds" | cut -f3); rd_short=$(printf '%s' "$rd_ds" | cut -f4)
  rd_problems=$(release_problems "$1" "$3" "$4" "$rd_docs" "$rd_sha" "$rd_short" "$5")
}

# --- Resolution --------------------------------------------------------------------
rows=""
row() { rows="$rows$1$TAB$2$TAB$3$TAB$4$TAB$5$TAB$6$TAB$7$TAB$8$TAB$9$TAB${10}$NL"; }
lrows=""
lrow() { lrows="$lrows$1$TAB$2$TAB$3$TAB$4$TAB$5$NL"; }
ovref() { printf '%s\n' "$ovr" | awk -F'\t' -v r="$1" '$1 == r { print $2 "\t" $3 }'; }

# override_row VERSION REPO REF SHA HOW REPLACED PASSES: an overridden row of a
# line version. REPLACED names the row the override replaces ("<ref> (<how>)",
# "no pin" or "no tag"), which was resolved and checked without reporting its
# errors; PASSES is yes when it passed every check, and then the override is
# stale: the run fails, so it cannot outlive the failure it was added for.
override_row() {
  or_docs=tag; if is_sha "$3"; then or_docs=sha; fi
  check_ref "$1" "$2" "$3 (override)" "$4" line
  if [ "$7" = yes ]; then
    err "$1: $2 override $3 (${5#override:}): no longer needed: the line resolves $6, which passes every check; remove the override"
  fi
  lrow "$2" "$3" "$4" "$5; replaces $6" "$or_docs"
}

# resolve_line VERSION: the rows of a line version into lrows, its errors into errs.
resolve_line() {
  lv=$1
  cl=$(one "version.$lv.cli-line"); gl=$(one "version.$lv.catalog-line")
  lrows=""
  # cli: the newest tag of the line; its pins are read only when it resolves.
  croot=$(root_of cli); csha=""
  if cref=$(newest_in_line "$croot" "" "${cl#v}"); then
    csha=$(commit_of "$croot" "refs/tags/$cref")
    check_ref "$lv" cli "$cref (newest tag of line $cl)" "$csha" line
    lrow cli "$cref" "$csha" "line:newest $cl.* tag" tag
  else
    err "$lv: cli line $cl: no tag $cl.<patch>[-<pre>] in $croot; fetch its tags (task versions:fetch)"
  fi
  # library, opm-operator and core: exactly what the cli tag pins.
  if [ -n "$csha" ]; then
    eff=$(resolve_pins "$cref" "$csha" "$lv" "$ovr")
    fails=$(printf '%s\n' "$eff" | sed -n 's/^!//p')
    [ -z "$fails" ] || errs="$errs$fails$NL"
    lib=$(printf '%s\n' "$eff" | awk -F'\t' '$1 == "library" { print $2 }')
    for r in library opm-operator core; do
      e=$(printf '%s\n' "$eff" | awk -F'\t' -v r="$r" '$1 == r')
      [ -n "$e" ] || continue
      ref=$(printf '%s' "$e" | cut -f2); sha=$(printf '%s' "$e" | cut -f3); how=$(printf '%s' "$e" | cut -f4-)
      if [ -n "$(ovref "$r")" ]; then
        # The replaced row: what r resolves to without its own override (core
        # is still read at the effective library).
        rp=$(resolve_pins "$cref" "$csha" "$lv" "$(printf '%s\n' "$ovr" | awk -F'\t' -v r="$r" '$1 != r')")
        rref=$(printf '%s\n' "$rp" | awk -F'\t' -v r="$r" '$1 == r { print $2 }')
        rsha=$(printf '%s\n' "$rp" | awk -F'\t' -v r="$r" '$1 == r { print $3 }')
        rhow=$(printf '%s\n' "$rp" | awk -F'\t' -v r="$r" '$1 == r { print $4 }')
        if [ -z "$rref" ]; then
          rref=$(printf '%s\n' "$rp" | awk -F'\t' -v r="?$r" '$1 == r { print $2 }')
          rhow=$(printf '%s\n' "$rp" | awk -F'\t' -v r="?$r" '$1 == r { print $3 }')
        fi
        passes=no
        if [ -n "$rsha" ]; then
          if [ "$r" = core ]; then
            release_docs core "" "$rref" "$rsha" "the release the stamp names"
            if [ -n "$rd_sha" ] && [ -z "$rd_problems" ]; then passes=yes; fi
          elif [ -z "$(tree_problems "$r" "$rsha" line)" ]; then passes=yes; fi
        fi
        if [ -n "$rref" ] && is_ref_text "$rref"; then replaced="$rref ($rhow)"; else replaced="no pin"; fi
        override_row "$lv" "$r" "$ref" "$sha" "$how" "$replaced" "$passes"
      elif [ "$r" = core ]; then
        release_docs core "" "$ref" "$sha" "the release the stamp names, pinned by library $lib"
        report "$lv" core "" "$rd_problems"
        [ -z "$rd_sha" ] || lrow core "$ref" "$rd_sha" "$how; docs: $rd_rule" "$rd_docs"
      else
        case "$r" in
          library) rule="pinned in cli go.mod at cli $cref" ;;
          *) rule="pinned in cli internal/operator/manifest.go at cli $cref" ;;
        esac
        check_ref "$lv" "$r" "$ref ($rule)" "$sha" line
        lrow "$r" "$ref" "$sha" "$how" tag
      fi
    done
  fi
  # catalog_opm: the newest tag of the catalog major.
  groot=$(root_of catalog_opm); gsha=""; gref=""
  if gref=$(newest_in_line "$groot" opm- "${gl#opm-v}"); then gsha=$(commit_of "$groot" "refs/tags/$gref"); else gref=""; fi
  ghow="line:newest $gl.* tag"
  o=$(ovref catalog_opm)
  if [ -n "$o" ]; then
    oref=${o%%"$TAB"*}
    if osha=$(anchor catalog_opm "$oref"); then
      passes=no; replaced="no tag"
      if [ -n "$gsha" ]; then
        replaced="$gref ($ghow)"
        release_docs catalog_opm opm- "$gref" "$gsha" "the release the stamp names"
        if [ -n "$rd_sha" ] && [ -z "$rd_problems" ]; then passes=yes; fi
      fi
      override_row "$lv" catalog_opm "$oref" "$osha" "override:${o#*"$TAB"}" "$replaced" "$passes"
    else
      err "$lv: catalog_opm $oref: $osha"
    fi
  elif [ -n "$gsha" ]; then
    release_docs catalog_opm opm- "$gref" "$gsha" "the release the stamp names, newest tag of line $gl"
    report "$lv" catalog_opm "" "$rd_problems"
    [ -z "$rd_sha" ] || lrow catalog_opm "$gref" "$rd_sha" "$ghow; docs: $rd_rule" "$rd_docs"
  else
    err "$lv: catalog_opm line $gl: no tag $gl.<minor>.<patch>[-<pre>] in $groot; fetch its tags (task versions:fetch)"
  fi
  # opm: no release line; the head of main. An override is refused unless that
  # head itself fails, since opm has no release to fall back to.
  msha=$(main_head "$(root_of opm)")
  o=$(ovref opm)
  if [ -n "$o" ]; then
    oref=${o%%"$TAB"*}
    if osha=$(anchor opm "$oref"); then
      passes=no; if [ -z "$(tree_problems opm "$msha" line)" ]; then passes=yes; fi
      override_row "$lv" opm "$oref" "$osha" "override:${o#*"$TAB"}" "main $(short "$msha") (line:main head)" "$passes"
    else
      err "$lv: opm $oref: $osha"
    fi
  else
    check_ref "$lv" opm "main $(short "$msha") (main head)" "$msha" line
    lrow opm main "$msha" "line:main head" main
  fi
}

ordered=$(for v in $versions; do printf '%s %s\n' "$(one "version.$v.weight")" "$v"; done | sort -n | awk '{ print $2 }')
for v in $ordered; do
  label=$(one "version.$v.label"); w=$(one "version.$v.weight")
  case " $defaults " in *" $v "*) d=true ;; *) d=false ;; esac
  if [ -n "$(one "version.$v.source")" ]; then
    for r in $REPOS; do
      sha=$(git -C "$(root_of "$r")" rev-parse HEAD)
      check_ref "$v" "$r" main "$sha" main
      row "$v" "$label" "$w" "$d" main "$r" main "$sha" head worktree
    done
    continue
  fi
  ovr=$(cfg --get-all "version.$v.override" 2>/dev/null | awk '{ r = $1; f = $2; $1 = ""; $2 = ""; sub(/^ +/, ""); print r "\t" f "\t" $0 }' || true)
  if [ -n "$(one "version.$v.cli-line")" ]; then
    resolve_line "$v"
    for r in $REPOS; do
      line=$(printf '%s' "$lrows" | awk -F'\t' -v r="$r" '$1 == r')
      [ -n "$line" ] || continue
      row "$v" "$label" "$w" "$d" line "$r" "$(printf '%s' "$line" | cut -f2)" "$(printf '%s' "$line" | cut -f3)" \
        "$(printf '%s' "$line" | cut -f4)" "$(printf '%s' "$line" | cut -f5)"
    done
    continue
  fi
  # cli, the anchor: its pins are read only when it resolves.
  cref=$(one "version.$v.cli")
  if csha=$(anchor cli "$cref"); then derived=$(resolve_pins "$cref" "$csha" "$v" "$ovr")
  else err "$v: cli $cref: $csha"; csha=""; derived=""; fi
  # catalog_opm and opm: explicit, or overridden
  explicit=""
  for pair in catalog_opm:catalog opm:opm; do
    r=${pair%%:*}; k=${pair#*:}
    o=$(ovref "$r")
    if [ -n "$o" ]; then ref=${o%%"$TAB"*}; how="override:${o#*"$TAB"}"; else ref=$(one "version.$v.$k"); how=explicit; fi
    if sha=$(anchor "$r" "$ref"); then explicit="$explicit$r$TAB$ref$TAB$sha$TAB$how$NL"; else err "$v: $r $ref: $sha"; fi
  done
  for r in $REPOS; do
    case "$r" in
      cli) line=""; [ -z "$csha" ] || line="cli$TAB$cref$TAB$csha${TAB}anchor" ;;
      catalog_opm|opm) line=$(printf '%s' "$explicit" | awk -F'\t' -v r="$r" '$1 == r') ;;
      *) line=$(printf '%s\n' "$derived" | awk -F'\t' -v r="$r" '$1 == r') ;;
    esac
    [ -n "$line" ] || continue
    ref=$(printf '%s' "$line" | cut -f2); sha=$(printf '%s' "$line" | cut -f3); how=$(printf '%s' "$line" | cut -f4-)
    if is_sha "$ref"; then docs=sha; else docs=tag; fi
    check_ref "$v" "$r" "$ref" "$sha" anchored
    row "$v" "$label" "$w" "$d" anchored "$r" "$ref" "$sha" "$how" "$docs"
  done
  fails=$(printf '%s\n' "$derived" | sed -n 's/^!//p')
  [ -z "$fails" ] || errs="$errs$fails$NL"
done

if [ -n "$errs" ]; then
  printf '%s' "$errs" >&2
  echo "resolve-versions: $manifest: $(printf '%s' "$errs" | grep -c .) problem(s)" >&2
  exit 1
fi

# --- Output ------------------------------------------------------------------------
# The opmodel.dev commit is the seventh input: the layouts, the site-owned
# pages, the floors and the build image. CI builds from a clean checkout; a
# local build with uncommitted edits is not reproducible from the record.
site_sha=$(git -C "$SITE" rev-parse --verify --quiet HEAD 2>/dev/null || true)
header="# version${TAB}label${TAB}weight${TAB}default${TAB}kind${TAB}repo${TAB}ref${TAB}sha${TAB}how${TAB}docs"
siteline=""; [ -z "$site_sha" ] || siteline="# site$TAB$site_sha$NL"
case "$manifest" in "$(dirname "$SITE")"/*) mshow=${manifest#"$(dirname "$SITE")"/} ;; *) mshow=$manifest ;; esac

# freeze: the resolved build as an anchored manifest, so nothing is re-derived:
# the floors, then every version with cli, catalog and opm explicit and
# library, core and opm-operator overridden. A row whose docs is a tag freezes
# by its tag name (tags are immutable), every other row by its SHA.
freeze() {
  printf '; generated by resolve-versions.sh from %s at opmodel.dev %s\n' "$mshow" "${site_sha:-unknown}"
  printf '; rebuild: check out opmodel.dev at that commit, copy this file outside site/.versions/,\n'
  printf '; then run OPM_VERSIONS_MANIFEST=<the copy> task build\n'
  for r in $REPOS; do printf '[repo "%s"]\n\tfloor = %s\n' "$r" "$(one "repo.$r.floor")"; done
  printf '%s' "$rows" | awk -F'\t' '
    function val() { return ($10 == "tag") ? $7 : $8 }
    !($1 in seen) { seen[$1]; order[++n] = $1; head[$1] = sprintf("[version \"%s\"]\n\tlabel = \"%s\"\n\tweight = %s\n\tdefault = %s\n", $1, $2, $3, $4) }
    $6 == "cli" { key[$1, "cli"] = val() }
    $6 == "catalog_opm" { key[$1, "catalog"] = val() }
    $6 == "opm" { key[$1, "opm"] = val() }
    $6 == "library" || $6 == "core" || $6 == "opm-operator" {
      why = "frozen from " $5
      if ($10 != "tag" && $7 != $8 && $7 != "main") why = why " " $7
      ov[$1, $6] = sprintf("\toverride = %s %s %s, docs %s\n", $6, val(), why, $10)
    }
    END {
      for (i = 1; i <= n; i++) {
        v = order[i]; printf "%s", head[v]
        printf "\tcli = %s\n\tcatalog = %s\n\topm = %s\n", key[v, "cli"], key[v, "catalog"], key[v, "opm"]
        printf "%s%s%s", ov[v, "library"], ov[v, "core"], ov[v, "opm-operator"]
      }
    }'
}

nvers=$(printf '%s' "$ordered" | grep -c .)
case "$mode" in
  check)
    printf '%s\n%s%s' "$header" "$siteline" "$rows"
    echo "resolve-versions: $nvers version(s) resolved from $manifest; nothing written" >&2
    exit 0 ;;
  freeze)
    freeze
    echo "resolve-versions: $nvers version(s) resolved from $manifest and frozen; nothing written" >&2
    exit 0 ;;
esac
mkdir -p "$(dirname "$OUT")"
printf '%s\n%s%s' "$header" "$siteline" "$rows" > "$OUT.tmp"
freeze > "$FROZEN.tmp"
mv "$OUT.tmp" "$OUT"
mv "$FROZEN.tmp" "$FROZEN"
echo "resolve-versions: $nvers version(s) from $manifest -> $OUT, $FROZEN"
