#!/bin/sh
# A lock with no docs entries: no site version to build.
jq 'del(.docs)' "$SITE/.bundles/lock.json" > "$SITE/l" && mv "$SITE/l" "$SITE/.bundles/lock.json"
