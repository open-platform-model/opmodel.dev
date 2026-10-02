#!/bin/sh
# A bundle kind index with a weight that is no positive integer.
sed -i 's/^weight: 2$/weight: two/' "$SITE/.bundles/catalog-opm/4.4/content/resources/_index.md"
