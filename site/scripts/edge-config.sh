#!/bin/sh
# Derives the edge build's pull config from site/bundles.cue (openspec
# add-edge-build, design Decision 1): every line of the input in order, the
# registry, the signer, tabs, docs, any later block (sections) and every
# comment included, except the top-level versions block (from its
# "versions:" line through the line that closes its braces), then one
# appended site version, "v1.0", whose anchor is cli at edge and whose tags
# put every other quoted key of docs at edge, in the order docs lists them,
# with no pinned (docs-kit C16: an anchor at edge pins nothing it chooses).
# The key stays "v1.0", the version the explicit build builds, so
# gen-docs-bundles.sh accepts the lock's docs entries as they are. Derived,
# never committed: the trust policy (signer, each project's repo) has one
# copy, site/bundles.cue.
#
#   edge-config.sh [<in> [<out>]]   default site/bundles.cue -> site/.edge/bundles.cue
#
# Paths are relative to the repository root. It refuses, naming the input, a
# config with no "cli" key under docs or no top-level versions block, and a
# versions block whose braces never close. POSIX sh and awk; runs on the host
# (task build:edge) and in the build image (task test:site).
set -eu
repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
in=${1:-site/bundles.cue}
out=${2:-site/.edge/bundles.cue}
die() { echo "edge-config: $*" >&2; exit 1; }
[ -f "$in" ] || die "$in does not exist"

# The quoted keys of the top-level docs block, as run-in-image.sh reads them.
keys=$(awk '/^docs:[[:space:]]*\{/ { on = 1; next } on && /^\}/ { on = 0 }
  on && match($0, /^[[:space:]]*"[a-z0-9]+(-[a-z0-9]+)*"[[:space:]]*:/) { k = substr($0, RSTART, RLENGTH); gsub(/[[:space:]":]/, "", k); print k }' "$in")
case " $(printf '%s' "$keys" | tr '\n' ' ') " in
  *" cli "*) ;;
  *) die "$in names no \"cli\" under docs: the edge build's anchor is the cli's edge bundle" ;;
esac

mkdir -p "$(dirname "$out")"
tmp=$out.tmp.$$
trap 'rm -f "$tmp"' EXIT
# Copy every line but the versions block; its end is the line where the
# braces opened on the versions: line balance again (a one-line block, or a
# closing } at column 0). Exit 3: no versions block; 4: it never closes.
rc=0
awk '
  !skip && !seen && /^versions:/ { seen = 1; skip = 1; depth = 0 }
  skip {
    line = $0
    o = gsub(/\{/, "{", line); c = gsub(/\}/, "}", line)
    depth += o - c; opened = opened || o > 0
    if (opened && depth <= 0) skip = 0
    next
  }
  { print }
  END { if (!seen) exit 3; if (skip) exit 4 }' "$in" > "$tmp" || rc=$?
case $rc in
  0) ;;
  3) die "$in has no top-level versions: block to replace" ;;
  4) die "$in: the top-level versions: block never closes" ;;
  *) die "reading $in failed (awk exit $rc)" ;;
esac

tags=""
for k in $keys; do
  [ "$k" = cli ] && continue
  tags="${tags:+$tags, }\"$k\": \"edge\""
done
{
  echo "// The edge build (task build:edge, CI's sources-main), written by"
  echo "// site/scripts/edge-config.sh in place of bundles.cue's versions: every"
  echo "// docs project at its edge bundle, the cli as the anchor."
  echo 'versions: "v1.0": {'
  printf '\tanchor: {project: "cli", tag: "edge"}\n'
  [ -z "$tags" ] || printf '\ttags: {%s}\n' "$tags"
  echo '}'
} >> "$tmp"
mv "$tmp" "$out"
trap - EXIT
echo "edge-config: wrote $out from $in (v1.0: cli at edge${tags:+, tags $(printf '%s' "$keys" | grep -vx cli | tr '\n' ' ' | sed 's/ $//') at edge})"
