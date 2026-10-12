#!/bin/sh
# data/enhancements.json is schema v2, but an entry names no layout.
d=$SITE/.bundles/enhancements/edge/data/enhancements.json
jq '.schema = "docs.opmodel.dev/data/enhancements/v2"' "$d" > "$d.tmp" && mv "$d.tmp" "$d"
