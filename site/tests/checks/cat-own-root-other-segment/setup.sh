#!/bin/sh
# A 4.4 page links its own catalog at 4.5: the renderer pins own-root links
# to the bundle's segment, so this can only be a bad bundle.
printf '\nSee [backup in 4.5](/catalogs/opm/4.5/traits/backup/).\n' >> "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
