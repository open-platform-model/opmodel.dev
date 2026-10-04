#!/bin/sh
# No section bundle: a source link into the section has nothing to resolve to.
# The fixture bundles without the Enhancements section bundle: its lock
# entry and its tree removed.
jq 'del(.bundles[] | select(.root == "/enhancements/"))' "$SITE/.bundles/lock.json" > "$SITE/lock.tmp" && mv "$SITE/lock.tmp" "$SITE/.bundles/lock.json"
rm -rf "$SITE/.bundles/enhancements"
