#!/bin/sh
# A bundle holds a content file its manifest does not list.
printf -- "---\ntitle: Stray\ndescription: Not listed.\ntype: reference\n---\n" > "$SITE/.bundles/catalog-opm/4.4/content/traits/stray.md"
