#!/bin/sh
# A build with a bundles.cue and no pull: the build requires the bundles
# (every source page comes from them) and names the task that pulls them.
rm -rf "$SITE/.bundles"
