#!/bin/sh
# No section bundle: no section, no tab.
# The fixture bundles without the Enhancements section bundle: its lock
# entry and its tree removed.
jq 'del(.bundles[] | select(.root == "/enhancements/"))' "$SITE/.bundles/lock.json" > "$SITE/lock.tmp" && mv "$SITE/lock.tmp" "$SITE/.bundles/lock.json"
rm -rf "$SITE/.bundles/enhancements"
