#!/bin/sh
# A history.json of another schema, at the digest the lock records.
f=$SITE/.bundles/catalog-opm/history.json
sed -i 's#docs.opmodel.dev/history/v1#docs.opmodel.dev/history/v2#' "$f"
d=sha256:$(sha256sum "$f" | cut -c1-64)
jq --arg d "$d" '.history[0].digest = $d' "$SITE/.bundles/lock.json" > "$SITE/.bundles/lock.tmp"
mv "$SITE/.bundles/lock.tmp" "$SITE/.bundles/lock.json"
