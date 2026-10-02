#!/bin/sh
# A bundle leaf page without a type, and a kind index with one.
sed -i '/^type:/d' "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
