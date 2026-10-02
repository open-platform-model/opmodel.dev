#!/bin/sh
# Two projects placed at one root: a second project's bundle, otherwise
# valid, at /catalogs/opm/.
cp -R "$SITE/.bundles/catalog-opm" "$SITE/.bundles/catalog-twin"
sed -i 's/"project": "catalog-opm"/"project": "catalog-twin"/' "$SITE/.bundles/catalog-twin/4.4/manifest.json"
jq '.bundles += [.bundles[0] | .project = "catalog-twin" | .dir = "catalog-twin/4.4"]' "$SITE/.bundles/lock.json" > "$SITE/lock.tmp" && mv "$SITE/lock.tmp" "$SITE/.bundles/lock.json"
