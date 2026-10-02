#!/bin/sh
# A bundle page with a Hugo shortcode the dialect does not allow.
printf '\n{{< tabs >}}\n' >> "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
