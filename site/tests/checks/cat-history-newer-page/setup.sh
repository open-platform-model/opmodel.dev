#!/bin/sh
# 4.4's doc model puts the backup trait's newest apiVersion on a page the
# bundle does not build, so the older page's "Newer version" has no target.
f=$SITE/.bundles/catalog-opm/4.4/data/catalog.json
jq '(.members[] | select(.fqn == "opmodel.dev/catalogs/opm/traits/backup@v1alpha2") | .page) = "traits/backup-gone"' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
