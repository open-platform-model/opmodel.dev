#!/bin/sh
# Vendored-file guard: every third-party file the site serves as it came
# (today Mermaid, assets/lib/mermaid/) is pinned by SHA-256 in
# site/vendored.sha256, with its version, source and licence in the comment
# above its line. A file whose bytes differ from its pin, or a pinned file
# that is missing, fails the build.
#
#   check-vendored.sh    check every pinned file; exit 1 on any difference
#
# Re-vendoring is a download from the source the comment names, verified
# there (the npm registry's dist.integrity for a package tarball), then a
# hand-edited line: there is no --update.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
list=$SITE_DIR/vendored.sha256
cd "$SITE_DIR"

out=$(mktemp); trap 'rm -f "$out" "$out.list"' EXIT
grep -v -e '^#' -e '^[[:space:]]*$' "$list" > "$out.list" || true
n=$(wc -l < "$out.list" | tr -d ' ')
[ "$n" -gt 0 ] || { echo "check-vendored: FAILED, $list pins no file"; exit 1; }
if sha256sum -c "$out.list" > "$out" 2>&1; then
  echo "check-vendored: $n vendored files match their pins"
else
  grep -v ': OK$' "$out" || true
  echo "check-vendored: FAILED, a vendored file differs from its pin in site/vendored.sha256 (re-vendor it from its source, never re-pin what is on disk)"
  exit 1
fi
