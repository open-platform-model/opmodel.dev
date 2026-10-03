#!/bin/sh
# A docs entry of the lock whose bundle is not placed in /docs/.
B=$SITE/.bundles/_versions/v1.0/library
jq '.placement = {kind: "tab", root: "/catalogs/library/"}' "$B/manifest.json" > "$B/m" && mv "$B/m" "$B/manifest.json"
