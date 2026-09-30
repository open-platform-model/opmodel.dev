#!/bin/sh
# Regression tests for site/scripts/resolve-versions.sh. Host side: POSIX sh
# and git, like the resolver. It builds six small git repositories (with
# go.mod, opm/schema/loader.go, internal/operator/manifest.go, docs/site/ and
# tags) under site/.check/versions-test/repos/, the only directory it removes
# and recreates, and never uses /tmp. Then:
#   - every resolver case of the fixture repositories: the pin reads,
#     overrides, the anchor rule, pseudo-versions, docs/site, floors, the
#     manifest grammar and the two root checks;
#   - the pins at the real cli v1.0.0-alpha.25, and a --check anchored there,
#     read from the caller's source roots (OPM_SRC_WORKTREE=site-src ...).
# Each failing case asserts that the message names the repository, and the
# ref where there is one. Prints "ok" or "FAIL" per case; exits 1 on any FAIL.
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
g() { d=$1; shift
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$d" -c user.name=opm-test -c user.email=opm-test@example.invalid \
    -c commit.gpgSign=false -c tag.gpgSign=false -c core.hooksPath=/dev/null "$@"; }
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
# resolver ENV... -- ARGS: the resolver on the fixture roots; output in $out, status in $rc.
fixture_env() { echo "OPM_SRC_OPM=$T/opm OPM_SRC_CORE=$T/core OPM_SRC_CATALOG_OPM=$T/catalog_opm OPM_SRC_CLI=$T/cli OPM_SRC_LIBRARY=$T/library OPM_SRC_OPM_OPERATOR=$T/opm-operator OPM_VERSIONS="; }
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
expect catalog-prefix 1 "a catalog tag without its opm-v or k8s-v prefix fails" "v2.0: catalog_opm v9.9.9: a catalog tag is opm-v* or k8s-v*"

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

echo
echo "test-resolve: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
