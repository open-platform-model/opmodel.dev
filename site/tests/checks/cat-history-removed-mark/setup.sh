#!/bin/sh
# A bundle page carries the "opm:removed" mark on a link to another segment
# of its own catalog that no removed entry of the page names.
printf '\nThe [old backup](/catalogs/opm/4.4/traits/backup/ "opm:removed") page.\n' >> "$SITE/.bundles/catalog-opm/4.5/content/traits/expose.md"
