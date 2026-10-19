#!/bin/sh
# data/enhancements.json carries a schema this site does not read (v3).
d=$SITE/.bundles/enhancements/edge/data/enhancements.json
jq '.schema = "docs.opmodel.dev/data/enhancements/v3"' "$d" > "$d.tmp" && mv "$d.tmp" "$d"
