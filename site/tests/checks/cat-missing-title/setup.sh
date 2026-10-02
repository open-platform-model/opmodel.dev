#!/bin/sh
# A bundle page without a title.
sed -i '/^title:/d' "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
