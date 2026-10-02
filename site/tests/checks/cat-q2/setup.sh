#!/bin/sh
# The adapter drops a page its manifest lists (4.4's older apiVersion page,
# which nothing links), and a static file adds one nobody lists.
sed -i 's#{{- $pg := . -}}#{{- $pg := . -}}{{- if eq .path "traits/backup-v1alpha1.md" -}}{{- continue -}}{{- end -}}#' "$SITE/catalogs/_content.gotmpl"
grep -q 'backup-v1alpha1' "$SITE/catalogs/_content.gotmpl" || { echo "cat-q2: the adapter edit did not apply" >&2; exit 1; }
