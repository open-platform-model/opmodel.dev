#!/bin/sh
# The bundle has no section page: _index.md is neither listed nor held.
m=$SITE/.bundles/enhancements/edge/manifest.json
jq 'del(.pages[] | select(.path == "_index.md"))' "$m" > "$m.tmp" && mv "$m.tmp" "$m"
rm "$SITE/.bundles/enhancements/edge/content/_index.md"
