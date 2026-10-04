#!/bin/sh
# The manifest places the bundle at another root.
m=$SITE/.bundles/enhancements/edge/manifest.json
jq '.placement.root = "/design/"' "$m" > "$m.tmp" && mv "$m.tmp" "$m"
