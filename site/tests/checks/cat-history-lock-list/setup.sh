#!/bin/sh
# A lock whose "history" is an object, not a list.
jq '.history = {"catalog-opm": .history[0]}' "$SITE/.bundles/lock.json" > "$SITE/.bundles/lock.tmp"
mv "$SITE/.bundles/lock.tmp" "$SITE/.bundles/lock.json"
