#!/bin/sh
# A build without bundles: no section, no tab, and a catalogs/ directory in
# the output fails.
rm -rf "$SITE/.bundles" "$SITE/bundles.cue"
