#!/bin/sh
# A /docs/ link from one docs bundle to a page no bundle and no site page of
# the version has. The bundle's own lint leaves links outside its owned paths
# to the site (docs-kit C15): the site's link check must fail it.
f=$SITE/.bundles/_versions/v1.0/opm-operator/content/operating/the-fixture-operator.md
sed -i 's#(/docs/operating/deploy-a-fixture/)#(/docs/operating/deploy-a-ghost/)#' "$f"
grep -q 'deploy-a-ghost' "$f"
