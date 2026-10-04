#!/bin/sh
# A lock without tab bundles: no section, no tab, and a catalogs/ directory
# in the output fails. The fixture pages that link the tab would fail first.
. "$BP"
drop_tabs "$SITE/.bundles"
drop_page "$SITE/.bundles" core concepts/catalog-links.md
drop_page "$SITE/.bundles" catalog-opm-docs authoring/attach-the-fixture-trait.md
