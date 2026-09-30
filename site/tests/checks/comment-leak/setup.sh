# Without HTML minification the planning comments reach the pages.
sed -i 's/^  minifyOutput = true$/  minifyOutput = false/' "$SITE/config/_default/hugo.toml"
grep -q 'minifyOutput = false' "$SITE/config/_default/hugo.toml"
