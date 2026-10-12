#!/bin/sh
# An alias of the schema v2 data names a page the bundle does not hold, so no
# page can carry its redirect stub.
. "$BP"
d=$SITE/.bundles/enhancements/edge/data/enhancements.json
jq '(.entries[] | select(.id == "0026") | .aliases) += [{from: "0026/ghost", to: "0026/nowhere"}]' "$d" > "$d.tmp" && mv "$d.tmp" "$d"
