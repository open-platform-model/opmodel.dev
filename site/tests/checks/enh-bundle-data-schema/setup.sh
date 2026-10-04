#!/bin/sh
# data/enhancements.json carries another schema.
d=$SITE/.bundles/enhancements/edge/data/enhancements.json
jq '.schema = "docs.opmodel.dev/data/enhancements/v2"' "$d" > "$d.tmp" && mv "$d.tmp" "$d"
