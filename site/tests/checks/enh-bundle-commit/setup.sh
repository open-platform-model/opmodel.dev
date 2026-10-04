#!/bin/sh
# The manifest's source.commit is not the commit the lock verified: the tree
# is not the bundle the pull checked.
m=$SITE/.bundles/enhancements/edge/manifest.json
jq '.source.commit = "0000000000000000000000000000000000000000"' "$m" > "$m.tmp" && mv "$m.tmp" "$m"
