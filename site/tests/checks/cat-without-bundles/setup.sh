#!/bin/sh
# Manifest mode (env: CASE_MANIFEST=1) with a bundles.cue and no pull: the
# build requires the bundles and names the task that pulls them.
rm -rf "$SITE/.bundles"
mkdir -p "$SITE/.versions/v1.0"
printf 'v1.0\tv1.0\t1\ttrue\tanchored\t\t\t\t\t\n' > "$SITE/.versions/versions.tsv"
