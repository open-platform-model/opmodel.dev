#!/bin/sh
# Regression tests for site/scripts/resolve-versions.sh. Host side: POSIX sh
# and git, like the resolver. It builds six small git repositories (with
# go.mod, opm/schema/loader.go, internal/operator/manifest.go, docs/site/ and
# tags) under site/.check/versions-test/repos/, the only directory it removes
# and recreates, and never uses /tmp. Then:
#   - every resolver case of the fixture repositories as roots: the pin reads,
#     overrides, the anchor rule, pseudo-versions, docs/site, floors, the
#     manifest grammar and the two root checks;
#   - the line cases: the six repositories act as upstreams, and their
#     clones under repos/line/ are the roots, so refs/remotes/origin/* and the
#     tags exist exactly as in CI. The upstreams then move through states A to
#     E (release branches, a newer final, a branch past its line, a catalog
#     major, a branch that misses its release), and --fetch moves the clones:
#     the semver order, the pins (always read at the release tags), the docs
#     rules of all five released repositories, overrides in a line, the
#     stamp, the frozen round trip, the recovery to the frozen version block,
#     and the fetch under prune config, under a configured branch mapping and
#     against a conflicting upstream tag;
#   - the enhancements section ([section "enhancements"]): origin/main, a tag,
#     an override, the frozen block, and its grammar and root errors, on a
#     small enhancements repository and its clone;
#   - the pins at the real cli v1.0.0-alpha.25, a --check anchored there, a
#     line version cli-line = v1.0, catalog-line = opm-v4 checked against
#     git's own tag order, and its frozen version block resolved as an
#     anchored version, read from the caller's source roots
#     (OPM_SRC_WORKTREE=site-src ...).
# Every fixture tag is created once and never moved: these are test data, but
# the immutability rule holds here too. Each failing case asserts that the
# message names the version, the repository, and the ref and the rule where
# there is one. Prints "ok" or "FAIL" per case; exits 1 on any FAIL.
#
#   sh site/tests/versions/test-resolve.sh
set -eu
export LC_ALL=C
HERE=$(cd "$(dirname "$0")" && pwd -P)
SITE=$(cd "$HERE/../.." && pwd -P)
RESOLVE=$SITE/scripts/resolve-versions.sh
T=$SITE/.check/versions-test/repos
REPOS="opm core catalog_opm cli library opm-operator"
TAB=$(printf '\t')
pass=0; fail=0

# --- Fixture repositories -----------------------------------------------------
rm -rf "$T"
mkdir -p "$T/manifests"
gx() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -c user.name=opm-test -c user.email=opm-test@example.invalid \
    -c commit.gpgSign=false -c tag.gpgSign=false -c core.hooksPath=/dev/null "$@"; }
g() { d=$1; shift; gx -C "$d" "$@"; }
commit() { g "$1" add -A && g "$1" commit -q -m "$2" && g "$1" rev-parse HEAD; }
page() { mkdir -p "$1/docs/site"; printf -- '---\ntitle: %s\ndescription: A test page.\ntype: reference\n---\n' "$2" > "$1/docs/site/$2.md"; }
gomod() { printf 'module github.com/open-platform-model/cli\n\ngo 1.25\n\nrequire (\n\tgithub.com/open-platform-model/library %s\n\tgithub.com/spf13/cobra v1.10.1\n)\n%s' "$2" "${3:-}" > "$1/go.mod"; }
operator() { mkdir -p "$1/internal/operator"; printf 'package operator\n\n// PinnedOperatorVersion is the opm-operator release tag.\nconst PinnedOperatorVersion = "%s"\n' "$2" > "$1/internal/operator/manifest.go"; }
loader() { mkdir -p "$1/opm/schema"; printf 'package schema\n\n// DefaultSchemaModule is the core module.\nconst DefaultSchemaModule = "opmodel.dev/core@%s"\n\nfunc load() string { return DefaultSchemaModule }\n' "$2" > "$1/opm/schema/loader.go"; }

for r in $REPOS; do mkdir -p "$T/$r"; g "$T/$r" init -q -b main; done

# opm: before the floor, the floor, one later commit (the explicit ref).
page "$T/opm" old; commit "$T/opm" old > /dev/null
page "$T/opm" start; commit "$T/opm" "adopt the dialect" > /dev/null; g "$T/opm" tag dialect-floor
page "$T/opm" more; OPM_SHA=$(commit "$T/opm" more)

# core: v4.0.0 before the floor; v4.1.0 and v4.2.0 after it.
page "$T/core" old; commit "$T/core" old > /dev/null; g "$T/core" tag v4.0.0
page "$T/core" concepts; commit "$T/core" "adopt the dialect" > /dev/null; g "$T/core" tag dialect-floor
page "$T/core" a; commit "$T/core" a > /dev/null; g "$T/core" tag v4.1.0
page "$T/core" b; commit "$T/core" b > /dev/null; g "$T/core" tag v4.2.0

# catalog_opm: opm-v1.0.0 before the floor; opm-v1.1.0 and an unprefixed v9.9.9 after it.
page "$T/catalog_opm" old; commit "$T/catalog_opm" old > /dev/null; g "$T/catalog_opm" tag opm-v1.0.0
page "$T/catalog_opm" reference; commit "$T/catalog_opm" "adopt the dialect" > /dev/null; g "$T/catalog_opm" tag dialect-floor
page "$T/catalog_opm" a; commit "$T/catalog_opm" a > /dev/null; g "$T/catalog_opm" tag opm-v1.1.0; g "$T/catalog_opm" tag v9.9.9

# library: v2.0.0 before the floor; after it v2.1.0 (core v4.1.0), v2.3.0
# (core v4.2.0) and v2.4.0-major (core v4, a major only).
page "$T/library" old; loader "$T/library" v4.0.0; commit "$T/library" old > /dev/null; g "$T/library" tag v2.0.0
page "$T/library" embedding; commit "$T/library" "adopt the dialect" > /dev/null; g "$T/library" tag dialect-floor
loader "$T/library" v4.1.0; commit "$T/library" pin > /dev/null; g "$T/library" tag v2.1.0
loader "$T/library" v4.2.0; commit "$T/library" pin > /dev/null; g "$T/library" tag v2.3.0
loader "$T/library" v4; commit "$T/library" major > /dev/null; g "$T/library" tag v2.4.0-major
loader "$T/library" v4.2.0; commit "$T/library" restore > /dev/null

# opm-operator: v3.0.0 before docs/site and before the floor; v3.1.0 after
# it; v3.2.0-nodocs after it but without docs/site; HEAD has docs/site again.
printf 'operator\n' > "$T/opm-operator/README.md"; commit "$T/opm-operator" old > /dev/null; g "$T/opm-operator" tag v3.0.0
page "$T/opm-operator" operating; commit "$T/opm-operator" "adopt the dialect" > /dev/null; g "$T/opm-operator" tag dialect-floor
page "$T/opm-operator" a; commit "$T/opm-operator" a > /dev/null; g "$T/opm-operator" tag v3.1.0
g "$T/opm-operator" rm -q -r docs/site; commit "$T/opm-operator" "drop docs" > /dev/null; g "$T/opm-operator" tag v3.2.0-nodocs
page "$T/opm-operator" operating; commit "$T/opm-operator" "docs again" > /dev/null

# cli: v1.0.0-old before the floor; v1.1.0 (library v2.1.0, operator
# v3.1.0); v1.2.0-pseudo (a pseudo-version library pin); v1.3.0-replace (a
# replace for the library); the branch "feature".
page "$T/cli" old; gomod "$T/cli" v2.0.0; operator "$T/cli" v3.0.0; commit "$T/cli" old > /dev/null; g "$T/cli" tag v1.0.0-old
page "$T/cli" operating; commit "$T/cli" "adopt the dialect" > /dev/null; g "$T/cli" tag dialect-floor
gomod "$T/cli" v2.1.0; operator "$T/cli" v3.1.0; CLI_SHA=$(commit "$T/cli" pins); g "$T/cli" tag v1.1.0; g "$T/cli" branch feature
gomod "$T/cli" v2.1.1-0.20260930120000-0123456789ab; commit "$T/cli" pseudo > /dev/null; g "$T/cli" tag v1.2.0-pseudo
gomod "$T/cli" v2.1.0 'replace github.com/open-platform-model/library => ../library
'; commit "$T/cli" replace > /dev/null; g "$T/cli" tag v1.3.0-replace
gomod "$T/cli" v2.1.0; commit "$T/cli" restore > /dev/null

