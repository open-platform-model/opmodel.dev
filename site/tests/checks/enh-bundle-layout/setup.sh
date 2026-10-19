#!/bin/sh
# data/enhancements.json is schema v2, but no entry names a layout.
d=$SITE/.bundles/enhancements/edge/data/enhancements.json
jq 'del(.entries[].layout)' "$d" > "$d.tmp" && mv "$d.tmp" "$d"
