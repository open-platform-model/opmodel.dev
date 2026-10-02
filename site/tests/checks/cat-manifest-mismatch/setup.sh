#!/bin/sh
# The lock and the bundle's manifest.json disagree on the version.
sed -i 's/"version": "4.5.0"/"version": "4.5.1"/' "$SITE/.bundles/catalog-opm/4.5/manifest.json"
