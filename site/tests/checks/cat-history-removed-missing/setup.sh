#!/bin/sh
# A removed member whose page its last segment does not have, at the digest the lock records.
f=$SITE/.bundles/catalog-opm/history.json
jq '.removed.edge[0].page = "blueprints/gone"' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
d=sha256:$(sha256sum "$f" | cut -c1-64)
jq --arg d "$d" '.history[0].digest = $d' "$SITE/.bundles/lock.json" > "$SITE/.bundles/lock.tmp"
mv "$SITE/.bundles/lock.tmp" "$SITE/.bundles/lock.json"
