#!/bin/sh
# A lock of another schema.
sed -i "s#docs.opmodel.dev/lock/v1#docs.opmodel.dev/lock/v2#" "$SITE/.bundles/lock.json"
