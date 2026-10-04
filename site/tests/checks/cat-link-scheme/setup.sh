#!/bin/sh
# A catalog page links javascript:. SITE/.bundles is the copy of what
# opm-docs pull wrote, so this edit comes after the pull's markup check
# (docs-kit internal/mdsafe, which refuses it there): the Catalogs render
# hook alone must refuse it.
printf '\nSee [backup](javascript:alert(1)).\n' >> "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
