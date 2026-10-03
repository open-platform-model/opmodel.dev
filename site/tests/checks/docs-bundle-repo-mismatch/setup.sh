#!/bin/sh
# A docs bundle whose manifest names another source repository than the one
# bundles.cue allows to sign its project.
B=$SITE/.bundles/_versions/v1.0/library
jq '.source.repo = "someone-else/library"' "$B/manifest.json" > "$B/m" && mv "$B/m" "$B/manifest.json"
