#!/bin/sh
# A build without bundles: no section, no tab, and a catalogs/ directory in
# the output fails.
rm -rf "$SITE/.bundles" "$SITE/bundles.cue"
# The fixture page that links the tab would fail first.
rm -f "$WS/core/docs/site/concepts/catalog-links.md"
