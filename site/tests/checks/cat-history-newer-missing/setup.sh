#!/bin/sh
# 4.4's lineage of the backup trait starts with an apiVersion 4.4 has no
# page for, at the digest the lock records.
f=$SITE/.bundles/catalog-opm/history.json
jq '.lineage["trait/backup"]["4.4"][0] = "v1alpha3"' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
d=sha256:$(sha256sum "$f" | cut -c1-64)
jq --arg d "$d" '.history[0].digest = $d' "$SITE/.bundles/lock.json" > "$SITE/.bundles/lock.tmp"
mv "$SITE/.bundles/lock.tmp" "$SITE/.bundles/lock.json"
