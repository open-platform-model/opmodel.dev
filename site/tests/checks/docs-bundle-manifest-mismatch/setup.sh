#!/bin/sh
# The lock and a docs bundle's manifest.json disagree on the version.
sed -i 's/"version": "2.0.0-beta.3"/"version": "2.0.0-beta.4"/' "$SITE/.bundles/_versions/v1.0/core/manifest.json"
