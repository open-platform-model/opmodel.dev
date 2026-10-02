#!/bin/sh
# A bundle page links a docs page the default version does not have.
printf '\nSee [nowhere](/docs/nowhere/).\n' >> "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
