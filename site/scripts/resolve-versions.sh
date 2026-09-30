#!/bin/sh
# resolve-versions: the versions manifest (site/versions.conf) -> the refs and
# SHAs every site version documents. Host side: git cannot read a worktree's
# history inside the build container, so this runs before it (task
# versions:prepare). POSIX sh, git and awk.
#
#   resolve-versions.sh              resolve and check every version, then write
#                                    site/.versions/versions.tsv for the build; with
#                                    OPM_VERSIONS set (explicit mode) only remove a stale one
#   resolve-versions.sh --check      resolve and check every version, print the table, write nothing
#   resolve-versions.sh --pins REF   print the library, core and opm-operator refs that cli REF
#                                    pins; no docs/site or floor check
#
# Environment:
#   OPM_VERSIONS_MANIFEST  the manifest (default site/versions.conf)
#   OPM_VERSIONS           set by a caller that owns the version set (fixture builds)
#   OPM_WS, OPM_SRC_WORKTREE, OPM_SRC_<REPO>
#                          the source roots, resolved by run-in-image.sh exactly as for a build
#
# A version is either "source = main" (every root at its checked-out HEAD) or
# anchored: cli = <tag or SHA> is the anchor; library comes from cli go.mod,
# core from library opm/schema/loader.go DefaultSchemaModule, opm-operator from
# cli internal/operator/manifest.go PinnedOperatorVersion; catalog and opm are
# explicit. cli/hack/platform/ is a test fixture and never read. An override
# (<repo> <ref> <reason>) replaces one row. Every resolved ref must be a
# commit, hold docs/site and contain its repository's dialect floor.
#
# Failures print one line each, "<version>: <repo> <ref>: <reason>", all of
# them, and then the run exits 1.
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

usage() { sed -n '2,15p' "$0" >&2; exit 2; }
mode="write"; pinref=""
case "${1:-}" in
  "") ;;
  --check) mode=check ;;
  --pins) mode=pins; pinref=${2:-}; [ -n "$pinref" ] || usage ;;
  *) usage ;;
esac

