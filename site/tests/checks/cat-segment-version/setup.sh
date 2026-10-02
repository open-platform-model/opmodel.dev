#!/bin/sh
# Lock and manifest agree on a version that is not in the segment.
sed -i "s/\"version\": \"4.4.5\"/\"version\": \"4.5.9\"/" "$SITE/.bundles/lock.json" "$SITE/.bundles/catalog-opm/4.4/manifest.json"
