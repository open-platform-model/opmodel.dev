#!/bin/sh
# A second catalog, twin, at /catalogs/twin/; an opm 4.4 page links it at a
# minor, which a bundle page may not (only its tab root or a major alias).
cp -R "$SITE/.bundles/catalog-opm" "$SITE/.bundles/catalog-twin"
for s in 4.4 4.5 edge; do
  sed -i 's/"project": "catalog-opm"/"project": "catalog-twin"/; s#"root": "/catalogs/opm/"#"root": "/catalogs/twin/"#' "$SITE/.bundles/catalog-twin/$s/manifest.json"
  # its pages link their own root, now /catalogs/twin/
  find "$SITE/.bundles/catalog-twin/$s/content" -name '*.md' -exec sed -i 's#/catalogs/opm/#/catalogs/twin/#g' {} +
done
jq '.bundles += [.bundles[] | select(.project == "catalog-opm") | .project = "catalog-twin" | .root = "/catalogs/twin/" | .dir = ("catalog-twin/" + .segment)]' "$SITE/.bundles/lock.json" > "$SITE/lock.tmp" && mv "$SITE/lock.tmp" "$SITE/.bundles/lock.json"
printf '\nThe [twin catalog](/catalogs/twin/4.4/).\n' >> "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
