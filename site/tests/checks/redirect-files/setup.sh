# No robots.txt at the root.
rm "$SITE/layouts/robots.txt"
sed -i 's/^enableRobotsTXT = true$/enableRobotsTXT = false/' "$SITE/config/_default/hugo.toml"
grep -q 'enableRobotsTXT = false' "$SITE/config/_default/hugo.toml"
