#!/bin/sh
# The adapter drops a page its manifest lists (edge's retention policy, which
# nothing links), and a static file adds one nobody lists.
sed -i 's#{{- $pg := . -}}#{{- $pg := . -}}{{- if eq .path "policies/retention.md" -}}{{- continue -}}{{- end -}}#' "$SITE/catalogs/_content.gotmpl"
grep -q 'policies/retention.md' "$SITE/catalogs/_content.gotmpl" || { echo "cat-q2: the adapter edit did not apply" >&2; exit 1; }
