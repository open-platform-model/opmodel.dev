#!/bin/sh
# Manifest mode (env: CASE_MANIFEST=1): versions.conf's from-bundles mirror,
# written to versions.tsv by resolve-versions.sh, names fewer repositories
# than the lock's docs entries replace.
V=$SITE/.versions
mkdir -p "$V/v1.0"
for r in opm catalog_opm library opm-operator; do cp -R "$WS/$r" "$V/v1.0/"; done
printf '# from-bundles\tv1.0\tcli core\nv1.0\tv1.0\t1\ttrue\tline\n' > "$V/versions.tsv"