manifest=${OPM_VERSIONS_MANIFEST:-$SITE/versions.conf}
case "$manifest" in /*) ;; *) manifest=$(pwd -P)/$manifest ;; esac

if [ "$mode" = write ] && [ -n "${OPM_VERSIONS:-}" ]; then
  rm -f "$OUT"
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

# --- Refs --------------------------------------------------------------------
# is_ref_text REF: the characters a tag or SHA may use here (the ref lands in
# TOML, JSON and URLs unquoted-safe).
is_ref_text() { case "$1" in ''|*[!A-Za-z0-9._/+-]*) return 1 ;; esac; }
is_sha() { printf '%s' "$1" | grep -Eq '^[0-9a-f]{40}$'; }
commit_of() { git -C "$1" rev-parse --verify --quiet "$2^{commit}" 2>/dev/null; }

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
# "<repo>\t<ref>\t<sha>\t<how>", or "!<line>" for a failure. OVERRIDES holds
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
    else echo "!$ver: library $lref: $lsha (pinned in cli go.mod at cli $cref); pin a release there, or add override = library <ref> <reason>"; lsha=""; fi
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
    else echo "!$ver: core $kref: $ksha (pinned in library opm/schema/loader.go at library $lref); add override = core <ref> <reason>"; fi
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
    else echo "!$ver: opm-operator $pref: $psha (pinned in cli internal/operator/manifest.go at cli $cref); add override = opm-operator <ref> <reason>"; fi
  else
    echo "!$ver: opm-operator (no pin): $pref (cli at $cref); add override = opm-operator <ref> <reason>"
  fi
}

if [ "$mode" = pins ]; then
  csha=$(anchor cli "$pinref") || csha=$(commit_of "$(root_of cli)" "$pinref") || {
    echo "cli $pinref: not a commit in $(root_of cli)" >&2; exit 1; }
  rows=$(resolve_pins "$pinref" "$csha" "pins" "")
  printf '# repo\tref\tsha\thow\ncli\t%s\t%s\tanchor\n' "$pinref" "$csha"
  printf '%s\n' "$rows" | grep -v '^!' || true
  if printf '%s\n' "$rows" | grep -q '^!'; then printf '%s\n' "$rows" | sed -n 's/^!//p' >&2; exit 1; fi
  exit 0
fi

# --- The manifest ------------------------------------------------------------
[ -f "$manifest" ] || { echo "resolve-versions: no manifest at $manifest" >&2; exit 1; }
cfg() { git config --file "$manifest" "$@"; }
keys=$(cfg --name-only --list) || { echo "resolve-versions: $manifest is not valid git-config syntax (see the line above)" >&2; exit 1; }
count() { cfg --null --get-all "$1" 2>/dev/null | tr -cd '\000' | wc -c | tr -d ' '; }
lines() { cfg --get-all "$1" 2>/dev/null | wc -l | tr -d ' '; }
# one KEY: the single value of KEY (empty when absent); a newline inside it counts as bad text.
one() { cfg --get "$1" 2>/dev/null || true; }
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
    version.label|version.weight|version.default|version.source|version.cli|version.catalog|version.opm|version.override)
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

[ -n "$versions" ] || err "$(basename "$manifest"): no [version \"...\"] section"
defaults=""; mains=""; weights=""
for v in $versions; do
  if ! printf '%s' "$v" | grep -Eq '^v[0-9]+\.[0-9]+$'; then err "version $v: the name is a URL segment and must be vN.N"; fi
  for k in label weight default source cli catalog opm; do
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
  s=$(one "version.$v.source")
  if [ "$(count "version.$v.source")" -gt 0 ]; then
    if [ "$s" != main ]; then err "version $v: source \"$s\": the only source is main"; fi
    mains="$mains $v"
    for k in cli catalog opm override; do
      if [ "$(count "version.$v.$k")" -gt 0 ]; then err "version $v: source = main excludes $k"; fi
    done
  else
    for k in cli catalog opm; do
      if [ "$(count "version.$v.$k")" -eq 0 ]; then err "version $v: $k is required unless source = main"; fi
    done
  fi
  seen=""
  ovals=$(cfg --get-all "version.$v.override" 2>/dev/null || true)
  if [ "$(lines "version.$v.override")" -ne "$(count "version.$v.override")" ]; then err "version $v: an override holds a line break"; fi
  while IFS= read -r o; do
    [ -n "$o" ] || continue
    orepo=${o%% *}; rest=${o#"$orepo"}; rest=${rest# }; oref=${rest%% *}; reason=${rest#"$oref"}; reason=${reason# }
    case " $REPOS " in *" $orepo "*) ;; *) err "version $v: override \"$o\": unknown repository $orepo"; continue ;; esac
    if [ "$orepo" = cli ]; then err "version $v: override \"$o\": cli is the anchor; set cli instead"; continue; fi
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

if [ -n "$errs" ]; then
  printf '%s' "$errs" >&2
  echo "resolve-versions: $manifest: $(printf '%s' "$errs" | grep -c .) problem(s)" >&2
  [ "$mode" = check ] || rm -f "$OUT"
  exit 1
fi

# --- Resolution and checks -----------------------------------------------------
# Every resolved ref: a commit, docs/site present, the floor an ancestor.
rows=""
row() { rows="$rows$1$TAB$2$TAB$3$TAB$4$TAB$5$TAB$6$TAB$7$TAB$8$TAB$9$NL"; }
check_ref() { # VERSION REPO REF SHA KIND
  root=$(root_of "$2"); floor=$(one "repo.$2.floor")
  if [ "$5" = main ]; then
    [ -d "$root/docs/site" ] || err "$1: $2 $3: no docs/site in $root"
  elif [ -z "$(git -C "$root" ls-tree -d --name-only "$4" docs/site 2>/dev/null)" ]; then
    err "$1: $2 $3: no docs/site at this ref"
  fi
  if git -C "$root" merge-base --is-ancestor "$floor" "$4" 2>/dev/null; then :
  else
    rc=$?
    if [ $rc -eq 1 ]; then err "$1: $2 $3: older than its floor $floor (the page-dialect merge); no ref before it builds"
    else err "$1: $2 $3: cannot compare with its floor $floor in $root"; fi
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
      row "$v" "$label" "$w" "$d" main "$r" main "$sha" head
    done
    continue
  fi
  ovr=$(cfg --get-all "version.$v.override" 2>/dev/null | awk '{ r = $1; f = $2; $1 = ""; $2 = ""; sub(/^ +/, ""); print r "\t" f "\t" $0 }' || true)
  ovref() { printf '%s\n' "$ovr" | awk -F'\t' -v r="$1" '$1 == r { print $2 "\t" $3 }'; }
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
    check_ref "$v" "$r" "$ref" "$sha" anchored
    row "$v" "$label" "$w" "$d" anchored "$r" "$ref" "$sha" "$how"
  done
  fails=$(printf '%s\n' "$derived" | sed -n 's/^!//p')
  [ -z "$fails" ] || errs="$errs$fails$NL"
done

if [ -n "$errs" ]; then
  printf '%s' "$errs" >&2
  echo "resolve-versions: $manifest: $(printf '%s' "$errs" | grep -c .) problem(s)" >&2
  [ "$mode" = check ] || rm -f "$OUT"
  exit 1
fi

header="# version${TAB}label${TAB}weight${TAB}default${TAB}kind${TAB}repo${TAB}ref${TAB}sha${TAB}how"
if [ "$mode" = check ]; then
  printf '%s\n%s' "$header" "$rows"
  echo "resolve-versions: $(printf '%s' "$ordered" | grep -c .) version(s) resolved from $manifest; nothing written" >&2
  exit 0
fi
mkdir -p "$(dirname "$OUT")"
printf '%s\n%s' "$header" "$rows" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
echo "resolve-versions: $(printf '%s' "$ordered" | grep -c .) version(s) from $manifest -> $OUT"
