#!/bin/sh
# The section page has no front matter.
f=$SITE/.bundles/enhancements/edge/content/_index.md
awk 'BEGIN { n = 0 } n >= 2 { print; next } /^---$/ { n++ }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
