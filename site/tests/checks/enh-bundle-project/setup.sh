#!/bin/sh
# The manifest names another project.
m=$SITE/.bundles/enhancements/edge/manifest.json
jq '.project = "design"' "$m" > "$m.tmp" && mv "$m.tmp" "$m"
