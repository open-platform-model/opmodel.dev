#!/bin/sh
# A docs bundle page at the URL of a site-owned page: the cli bundle gains
# reference/_index.md (listed in its manifest), which the site's own
# content/docs/reference/_index.md also publishes. opm-docs pull checks bundle
# against bundle only (C16); the site's A1 check covers bundle against site.
B=$SITE/.bundles/_versions/v1.0/cli
printf -- '---\ntitle: Reference\ndescription: A section page the cli bundle should not own.\n---\n\nNot the cli bundle'"'"'s page.\n' > "$B/content/reference/_index.md"
jq '.pages += [{path: "reference/_index.md", source: "docs/site/reference/_index.md", generated: false}] | .pages |= sort_by(.path)' "$B/manifest.json" > "$B/m" && mv "$B/m" "$B/manifest.json"
