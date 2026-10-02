#!/bin/sh
# A bundle page with a front-matter key outside the dialect.
sed -i '2a draft: true' "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
