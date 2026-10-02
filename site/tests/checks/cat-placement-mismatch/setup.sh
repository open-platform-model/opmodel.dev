#!/bin/sh
# A manifest places its bundle at another root than the lock's.
sed -i "s#\"root\": \"/catalogs/opm/\"#\"root\": \"/catalogs/other/\"#" "$SITE/.bundles/catalog-opm/4.5/manifest.json"
