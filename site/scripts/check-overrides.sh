#!/bin/sh
# Drift guard: every theme file that an override in site/layouts or
# site/assets copies is pinned by hash in site/overrides.sha256 (paths
# relative to site/themes/hextra). After a Hextra bump, a failure names each
# pinned file that changed upstream: diff it, merge the hunk into the
# override, then re-pin.
#
#   check-overrides.sh             check every pinned file; exit 1 on any change
#   check-overrides.sh --update    re-pin exactly the paths already listed
#
# A new override copy adds its line to site/overrides.sha256 by hand
# (sha256sum <path>, run in site/themes/hextra). Never run --update only to
# turn a build green.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
list=$SITE_DIR/overrides.sha256
cd "$SITE_DIR/themes/hextra"

if [ "${1:-}" = --update ]; then
  paths=$(awk 'NF { print $2 }' "$list")
  # shellcheck disable=SC2086 # the listed paths hold no spaces
  sha256sum $paths > "$list.new"
  mv "$list.new" "$list"
  echo "check-overrides: re-pinned $(wc -l < "$list" | tr -d ' ') theme files"
  exit 0
fi

out=$(mktemp); trap 'rm -f "$out"' EXIT
if sha256sum -c "$list" > "$out" 2>&1; then
  echo "check-overrides: $(wc -l < "$list" | tr -d ' ') overridden theme files unchanged upstream"
else
  grep -v ': OK$' "$out" || true
  echo "check-overrides: FAILED, the theme changed under an override (diff upstream, merge the hunk, then --update)"
  exit 1
fi
