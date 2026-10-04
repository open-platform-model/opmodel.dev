#!/bin/sh
# data/enhancements.json lost the archived entry 0002, whose pages remain.
d=$SITE/.bundles/enhancements/edge/data/enhancements.json
jq 'del(.entries[] | select(.id == "0002"))' "$d" > "$d.tmp" && mv "$d.tmp" "$d"
