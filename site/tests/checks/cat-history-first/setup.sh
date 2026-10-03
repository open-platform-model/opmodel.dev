#!/bin/sh
# A member first seen in a segment the history does not list, at the digest the lock records.
f=$SITE/.bundles/catalog-opm/history.json
jq '.members["opmodel.dev/catalogs/opm/traits/backup@v1alpha2"].first = "4.3"' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
d=sha256:$(sha256sum "$f" | cut -c1-64)
jq --arg d "$d" '.history[0].digest = $d' "$SITE/.bundles/lock.json" > "$SITE/.bundles/lock.tmp"
mv "$SITE/.bundles/lock.tmp" "$SITE/.bundles/lock.json"
