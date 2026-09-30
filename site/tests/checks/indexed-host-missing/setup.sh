# No params.opm.indexedHost: the build must fail, not publish without a robots rule.
sed -i '/^    indexedHost = /d' "$SITE/config/_default/hugo.toml"
! grep -q 'indexedHost' "$SITE/config/_default/hugo.toml"
