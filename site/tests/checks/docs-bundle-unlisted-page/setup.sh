#!/bin/sh
# A page under a docs bundle's content/ that its manifest.json does not list.
printf -- '---\ntitle: Stray\ndescription: Not in the manifest.\n---\n\nStray.\n' > "$SITE/.bundles/_versions/v1.0/core/content/concepts/stray.md"