# The release lines, state A, before any case runs.
# core: v4.2.0-rc.0 on the pre-floor commit; a docs commit after v4.2.0, so
# main's head is not the tag.
g "$T/core" tag v4.2.0-rc.0 v4.0.0
page "$T/core" c; commit "$T/core" "docs after v4.2.0" > /dev/null
# catalog_opm: opm-v0.9.0 on the pre-floor commit; a docs commit after opm-v1.1.0.
g "$T/catalog_opm" tag opm-v0.9.0 opm-v1.0.0
page "$T/catalog_opm" b; commit "$T/catalog_opm" "docs after opm-v1.1.0" > /dev/null
# library: v2.2.0-oldcore, after the floor, pins core v4.2.0-rc.0; then the pin is restored.
loader "$T/library" v4.2.0-rc.0; commit "$T/library" oldcore > /dev/null; g "$T/library" tag v2.2.0-oldcore
loader "$T/library" v4.2.0; commit "$T/library" restore > /dev/null
# cli, the v1.5 line: v1.5.0-beta.2 and v1.5.0-beta.10 (library v2.3.0,
# operator v3.1.0); v1.5.0-beta.3 (library v2.1.0), lower by semver but cut
# later; the decoy v1.50.0; v1.6.0 (library v2.2.0-oldcore, operator v3.1.0);
# then the pins are restored (library v2.1.0).
gomod "$T/cli" v2.3.0; operator "$T/cli" v3.1.0; commit "$T/cli" beta2 > /dev/null; g "$T/cli" tag v1.5.0-beta.2
page "$T/cli" beta10; commit "$T/cli" beta10 > /dev/null; g "$T/cli" tag v1.5.0-beta.10
gomod "$T/cli" v2.1.0; commit "$T/cli" beta3 > /dev/null; g "$T/cli" tag v1.5.0-beta.3
page "$T/cli" decoy; commit "$T/cli" decoy > /dev/null; g "$T/cli" tag v1.50.0
gomod "$T/cli" v2.2.0-oldcore; commit "$T/cli" oldcore > /dev/null; g "$T/cli" tag v1.6.0
gomod "$T/cli" v2.1.0; commit "$T/cli" restore > /dev/null
# then main moves its library pin past every v1.5 and v1.50 tag, so a line
# whose docs come from main's head still reads its pins at the tag.
gomod "$T/cli" v2.3.0; commit "$T/cli" "main pins library v2.3.0" > /dev/null

# enhancements: an upstream with two commits holding INDEX.md (the first
# tagged), and a commit without it; enh/ is its clone, the root of the
# section cases, so refs/remotes/origin/main exists as in CI.
mkdir -p "$T/enh-up"; g "$T/enh-up" init -q -b main
printf '# Index\n' > "$T/enh-up/INDEX.md"; ENH_OLD=$(commit "$T/enh-up" "index"); g "$T/enh-up" tag enh-v1
printf '# Index\n\nMore.\n' > "$T/enh-up/INDEX.md"; ENH_SHA=$(commit "$T/enh-up" "more")
g "$T/enh-up" switch -q -c bare; g "$T/enh-up" rm -q INDEX.md; printf 'x\n' > "$T/enh-up/README.md"; ENH_BARE=$(commit "$T/enh-up" "no index"); g "$T/enh-up" switch -q main
gx clone -q "$T/enh-up" "$T/enh"

# A docs/site tree inside another repository (this worktree), like A's
# fixture workspace: not its own git top level.
mkdir -p "$T/inside/opm"; page "$T/inside/opm" start

