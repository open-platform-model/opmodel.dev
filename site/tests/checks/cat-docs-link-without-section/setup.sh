#!/bin/sh
# A build without bundles: a docs page's link into the Catalogs tab has
# nothing to resolve to, and the failure names the task that pulls them.
rm -rf "$SITE/.bundles" "$SITE/bundles.cue"
