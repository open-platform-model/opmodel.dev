#!/bin/sh
# A bundle page whose front matter is not YAML.
sed -i '2s/.*/title: [unclosed/' "$SITE/.bundles/catalog-opm/4.4/content/resources/volumes.md"