# --- Cases ------------------------------------------------------------------------
floors() {
  for r in $REPOS; do
    f=$(g "$T/$r" rev-parse dialect-floor)
    printf '[repo "%s"]\n\tfloor = %s\n' "$r" "$f"
  done
}
# manifest NAME BODY: the six floors plus BODY, as manifests/NAME.conf.
manifest() { { floors; printf '%s\n' "$2"; } > "$T/manifests/$1.conf"; echo "$T/manifests/$1.conf"; }
# run MANIFEST ENV... -- ARGS: the resolver on the fixture roots under $R (the
# repositories themselves, or their clones under line/); output in $out,
# status in $rc.
R=$T
fixture_env() { echo "OPM_SRC_OPM=$R/opm OPM_SRC_CORE=$R/core OPM_SRC_CATALOG_OPM=$R/catalog_opm OPM_SRC_CLI=$R/cli OPM_SRC_LIBRARY=$R/library OPM_SRC_OPM_OPERATOR=$R/opm-operator OPM_SRC_ENHANCEMENTS=$T/enh OPM_VERSIONS="; }
run() { # MANIFEST [EXTRA ENV...] -- resolver args
  m=$1; shift; extra=""
  while [ $# -gt 0 ] && [ "$1" != -- ]; do extra="$extra $1"; shift; done
  [ $# -eq 0 ] || shift
  # shellcheck disable=SC2046,SC2086 # env assignments hold no spaces
  out=$(env $(fixture_env) $extra OPM_VERSIONS_MANIFEST="$m" sh "$RESOLVE" "$@" 2>&1) && rc=0 || rc=$?
}
ok() { echo "ok   $1: $2"; pass=$((pass + 1)); }
bad() { echo "FAIL $1: $2"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/     | /'; fail=$((fail + 1)); }
# expect NAME WANT_RC SUMMARY PATTERN...: every PATTERN (fixed text) in the output.
expect() {
  name=$1; want=$2; what=$3; shift 3; why=""
  [ "$rc" = "$want" ] || why="exit $rc, want $want"
  for p in "$@"; do printf '%s\n' "$out" | grep -qF -- "$p" || why="${why:+$why; }missing: $p"; done
  if [ -z "$why" ]; then ok "$name" "$what"; else bad "$name" "$why"; fi
}

v='[version "v2.0"]
	label = v2.0 (test)
	weight = 1
	default = true'
good="$v
	cli = v1.1.0
	catalog = opm-v1.1.0
	opm = $OPM_SHA"

run "$(manifest pins "$good")" -- --check
expect pins 0 "library from cli go.mod, core from library DefaultSchemaModule, opm-operator from cli PinnedOperatorVersion" \
  "v2.0${TAB}v2.0 (test)${TAB}1${TAB}true${TAB}anchored${TAB}cli${TAB}v1.1.0${TAB}$CLI_SHA${TAB}anchor" \
  "${TAB}library${TAB}v2.1.0${TAB}$(g "$T/library" rev-parse v2.1.0)${TAB}pin:cli go.mod" \
  "${TAB}core${TAB}v4.1.0${TAB}$(g "$T/core" rev-parse v4.1.0)${TAB}pin:library opm/schema/loader.go" \
  "${TAB}opm-operator${TAB}v3.1.0${TAB}$(g "$T/opm-operator" rev-parse v3.1.0)${TAB}pin:cli internal/operator/manifest.go" \
  "${TAB}catalog_opm${TAB}opm-v1.1.0${TAB}$(g "$T/catalog_opm" rev-parse opm-v1.1.0)${TAB}explicit" \
  "${TAB}opm${TAB}$OPM_SHA${TAB}$OPM_SHA${TAB}explicit"

run "$(manifest pins-flag "$good")" -- --pins v1.1.0
expect pins-flag 0 "--pins v1.1.0 prints library v2.1.0, core v4.1.0, opm-operator v3.1.0" \
  "library${TAB}v2.1.0${TAB}" "core${TAB}v4.1.0${TAB}" "opm-operator${TAB}v3.1.0${TAB}"

# from-bundles (openspec pull-reference-bundles): the repositories a version
# reads from docs bundles get no row, and versions.tsv mirrors the set.
FBL="# from-bundles${TAB}v2.0${TAB}"
run "$(manifest fb-core "$good
	from-bundles = core")" -- --check
if [ "$rc" = 0 ] && ! printf '%s\n' "$out" | grep -q "^v2.0${TAB}.*${TAB}core${TAB}"; then
  expect fb-core 0 "from-bundles = core: no core row, the mirror line; the cli pins still resolve library and opm-operator" \
    "${FBL}core" "${TAB}library${TAB}v2.1.0${TAB}" "${TAB}opm-operator${TAB}v3.1.0${TAB}"
else bad fb-core "exit $rc, or a core row is left"; fi
fbcli="$v
	from-bundles = cli core library opm-operator
	catalog = opm-v1.1.0
	opm = $OPM_SHA"
run "$(manifest fb-cli "$fbcli")" -- --check
if [ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | grep -c "^v2.0${TAB}")" = 2 ]; then
  expect fb-cli 0 "from-bundles naming cli and its pins: no cli anchor, only catalog_opm and opm resolve" \
    "${FBL}cli core library opm-operator" "${TAB}anchored${TAB}catalog_opm${TAB}opm-v1.1.0${TAB}" "${TAB}anchored${TAB}opm${TAB}$OPM_SHA${TAB}"
else bad fb-cli "exit $rc, or rows other than catalog_opm and opm"; fi
# shellcheck disable=SC2046 # env assignments hold no spaces
env $(fixture_env) OPM_VERSIONS_MANIFEST="$T/manifests/fb-cli.conf" sh "$RESOLVE" --freeze > "$T/manifests/fb-cli-frozen.conf" 2>/dev/null
run "$T/manifests/fb-cli-frozen.conf" -- --check
if [ "$rc" = 0 ] && grep -qx '	from-bundles = cli core library opm-operator' "$T/manifests/fb-cli-frozen.conf" && ! grep -q '	cli = ' "$T/manifests/fb-cli-frozen.conf"; then
  expect fb-cli-freeze 0 "the frozen copy keeps from-bundles, names no cli and resolves the same two rows" "${FBL}cli core library opm-operator" "${TAB}catalog_opm${TAB}opm-v1.1.0${TAB}"
else bad fb-cli-freeze "exit $rc, or the frozen copy lost from-bundles or names a cli"; fi
run "$(manifest fb-cli-anchor "$fbcli
	cli = v1.1.0")" -- --check
expect fb-cli-anchor 1 "from-bundles naming cli refuses a cli anchor" "version v2.0: from-bundles names cli, which excludes cli"
run "$(manifest fb-cli-partial "$v
	from-bundles = cli core
	catalog = opm-v1.1.0
	opm = $OPM_SHA")" -- --check
expect fb-cli-partial 1 "from-bundles naming cli must name its pins too" "version v2.0: from-bundles names cli but not library" "version v2.0: from-bundles names cli but not opm-operator"
run "$(manifest fb-unknown "$good
	from-bundles = enhancements")" -- --check
expect fb-unknown 1 "from-bundles names only the docs-bundle repositories" "version v2.0: from-bundles names enhancements; only cli, core, library, opm-operator and opm publish docs bundles"
# opm from its bundle (openspec serve-docs-from-bundles): no opm key, no opm row.
run "$(manifest fb-opm "$v
	cli = v1.1.0
	catalog = opm-v1.1.0
	from-bundles = opm")" -- --check
if [ "$rc" = 0 ] && ! printf '%s\n' "$out" | grep -q "^v2.0${TAB}.*${TAB}opm${TAB}"; then
  expect fb-opm 0 "from-bundles = opm: no opm key and no opm row; cli and its pins and catalog_opm resolve" \
    "${FBL}opm" "${TAB}cli${TAB}v1.1.0${TAB}" "${TAB}catalog_opm${TAB}opm-v1.1.0${TAB}"
else bad fb-opm "exit $rc, or an opm row is left"; fi
# shellcheck disable=SC2046 # env assignments hold no spaces
env $(fixture_env) OPM_VERSIONS_MANIFEST="$T/manifests/fb-opm.conf" sh "$RESOLVE" --freeze > "$T/manifests/fb-opm-frozen.conf" 2>/dev/null
run "$T/manifests/fb-opm-frozen.conf" -- --check
if [ "$rc" = 0 ] && ! grep -q '	opm = ' "$T/manifests/fb-opm-frozen.conf"; then
  expect fb-opm-freeze 0 "the frozen copy of a version reading opm from its bundle names no opm" "${FBL}opm"
else bad fb-opm-freeze "exit $rc, or the frozen copy names an opm"; fi
run "$(manifest fb-opm-key "$good
	from-bundles = opm")" -- --check
expect fb-opm-key 1 "from-bundles naming opm refuses an opm key" "version v2.0: from-bundles names opm, which excludes opm"
run "$(manifest fb-override "$good
	from-bundles = core
	override = core v4.2.0 a test")" -- --check
expect fb-override 1 "a repository read from its bundle takes no override" "version v2.0: override \"core v4.2.0 a test\": from-bundles names core"

run "$(manifest main "[version \"v1.0\"]
	label = v1.0 (beta)
	weight = 1
	default = true
	source = main
[version \"v2.0\"]
	label = v2.0 (test)
	weight = 2
	cli = v1.1.0
	catalog = opm-v1.1.0
	opm = $OPM_SHA")" -- --check
expect main 0 "source = main records every root's HEAD; versions in weight order" \
  "v1.0${TAB}v1.0 (beta)${TAB}1${TAB}true${TAB}main${TAB}cli${TAB}main${TAB}$(g "$T/cli" rev-parse HEAD)${TAB}head" \
  "v2.0${TAB}v2.0 (test)${TAB}2${TAB}false${TAB}anchored${TAB}cli${TAB}v1.1.0"

run "$(manifest override "$good
	override = library v2.3.0 the pinned library predates a page
	override = opm-operator $(g "$T/opm-operator" rev-parse v3.1.0) test pins a SHA")" -- --check
expect override 0 "an override replaces a row and moves where core is read (library v2.3.0 pins core v4.2.0)" \
  "${TAB}library${TAB}v2.3.0${TAB}$(g "$T/library" rev-parse v2.3.0)${TAB}override:the pinned library predates a page" \
  "${TAB}core${TAB}v4.2.0${TAB}$(g "$T/core" rev-parse v4.2.0)${TAB}pin:library opm/schema/loader.go" \
  "${TAB}opm-operator${TAB}$(g "$T/opm-operator" rev-parse v3.1.0)${TAB}$(g "$T/opm-operator" rev-parse v3.1.0)${TAB}override:test pins a SHA"

run "$(manifest override-no-reason "$good
	override = core v4.2.0")" -- --check
expect override-no-reason 1 "an override without a reason fails, naming the repository and the ref" "override core v4.2.0" "the reason is required"

run "$(manifest no-catalog "$v
	cli = v1.1.0
	opm = $OPM_SHA")" -- --check
expect no-catalog 1 "a missing catalog fails" "version v2.0: catalog is required"

run "$(manifest no-opm "$v
	cli = v1.1.0
	catalog = opm-v1.1.0")" -- --check
expect no-opm 1 "a missing opm fails" "version v2.0: opm is required"

for a in main feature 'v1.*' "$(printf '%.7s' "$CLI_SHA")" HEAD; do
  run "$(manifest anchor "$v
	cli = $a
	catalog = opm-v1.1.0
	opm = $OPM_SHA")" -- --check
  expect "anchor-$a" 1 "cli = $a is refused: an anchor is a tag or a full SHA" "v2.0: cli $a: " "a tag or a full"
done

run "$(manifest catalog-prefix "$v
	cli = v1.1.0
	catalog = v9.9.9
	opm = $OPM_SHA")" -- --check
expect catalog-prefix 1 "a catalog tag without its opm-v prefix fails" "v2.0: catalog_opm v9.9.9: a catalog tag is opm-v*"

run "$(manifest pseudo "$v
	cli = v1.2.0-pseudo
	catalog = opm-v1.1.0
	opm = $OPM_SHA")" -- --check
expect pseudo 1 "a pseudo-version pin fails, naming the repository, the file and the anchor" \
  "v2.0: library v2.1.1-0.20260930120000-0123456789ab: a Go pseudo-version" "cli go.mod at cli v1.2.0-pseudo"

run "$(manifest replace "$v
	cli = v1.3.0-replace
	catalog = opm-v1.1.0
	opm = $OPM_SHA")" -- --check
expect replace 1 "a replace for the library in go.mod fails" "v2.0: library (no pin): go.mod replaces github.com/open-platform-model/library (cli go.mod at cli v1.3.0-replace)"

run "$(manifest major "$good
	override = library v2.4.0-major test the major-only pin")" -- --check
expect major 1 "a DefaultSchemaModule with only a major fails" "v2.0: core v4: DefaultSchemaModule names only a major" "at library v2.4.0-major"

run "$(manifest no-docs "$good
	override = opm-operator v3.2.0-nodocs test a ref without docs")" -- --check
expect no-docs 1 "a ref without docs/site fails, naming the repository and the ref" "v2.0: opm-operator v3.2.0-nodocs: no docs/site at this ref"

run "$(manifest floor "$v
	cli = v1.0.0-old
	catalog = opm-v1.1.0
	opm = $OPM_SHA")" -- --check
expect floor 1 "a ref older than its floor fails, naming the repository and the ref" \
  "v2.0: cli v1.0.0-old: older than its floor $(g "$T/cli" rev-parse dialect-floor)" "v2.0: library v2.0.0: older than its floor" "v2.0: opm-operator v3.0.0: no docs/site"

run "$(manifest unknown-key "$good
	colour = red")" -- --check
expect unknown-key 1 "an unknown key fails, naming the key" 'unknown key "version.v2.0.colour"'

run "$(manifest unknown-repo "$good
[repo \"docs\"]
	floor = $(g "$T/opm" rev-parse dialect-floor)")" -- --check
expect unknown-repo 1 "an unknown repository fails, naming it" 'unknown key "repo.docs.floor"'

run "$(manifest two-defaults "$good
[version \"v1.0\"]
	label = v1.0 (beta)
	weight = 2
	default = true
	source = main")" -- --check
expect two-defaults 1 "two defaults fail" "exactly one version is the default" "v2.0 v1.0"

run "$(manifest two-mains "[version \"v1.0\"]
	label = v1.0 (beta)
	weight = 1
	default = true
	source = main
[version \"v1.1\"]
	label = v1.1
	weight = 2
	source = main")" -- --check
expect two-mains 1 "two source = main versions fail" "at most one version has source = main" "v1.0 v1.1"

run "$(manifest bad-name "[version \"latest\"]
	label = latest
	weight = 1
	default = true
	source = main")" -- --check
expect bad-name 1 "a version name that is not vN.N fails" "version latest: the name is a URL segment and must be vN.N"

run "$(manifest weight "$good
[version \"v1.0\"]
	label = v1.0 (beta)
	weight = 1
	source = main")" -- --check
expect weight 1 "a duplicate weight fails" "version v1.0: weight 1 is taken"

for c in tab:'"a\tb"' quote:"it's" dquote:'a\"b' backslash:'a\\b'; do
  run "$(manifest label "[version \"v1.0\"]
	label = ${c#*:}
	weight = 1
	default = true
	source = main")" -- --check
  expect "label-${c%%:*}" 1 "a label holding a ${c%%:*} fails" "version v1.0: label" "holds a tab"
done
for c in quote:"it's pinned" backslash:'a\\b'; do
  run "$(manifest reason "$good
	override = core v4.2.0 ${c#*:}")" -- --check
  expect "reason-${c%%:*}" 1 "an override reason holding a ${c%%:*} fails, naming the repository" "version v2.0: override core v4.2.0: the reason holds"
done

run "$(manifest root-missing "$good")" OPM_SRC_CORE="$T/nope" -- --check
expect root-missing 1 "a missing root fails before any ref, naming OPM_SRC_CORE" "OPM_SRC_CORE: $T/nope has no docs/site"

run "$(manifest root-fixture "$good")" OPM_SRC_OPM="$T/inside/opm" -- --check
expect root-fixture 1 "a root inside another repository fails, naming OPM_SRC_OPM and explicit mode" \
  "opm: root $T/inside/opm: not its own git top level" "set OPM_SRC_OPM" "OPM_VERSIONS=v1.0=/src"

# --- The enhancements section -------------------------------------------------------
sec() { printf '%s\n[section "%s"]\n\t%s\n' "$good" "${2:-enhancements}" "$1"; }
run "$(manifest enh-main "$(sec 'ref = origin/main')")" -- --check
expect enh-main 0 "ref = origin/main resolves the remote-tracking ref into the # section line" \
  "# section${TAB}enhancements${TAB}origin/main${TAB}$ENH_SHA${TAB}ref origin/main"
run "$(manifest enh-tag "$(sec 'ref = enh-v1')")" -- --check
expect enh-tag 0 "ref = a tag resolves the tag" "# section${TAB}enhancements${TAB}enh-v1${TAB}$ENH_OLD${TAB}ref enh-v1"
run "$(manifest enh-override "$(sec "ref = origin/main
	override = $ENH_OLD the newest commit breaks the build")")" -- --check
expect enh-override 0 "an override pins its SHA, naming its reason and the ref it replaces" \
  "# section${TAB}enhancements${TAB}origin/main${TAB}$ENH_OLD${TAB}override:the newest commit breaks the build; replaces origin/main $(printf '%.7s' "$ENH_SHA")"
run "$(manifest enh-freeze "$(sec 'ref = origin/main')")" -- --freeze
expect enh-freeze 0 "the frozen manifest pins the section at its SHA" "[section \"enhancements\"]" "ref = $ENH_SHA"
run "$(manifest enh-local "$(sec 'ref = main')")" -- --check
expect enh-local 1 "a local branch is refused, naming the section and the ref" \
  "section enhancements main: not origin/<branch>, a tag or a full SHA"
run "$(manifest enh-no-index "$(sec "ref = $ENH_BARE")")" -- --check
expect enh-no-index 1 "a commit without INDEX.md fails" "section enhancements $ENH_BARE ($(printf '%.7s' "$ENH_BARE")): no INDEX.md at this commit"
run "$(manifest enh-no-reason "$(sec "ref = origin/main
	override = $ENH_OLD")")" -- --check
expect enh-no-reason 1 "an override without a reason fails" "section enhancements: override" "the reason is required"
run "$(manifest enh-two-refs "$(sec "ref = origin/main
	ref = enh-v1")")" -- --check
expect enh-two-refs 1 "two refs fail" "section enhancements: exactly one ref is required (2 found)"
run "$(manifest enh-unknown "$(sec 'ref = origin/main' docs)")" -- --check
expect enh-unknown 1 "a section other than enhancements fails, naming the key" 'unknown key "section.docs.ref" (the only section is enhancements)'
run "$(manifest enh-no-root "$(sec 'ref = origin/main')")" OPM_SRC_ENHANCEMENTS="$T/nope" -- --check
expect enh-no-root 1 "a missing root fails, naming OPM_SRC_ENHANCEMENTS" "section enhancements: no enhancements root" "set OPM_SRC_ENHANCEMENTS"
run "$(manifest enh-none "$good")" -- --check
rc_none=$rc
if [ "$rc_none" = 0 ] && ! printf '%s\n' "$out" | grep -q '^# section'; then ok enh-none "a manifest without the stanza has no section"
else bad enh-none "exit $rc_none, or a # section line without the stanza"; fi

# --- Line versions: the repositories above are the upstreams ----------------------
# Their clones under line/ are the roots, so refs/remotes/origin/* and the tags
# exist exactly as in CI. A later state changes an upstream, and --fetch moves
# the clones. Upstream branches are made with git switch -c, then git switch main.
rev() { g "$T/$1" rev-parse "$2"; }
short() { printf '%.7s' "$1"; }
SITE_SHA=$(git -C "$SITE" rev-parse HEAD)
mkdir -p "$T/line"
for r in $REPOS; do gx clone -q "$T/$r" "$T/line/$r"; done
R=$T/line
lv="$v"
lgood="$lv
	cli-line = v1.5
	catalog-line = opm-v1"
L="v2.0${TAB}v2.0 (test)${TAB}1${TAB}true${TAB}line${TAB}"
CORE_HOW="pin:library opm/schema/loader.go"
CORE_A=$(rev core main); CAT_A=$(rev catalog_opm main); OPM_HEAD=$(rev opm main)

# State A.
run "$(manifest line "$lgood")" -- --check
expect line 0 "cli v1.5.0-beta.10 beats beta.3 and beta.2, ignores v1.50.0 and v1.6.0; the pins; catalog opm-v1.1.0; core and catalog docs from main; opm main" \
  "# site${TAB}$SITE_SHA" \
  "${L}cli${TAB}v1.5.0-beta.10${TAB}$(rev cli v1.5.0-beta.10)${TAB}line:newest v1.5.* tag; docs: v1.5.0-beta.10 (main is past v1.5, no release/v1.5)${TAB}tag" \
  "${L}library${TAB}v2.3.0${TAB}$(rev library v2.3.0)${TAB}pin:cli go.mod; docs: v2.3.0 (main is past v2.3, no release/v2.3)${TAB}tag" \
  "${L}opm-operator${TAB}v3.1.0${TAB}$(rev opm-operator v3.1.0)${TAB}pin:cli internal/operator/manifest.go; docs: v3.1.0 (main is past v3.1, no release/v3.1)${TAB}tag" \
  "${L}core${TAB}v4.2.0${TAB}$CORE_A${TAB}$CORE_HOW; docs: main head (no release/v4.2; main still releases v4.2)${TAB}main" \
  "${L}catalog_opm${TAB}opm-v1.1.0${TAB}$CAT_A${TAB}line:newest opm-v1.* tag; docs: main head (no release/opm-v1.1; main still releases opm-v1.1)${TAB}main" \
  "${L}opm${TAB}main${TAB}$OPM_HEAD${TAB}line:main head${TAB}main"

# A line version that reads cli and its pins from docs bundles: catalog-line
# and from-bundles, no cli-line; only catalog_opm and opm resolve.
run "$(manifest line-fb "$lv
	catalog-line = opm-v1
	from-bundles = cli core library opm-operator")" -- --check
if [ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | grep -c "^v2.0${TAB}")" = 2 ]; then
  expect line-fb 0 "catalog-line with from-bundles naming cli: a line version of catalog_opm and opm only" \
    "# from-bundles${TAB}v2.0${TAB}cli core library opm-operator" \
    "${L}catalog_opm${TAB}opm-v1.1.0${TAB}$CAT_A${TAB}" "${L}opm${TAB}main${TAB}$OPM_HEAD${TAB}line:main head${TAB}main"
else bad line-fb "exit $rc, or rows other than catalog_opm and opm"; fi
run "$(manifest line-fb-opm "$lv
	catalog-line = opm-v1
	from-bundles = cli core library opm-operator opm")" -- --check
if [ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | grep -c "^v2.0${TAB}")" = 1 ]; then
  expect line-fb-opm 0 "a line version reading opm from its bundle resolves catalog_opm only, never opm's main" \
    "# from-bundles${TAB}v2.0${TAB}cli core library opm-operator opm" "${L}catalog_opm${TAB}opm-v1.1.0${TAB}$CAT_A${TAB}"
else bad line-fb-opm "exit $rc, or rows other than catalog_opm"; fi
run "$(manifest line-fb-cli-line "$lgood
	from-bundles = cli core library opm-operator")" -- --check
expect line-fb-cli-line 1 "from-bundles naming cli and cli-line together are refused" "version v2.0: from-bundles names cli, which excludes cli-line"

# cli v1.50.0 is the newest release on cli main, so main still releases v1.50:
# the cli docs come from main's head, while the pins are read at the tag
# (library v2.1.0, not main's v2.3.0).
LV150=$(manifest line-cli-main "$lv
	cli-line = v1.50
	catalog-line = opm-v1")
run "$LV150" -- --check
expect line-cli-main 0 "cli docs from main's head while main still releases the cli line; the pins still come from the tag" \
  "${L}cli${TAB}v1.50.0${TAB}$(rev cli main)${TAB}line:newest v1.50.* tag; docs: main head (no release/v1.50; main still releases v1.50)${TAB}main" \
  "${L}library${TAB}v2.1.0${TAB}$(rev library v2.1.0)${TAB}pin:cli go.mod; docs: v2.1.0 (main is past v2.1, no release/v2.1)${TAB}tag"
# shellcheck disable=SC2046 # env assignments hold no spaces
env $(fixture_env) OPM_VERSIONS_MANIFEST="$LV150" sh "$RESOLVE" --freeze > "$T/manifests/frozen-cli-main.conf" 2>/dev/null
out=$(cat "$T/manifests/frozen-cli-main.conf"); rc=0
expect line-cli-freeze 0 "a cli whose docs come from main's head freezes by that SHA, with a comment naming the release" \
  "	; cli v1.50.0, docs main" "	cli = $(rev cli main)"
run "$T/manifests/frozen-cli-main.conf" -- --check
expect line-cli-freeze-check 0 "that frozen copy resolves anchored at main's head; the library override keeps its tag" \
  "v2.0${TAB}v2.0 (test)${TAB}1${TAB}true${TAB}anchored${TAB}cli${TAB}$(rev cli main)${TAB}$(rev cli main)${TAB}anchor${TAB}sha" \
  "${TAB}library${TAB}v2.1.0${TAB}$(rev library v2.1.0)${TAB}override:frozen from line, docs tag${TAB}tag"
# Freezing that anchored copy again names no release: its cli is a SHA, not a line.
run "$T/manifests/frozen-cli-main.conf" -- --freeze
if [ "$rc" = 0 ] && ! printf '%s\n' "$out" | grep -qE "^${TAB}; cli [0-9a-f]{40}, docs sha"; then
  ok line-cli-refreeze "freezing a frozen copy again writes no cli release comment for its anchored cli"
else bad line-cli-refreeze "exit $rc, or a '; cli <sha>, docs sha' comment"; fi

run "$(manifest line-override-1 "$lv
	cli-line = v1.2
	catalog-line = opm-v1
	override = library v2.3.0 the v1.2 line pins a pseudo-version")" -- --check
expect line-override-1 0 "an override replaces a failing pseudo-version pin; core follows the overridden library; how names the replaced row" \
  "${L}library${TAB}v2.3.0${TAB}$(rev library v2.3.0)${TAB}override:the v1.2 line pins a pseudo-version; replaces v2.1.1-0.20260930120000-0123456789ab (pin:cli go.mod)${TAB}tag" \
  "${L}core${TAB}v4.2.0${TAB}$CORE_A${TAB}$CORE_HOW; docs: main head"
run "$(manifest line-override-2 "$lv
	cli-line = v1.2
	catalog-line = opm-v1
	override = library v2.4.0-major the v1.2 line pins a pseudo-version
	override = core $(rev core v4.2.0) the library names only a major")" -- --check
expect line-override-2 0 "a core override names the tree: docs sha, no containment; it replaces no pin" \
  "${L}core${TAB}$(rev core v4.2.0)${TAB}$(rev core v4.2.0)${TAB}override:the library names only a major; replaces no pin${TAB}sha" \
  "${L}library${TAB}v2.4.0-major${TAB}"
run "$(manifest line-override-3 "$lv
	cli-line = v1.5
	catalog-line = opm-v0
	override = catalog_opm opm-v1.1.0 the opm-v0 line predates the floor")" -- --check
expect line-override-3 0 "a catalog override of a pre-floor line: docs tag; it names the replaced row" \
  "${L}catalog_opm${TAB}opm-v1.1.0${TAB}$(rev catalog_opm opm-v1.1.0)${TAB}override:the opm-v0 line predates the floor; replaces opm-v0.9.0 (line:newest opm-v0.* tag)${TAB}tag"

run "$(manifest line-override-stale "$lgood
	override = opm-operator v3.1.0 the pin was a pseudo-version
	override = opm $(rev opm dialect-floor) main had no docs")" -- --check
expect line-override-stale 1 "an override whose replaced row passes every check fails as no longer needed, opm included" \
  "v2.0: opm-operator override v3.1.0 (the pin was a pseudo-version): no longer needed: the line resolves v3.1.0 (pin:cli internal/operator/manifest.go), which passes every check; remove the override" \
  "v2.0: opm override $(rev opm dialect-floor) (main had no docs): no longer needed: the line resolves main $(short "$OPM_HEAD") (line:main head)"

run "$(manifest line-core-pre-floor "$lv
	cli-line = v1.6
	catalog-line = opm-v1")" -- --check
expect line-core-pre-floor 1 "core v4.2.0-rc.0, pinned by library v2.2.0-oldcore, is older than its floor though its docs (main) are not" \
  "v2.0: core v4.2.0-rc.0 (the release the stamp names, pinned by library v2.2.0-oldcore; docs main head): older than its floor $(rev core dialect-floor)"

run "$(manifest line-pre-floor "$lv
	cli-line = v1.0
	catalog-line = opm-v1")" -- --check
expect line-pre-floor 1 "the newest tag of a line older than its floor fails, naming the rule" \
  "v2.0: cli v1.0.0-old (newest tag of line v1.0; docs its tag): older than its floor $(rev cli dialect-floor)"

run "$(manifest line-no-tag "$lv
	cli-line = v9.9
	catalog-line = opm-v9")" -- --check
expect line-no-tag 1 "a line without a tag fails, naming the line and task versions:fetch" \
  "v2.0: cli line v9.9: no tag v9.9.<patch>[-<pre>] in $R/cli; fetch its tags (task versions:fetch)" \
  "v2.0: catalog_opm line opm-v9: no tag opm-v9.<minor>.<patch>[-<pre>] in $R/catalog_opm; fetch its tags (task versions:fetch)"

for c in \
  "with-cli|	cli = v1.5.0-beta.10|version v2.0: cli-line excludes cli" \
  "with-source|	source = main|version v2.0: source = main excludes cli-line" \
  "no-catalog-line|-|version v2.0: cli-line needs catalog-line = opm-vN" \
  "cli-minor|	cli-line = 1.5|version v2.0: cli-line \"1.5\": not a cli minor line vX.Y" \
  "catalog-v1|	catalog-line = v1|version v2.0: catalog-line \"v1\": not an opm catalog major opm-vN" \
  "catalog-minor|	catalog-line = opm-v4.4|version v2.0: catalog-line \"opm-v4.4\": a minor; the catalog line is the opm catalog major (opm-v4)" \
  "catalog-k8s|	catalog-line = k8s-v1|version v2.0: catalog-line \"k8s-v1\": not an opm catalog major opm-vN"; do
  name=${c%%|*}; rest=${c#*|}; extra=${rest%%|*}; want=${rest#*|}
  case "$name" in
    no-catalog-line) body="$lv
	cli-line = v1.5" ;;
    cli-minor) body="$lv
	catalog-line = opm-v1
$extra" ;;
    catalog-*) body="$lv
	cli-line = v1.5
$extra" ;;
    *) body="$lgood
$extra" ;;
  esac
  run "$(manifest "line-grammar-$name" "$body")" -- --check
  expect "line-grammar-$name" 1 "a grammar error is named: $name" "$want"
done
run "$(manifest line-grammar-anchored "$good
	catalog-line = opm-v1")" -- --check
expect line-grammar-anchored 1 "catalog-line in an anchored version fails" "version v2.0: catalog-line needs cli-line"

gx clone -q --depth 1 "file://$T/opm" "$T/shallow-opm"
run "$(manifest line-shallow "$lgood")" OPM_SRC_OPM="$T/shallow-opm" -- --check
expect line-shallow 1 "a shallow root fails, named" \
  "v2.0: opm: root $T/shallow-opm: a shallow clone; a line version needs full history and tags (fetch-depth: 0)"

R=$T
run "$(manifest line-no-origin "$lgood")" -- --check
expect line-no-origin 1 "a root without refs/remotes/origin/main fails, named" \
  "v2.0: cli: root $T/cli: no refs/remotes/origin/main; a line version reads remote-tracking refs (task versions:fetch)"
R=$T/line

# State B: release/v4.2 (core) and release/opm-v1.1 (catalog_opm), each with a docs commit.
g "$T/core" switch -q -c release/v4.2 v4.2.0; page "$T/core" fix42; commit "$T/core" "docs fix on release/v4.2" > /dev/null; g "$T/core" switch -q main
g "$T/catalog_opm" switch -q -c release/opm-v1.1 opm-v1.1.0; page "$T/catalog_opm" fix11; commit "$T/catalog_opm" "docs fix on release/opm-v1.1" > /dev/null; g "$T/catalog_opm" switch -q main
# ... and release/v2.3 (library) and release/v3.1 (opm-operator), the same way.
g "$T/library" switch -q -c release/v2.3 v2.3.0; page "$T/library" fix23; commit "$T/library" "docs fix on release/v2.3" > /dev/null; g "$T/library" switch -q main
g "$T/opm-operator" switch -q -c release/v3.1 v3.1.0; page "$T/opm-operator" fix31; commit "$T/opm-operator" "docs fix on release/v3.1" > /dev/null; g "$T/opm-operator" switch -q main
LGOOD=$(manifest line-b "$lgood")

run "$LGOOD" -- --check
expect line-stale 0 "before --fetch the clones still resolve state A" \
  "${L}core${TAB}v4.2.0${TAB}$CORE_A${TAB}$CORE_HOW; docs: main head (no release/v4.2; main still releases v4.2)${TAB}main" \
  "${L}catalog_opm${TAB}opm-v1.1.0${TAB}$CAT_A${TAB}"

run "$LGOOD" -- --fetch
expect fetch-b 0 "--fetch brings the release branches into the clones"
run "$LGOOD" -- --check
expect line-branch 0 "core, catalog, library and operator docs from their release branch heads; the versions are unchanged" \
  "${L}core${TAB}v4.2.0${TAB}$(rev core release/v4.2)${TAB}$CORE_HOW; docs: release/v4.2 head${TAB}release/v4.2" \
  "${L}library${TAB}v2.3.0${TAB}$(rev library release/v2.3)${TAB}pin:cli go.mod; docs: release/v2.3 head${TAB}release/v2.3" \
  "${L}opm-operator${TAB}v3.1.0${TAB}$(rev opm-operator release/v3.1)${TAB}pin:cli internal/operator/manifest.go; docs: release/v3.1 head${TAB}release/v3.1" \
  "${L}catalog_opm${TAB}opm-v1.1.0${TAB}$(rev catalog_opm release/opm-v1.1)${TAB}line:newest opm-v1.* tag; docs: release/opm-v1.1 head${TAB}release/opm-v1.1" \
  "${L}cli${TAB}v1.5.0-beta.10${TAB}"

# The stamp: gen-stamp.sh on the host, SITE_DIR at a scratch copy of the --check output.
mkdir -p "$T/stamp/.versions"
# shellcheck disable=SC2046 # env assignments hold no spaces
env $(fixture_env) OPM_VERSIONS_MANIFEST="$LGOOD" sh "$RESOLVE" --check > "$T/stamp/.versions/versions.tsv" 2>/dev/null
out=$(SITE_DIR="$T/stamp" OPM_VERSIONS='' OPM_BUILD_REFS='' sh "$SITE/scripts/gen-stamp.sh" 2>&1 && cat "$T/stamp/data/opm/build.json") && rc=0 || rc=$?
expect line-stamp 0 "build.json records every SHA, every docs value, kind line and the opmodel.dev commit" \
  "\"site\": \"$SITE_SHA\"" "\"kind\": \"line\"" \
  "\"cli\": {\"ref\": \"v1.5.0-beta.10\", \"sha\": \"$(rev cli v1.5.0-beta.10)\", \"how\": \"line:newest v1.5.* tag; docs: v1.5.0-beta.10 (main is past v1.5, no release/v1.5)\", \"docs\": \"tag\"}" \
  "\"library\": {\"ref\": \"v2.3.0\", \"sha\": \"$(rev library release/v2.3)\", \"how\": \"pin:cli go.mod; docs: release/v2.3 head\", \"docs\": \"release/v2.3\"}" \
  "\"opm-operator\": {\"ref\": \"v3.1.0\", \"sha\": \"$(rev opm-operator release/v3.1)\"" \
  "\"core\": {\"ref\": \"v4.2.0\", \"sha\": \"$(rev core release/v4.2)\", \"how\": \"$CORE_HOW; docs: release/v4.2 head\", \"docs\": \"release/v4.2\"}" \
  "\"catalog_opm\": {\"ref\": \"opm-v1.1.0\", \"sha\": \"$(rev catalog_opm release/opm-v1.1)\"" "\"docs\": \"release/opm-v1.1\"" \
  "\"opm\": {\"ref\": \"main\", \"sha\": \"$OPM_HEAD\", \"how\": \"line:main head\", \"docs\": \"main\"}"

# The frozen manifest round trip: --freeze, then --check of that copy.
# shellcheck disable=SC2046
env $(fixture_env) OPM_VERSIONS_MANIFEST="$LGOOD" sh "$RESOLVE" --freeze > "$T/manifests/frozen-b.conf" 2>/dev/null
run "$T/manifests/frozen-b.conf" -- --check
A="v2.0${TAB}v2.0 (test)${TAB}1${TAB}true${TAB}anchored${TAB}"
expect line-freeze 0 "the frozen copy resolves the same six SHAs, anchored, cli by tag name, library and opm-operator by their branch heads" \
  "${A}cli${TAB}v1.5.0-beta.10${TAB}$(rev cli v1.5.0-beta.10)${TAB}anchor${TAB}tag" \
  "${A}library${TAB}$(rev library release/v2.3)${TAB}$(rev library release/v2.3)${TAB}override:frozen from line v2.3.0, docs release/v2.3${TAB}sha" \
  "${A}opm-operator${TAB}$(rev opm-operator release/v3.1)${TAB}$(rev opm-operator release/v3.1)${TAB}override:frozen from line v3.1.0, docs release/v3.1${TAB}sha" \
  "${A}core${TAB}$(rev core release/v4.2)${TAB}$(rev core release/v4.2)${TAB}override:frozen from line v4.2.0, docs release/v4.2${TAB}sha" \
  "${A}catalog_opm${TAB}$(rev catalog_opm release/opm-v1.1)${TAB}$(rev catalog_opm release/opm-v1.1)${TAB}explicit${TAB}sha" \
  "${A}opm${TAB}$OPM_HEAD${TAB}$OPM_HEAD${TAB}explicit${TAB}sha"
run "$SITE/.versions/frozen.conf" -- --check
expect line-freeze-in-place 1 "the generated frozen.conf is refused as the manifest, by path" \
  "resolve-versions: $SITE/.versions/frozen.conf is the generated frozen manifest, which this run rewrites; copy it outside site/.versions/ first"

# The recovery from a line version that fails the build: the version block of
# the last good frozen.conf, pasted into a manifest with its own header and
# floors, resolves as an anchored version at the same trees.
freeze_block() { awk '/^\[version /{ on = 1 } on' "$1"; }
run "$(manifest line-recover "$(freeze_block "$T/manifests/frozen-b.conf")")" -- --check
expect line-recover 0 "the frozen version block pasted into a manifest resolves anchored at the same six SHAs" \
  "${A}cli${TAB}v1.5.0-beta.10${TAB}$(rev cli v1.5.0-beta.10)${TAB}anchor${TAB}tag" \
  "${A}library${TAB}$(rev library release/v2.3)${TAB}" "${A}opm-operator${TAB}$(rev opm-operator release/v3.1)${TAB}" \
  "${A}core${TAB}$(rev core release/v4.2)${TAB}" "${A}catalog_opm${TAB}$(rev catalog_opm release/opm-v1.1)${TAB}" \
  "${A}opm${TAB}$OPM_HEAD${TAB}"

# State C: cli v1.5.0, a final on main, pinning library v2.1.0 (so core v4.1.0); core
# v4.1.1 on a side branch fix-v4.1 off v4.1.0, never merged into main; catalog
# opm-v1.2.0 on main after a docs commit.
gomod "$T/cli" v2.1.0; page "$T/cli" final; commit "$T/cli" "v1.5.0" > /dev/null; g "$T/cli" tag v1.5.0
g "$T/core" switch -q -c fix-v4.1 v4.1.0; page "$T/core" fix41; commit "$T/core" "fix on v4.1" > /dev/null; g "$T/core" tag v4.1.1; g "$T/core" switch -q main
page "$T/catalog_opm" c; commit "$T/catalog_opm" "docs before opm-v1.2.0" > /dev/null; g "$T/catalog_opm" tag opm-v1.2.0
run "$LGOOD" -- --fetch
expect fetch-c 0 "--fetch brings state C into the clones"
run "$LGOOD" -- --check
expect line-newer-tag 0 "a final beats its prereleases; core's line v4.1, which main is past, documents its pin v4.1.0, not v4.1.1; the catalog major follows opm-v1.2.0" \
  "${L}cli${TAB}v1.5.0${TAB}$(rev cli v1.5.0)${TAB}" \
  "${L}library${TAB}v2.1.0${TAB}" \
  "${L}core${TAB}v4.1.0${TAB}$(rev core v4.1.0)${TAB}$CORE_HOW; docs: v4.1.0 (main is past v4.1, no release/v4.1)${TAB}tag" \
  "${L}catalog_opm${TAB}opm-v1.2.0${TAB}$(rev catalog_opm main)${TAB}line:newest opm-v1.* tag; docs: main head (no release/opm-v1.2; main still releases opm-v1.2)${TAB}main"

# State D: catalog opm-v2.0.0 on main.
page "$T/catalog_opm" d; commit "$T/catalog_opm" "opm-v2.0.0" > /dev/null; g "$T/catalog_opm" tag opm-v2.0.0
run "$LGOOD" -- --fetch
expect fetch-d 0 "--fetch brings state D into the clones"
run "$LGOOD" -- --check
expect line-catalog-major 0 "the catalog stays on its major (opm-v1.2.0), docs at its tag once main is past opm-v1.2" \
  "${L}catalog_opm${TAB}opm-v1.2.0${TAB}$(rev catalog_opm opm-v1.2.0)${TAB}line:newest opm-v1.* tag; docs: opm-v1.2.0 (main is past opm-v1.2, no release/opm-v1.2)${TAB}tag"

# State E: core release/v4.1 from the floor commit, and cli release/v1.5 from
# v1.5.0-beta.10, each plus a docs commit; neither contains the release.
g "$T/core" switch -q -c release/v4.1 dialect-floor; page "$T/core" fix41b; commit "$T/core" "docs on release/v4.1" > /dev/null; g "$T/core" switch -q main
g "$T/cli" switch -q -c release/v1.5 v1.5.0-beta.10; page "$T/cli" fix15; commit "$T/cli" "docs on release/v1.5" > /dev/null; g "$T/cli" switch -q main
run "$LGOOD" -- --fetch
expect fetch-e 0 "--fetch brings state E into the clones"
run "$LGOOD" -- --check
expect line-contain 1 "a release branch that does not contain the release the stamp names fails, cli included (no override recovers it)" \
  "v2.0: core release/v4.1 $(short "$(rev core release/v4.1)") (docs for v4.1.0): does not contain v4.1.0, the release the stamp names" \
  "v2.0: cli release/v1.5 $(short "$(rev cli release/v1.5)") (docs for v1.5.0): does not contain v1.5.0, the release the stamp names"

# The fetch: a local-only tag survives prune config, and a worktree root gets no FETCH_HEAD.
g "$R/opm" tag v0.0.0-localonly
g "$R/library" worktree add -q --detach "$T/line-wt-library"
run "$LGOOD" OPM_SRC_LIBRARY="$T/line-wt-library" GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=fetch.prune GIT_CONFIG_VALUE_0=true \
  GIT_CONFIG_KEY_1=fetch.pruneTags GIT_CONFIG_VALUE_1=true -- --fetch
heads=$(find "$R" -path '*/.git/FETCH_HEAD' -o -path '*/.git/worktrees/*/FETCH_HEAD' | head -n 3)
why=""
g "$R/opm" rev-parse -q --verify refs/tags/v0.0.0-localonly > /dev/null || why="the local-only tag is gone; "
[ -z "$heads" ] || why="${why}FETCH_HEAD written: $heads"
if [ "$rc" = 0 ] && [ -z "$why" ]; then ok line-fetch-prune "--fetch under fetch.prune and fetch.pruneTags keeps a local-only tag and writes no FETCH_HEAD, from a worktree too"
else bad line-fetch-prune "exit $rc; $why"; fi

# A configured mapping onto local branches: without --refmap= git would apply
# it as an extra forced update and drop a local-only commit on a branch that
# is not checked out; with it, the branch stays put.
g "$R/catalog_opm" switch -q --detach
LOCALBR=$(g "$R/catalog_opm" commit-tree -p refs/remotes/origin/release/opm-v1.1 -m "local only" "refs/remotes/origin/release/opm-v1.1^{tree}")
g "$R/catalog_opm" branch release/opm-v1.1 "$LOCALBR"
g "$R/catalog_opm" config --add remote.origin.fetch '+refs/heads/*:refs/heads/*'
run "$LGOOD" -- --fetch
why=""
[ "$(g "$R/catalog_opm" rev-parse refs/heads/release/opm-v1.1)" = "$LOCALBR" ] || why="the local branch release/opm-v1.1 was reset by the configured mapping"
if [ "$rc" = 0 ] && [ -z "$why" ]; then ok line-fetch-refmap "--fetch ignores a configured +refs/heads/*:refs/heads/* mapping; a local-only commit on a branch not checked out survives"
else bad line-fetch-refmap "exit $rc; $why"; fi

# A conflicting upstream tag: refused, the local tag kept, every other ref updated.
g "$R/core" tag v4.9.0 HEAD
LOCAL49=$(g "$R/core" rev-parse v4.9.0)
g "$R/core" config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'
page "$T/core" new49; commit "$T/core" "v4.9.0 upstream" > /dev/null; g "$T/core" tag v4.9.0
run "$LGOOD" -- --fetch
why=""
[ "$(g "$R/core" rev-parse v4.9.0)" = "$LOCAL49" ] || why="the local v4.9.0 moved; "
[ "$(g "$R/core" rev-parse refs/remotes/origin/main)" = "$(rev core main)" ] || why="${why}origin/main did not update"
expect line-fetch-clobber 1 "--fetch refuses to clobber a local tag, names the root, and still updates origin/main" \
  "would clobber existing tag" "--fetch failed in:" "core: $R/core"
[ -z "$why" ] || bad line-fetch-clobber-refs "$why"

# --- The real repositories (the caller's roots), resolver only -------------------
rrun() { out=$(OPM_VERSIONS='' sh "$RESOLVE" "$@" 2>&1) && rc=0 || rc=$?; }
rrun --pins v1.0.0-alpha.25
expect real-pins 0 "cli v1.0.0-alpha.25 pins library v1.0.0-alpha.35, core v2.0.0-alpha.12, opm-operator v1.0.0-alpha.19" \
  "library${TAB}v1.0.0-alpha.35${TAB}" "core${TAB}v2.0.0-alpha.12${TAB}" "opm-operator${TAB}v1.0.0-alpha.19${TAB}"

real=$SITE/.check/versions-test/repos/manifests/real-alpha25.conf
{
  for r in $REPOS; do printf '[repo "%s"]\n\tfloor = %s\n' "$r" "$(git config --file "$SITE/versions.conf" --get "repo.$r.floor")"; done
  printf '[version "v1.0"]\n\tlabel = v1.0 (beta)\n\tweight = 1\n\tdefault = true\n\tcli = v1.0.0-alpha.25\n\tcatalog = opm-v4.4.2\n\topm = %s\n' \
    "$(git config --file "$SITE/versions.conf" --get repo.opm.floor)"
} > "$real"
out=$(OPM_VERSIONS='' OPM_VERSIONS_MANIFEST="$real" sh "$RESOLVE" --check 2>&1) && rc=0 || rc=$?
expect real-pre-floor 1 "anchored at cli v1.0.0-alpha.25, every pin is older than its floor" \
  "v1.0: cli v1.0.0-alpha.25: older than its floor" "v1.0: opm-operator v1.0.0-alpha.19: no docs/site at this ref"

# A line version on the real roots: the cli and catalog refs equal git's own
# tag order (versionsort.suffix=-, right while every prerelease uses "-": the
# oracle, never the implementation), and library, core and opm-operator are
# exactly what that cli tag pins.
real_root() {
  sh -c '. "$0" >/dev/null; sources; for m in $MOUNTS; do [ "$m" = -v ] || printf "%s\n" "$m"; done' "$SITE/scripts/run-in-image.sh" tag |
    awk -v r="$1" '{ m = $0; sub(/:\/src\/.*/, "", m); d = $0; sub(/.*:\/src\//, "", d); sub(/:ro$/, "", d); if (d == r) print m }'
}
git_newest() { git -C "$(real_root "$1")" -c versionsort.suffix=- tag -l --sort=-v:refname | grep -E "$2" | head -n 1; }
reall=$SITE/.check/versions-test/repos/manifests/real-line.conf
{
  for r in $REPOS; do printf '[repo "%s"]\n\tfloor = %s\n' "$r" "$(git config --file "$SITE/versions.conf" --get "repo.$r.floor")"; done
  printf '[version "v1.0"]\n\tlabel = v1.0 (beta)\n\tweight = 1\n\tdefault = true\n\tcli-line = v1.0\n\tcatalog-line = opm-v4\n'
} > "$reall"
want_cli=$(git_newest cli '^v1\.0\.[0-9]+(-[0-9A-Za-z.-]+)?$')
want_cat=$(git_newest catalog_opm '^opm-v4\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$')
pins=$(OPM_VERSIONS='' sh "$RESOLVE" --pins "$want_cli" 2>/dev/null || true)
pin() { printf '%s\n' "$pins" | awk -F'\t' -v r="$1" '$1 == r { print $2 }'; }
out=$(OPM_VERSIONS='' OPM_VERSIONS_MANIFEST="$reall" sh "$RESOLVE" --check 2>&1) && rc=0 || rc=$?
RL="v1.0${TAB}v1.0 (beta)${TAB}1${TAB}true${TAB}line${TAB}"
baddocs=$(printf '%s\n' "$out" | awk -F'\t' '$5 == "line" && $10 != "tag" && $10 != "main" && $10 !~ /^release\// { print $6 ": " $10 }')
expect real-line 0 "cli-line = v1.0 resolves cli $want_cli (git's order), the pins of that tag, catalog $want_cat (git's order); docs tag, main or release/" \
  "${RL}cli${TAB}$want_cli${TAB}" "${RL}library${TAB}$(pin library)${TAB}" "${RL}core${TAB}$(pin core)${TAB}" \
  "${RL}opm-operator${TAB}$(pin opm-operator)${TAB}" "${RL}catalog_opm${TAB}$want_cat${TAB}" "${RL}opm${TAB}main${TAB}"
if [ -z "$want_cli" ] || [ -z "$want_cat" ] || [ -z "$(pin core)" ] || [ -n "$baddocs" ]; then
  bad real-line-docs "cli \"$want_cli\", catalog \"$want_cat\", core pin \"$(pin core)\"; docs not tag, main or release/: $baddocs"
fi

# The recovery on the real roots: the frozen version block of that line, with
# the real floors, resolves as an anchored version at the same six SHAs.
line_shas=$(printf '%s\n' "$out" | awk -F'\t' '$5 == "line" { print $6 " " $8 }' | sort)
# A cli whose docs are not its tag freezes by the SHA of its docs tree.
want_fcli=$(printf '%s\n' "$out" | awk -F'\t' '$5 == "line" && $6 == "cli" { print ($10 == "tag") ? $7 : $8 }')
realf=$SITE/.check/versions-test/repos/manifests/real-line-frozen.conf
{
  for r in $REPOS; do printf '[repo "%s"]\n\tfloor = %s\n' "$r" "$(git config --file "$SITE/versions.conf" --get "repo.$r.floor")"; done
  OPM_VERSIONS='' OPM_VERSIONS_MANIFEST="$reall" sh "$RESOLVE" --freeze 2>/dev/null | awk '/^\[version /{ on = 1 } on'
} > "$realf"
out=$(OPM_VERSIONS='' OPM_VERSIONS_MANIFEST="$realf" sh "$RESOLVE" --check 2>&1) && rc=0 || rc=$?
frozen_shas=$(printf '%s\n' "$out" | awk -F'\t' '$5 == "anchored" { print $6 " " $8 }' | sort)
expect real-line-frozen 0 "the real line's frozen version block resolves anchored" "${RL%line${TAB}}anchored${TAB}cli${TAB}$want_fcli${TAB}"
if [ -z "$line_shas" ] || [ "$line_shas" != "$frozen_shas" ]; then
  bad real-line-frozen-shas "line: $(printf '%s' "$line_shas" | tr '\n' ' '); frozen: $(printf '%s' "$frozen_shas" | tr '\n' ' ')"
fi

echo
echo "test-resolve: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
