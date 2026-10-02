#!/bin/sh
# The alias stubs are not published (a broken head-end hook): hosts that
# ignore _redirects would serve nothing at /catalogs/opm/4/....
sed -i 's#{{- range $stubs -}}{{- (resources.FromString . $html).Publish -}}{{- end -}}##' "$SITE/layouts/_partials/custom/head-end.html"
! grep -q 'range $stubs' "$SITE/layouts/_partials/custom/head-end.html" || { echo "cat-redirects: the hook edit did not apply" >&2; exit 1; }
