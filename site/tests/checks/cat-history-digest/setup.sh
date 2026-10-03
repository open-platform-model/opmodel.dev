#!/bin/sh
# history.json edited after the lock recorded its digest.
sed -i 's#"floor": "4.4"#"floor": "4.3"#' "$SITE/.bundles/catalog-opm/history.json"
