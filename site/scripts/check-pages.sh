#!/bin/sh
# Page-set checks.
#
#   check-pages.sh pre  VERSION=ROOT [...]   before hugo build: A1
#   check-pages.sh post VERSION=ROOT [...]   after it: A1, Q2, stray files, nav order
#
# Lists the URL every page should publish at: the site-owned content/ at /,
# and each source repo's ROOT/<repo>/docs/site/ at /docs/ (x/_index.md is
# /x/, x.md is /x/). Then:
#   A1     fails when two files publish one URL, x.md against x/_index.md
#          included (Hugo lets the first mount win, silently);
#   Q2     fails when a listed URL has no index.html under public/<version>/,
#          or public/<version>/ holds a page nobody listed (a section with no
#          _index.md, a swallowed page);
#   stray  fails on a file under public/<version>/ that is not a known output
#          type, or a .md that is not a page's Markdown output;
#   nav    writes SITE_DIR/.check/<version>/nav-order.txt: the sidebar's links
#          on the version's docs home, in document order.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
mode=$1; shift
PUBLIC=${PUBLIC:-public}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
rc=0

urls() { # $1 dir, $2 URL prefix, $3 label
  [ -d "$1" ] || return 0
  (cd "$1" && find . -type f -name '*.md') | sed 's|^\./||' | sort | while IFS= read -r f; do
    u=$(printf '%s' "$f" | sed -E 's#(^|/)_index\.md$#\1#; s#\.md$#/#')
    printf '%s%s\t%s/%s\n' "$2" "$u" "$3" "$f"
  done
}

for pair in "$@"; do
  v=${pair%%=*}; root=${pair#*=}
  {
    urls content / site
    for r in $REPOS; do urls "$root/$r/docs/site" /docs/ "$r"; done
  } > "$tmp/$v.src"
  awk -F'\t' -v v="$v" '
    { n[$1]++; src[$1] = src[$1] " " $2 }
    END { for (u in n) { if (n[u] > 1) print "A1 FAIL " v ": " u " is published by:" src[u] > "/dev/stderr"; print u } }
  ' "$tmp/$v.src" 2> "$tmp/$v.a1" | sort > "$tmp/$v.want"
  if [ -s "$tmp/$v.a1" ]; then cat "$tmp/$v.a1"; rc=1; fi
  if [ "$mode" != post ]; then
    echo "$v: $(wc -l < "$tmp/$v.want" | tr -d ' ') pages expected, $( [ $rc -eq 0 ] && echo 'no collisions' || echo 'COLLISIONS')"
    continue
  fi

  [ -d "$PUBLIC/$v" ] || { echo "Q2 FAIL $v: $PUBLIC/$v was not built"; rc=1; continue; }
  (cd "$PUBLIC/$v" && find . -type f -name index.html) | sed 's|^\.||; s|index\.html$||' | sort > "$tmp/$v.have"
  missing=$(comm -23 "$tmp/$v.want" "$tmp/$v.have")
  extra=$(comm -13 "$tmp/$v.want" "$tmp/$v.have")
  if [ -n "$missing" ]; then rc=1; echo "Q2 FAIL $v: no page built for:"; echo "$missing" | sed 's/^/  /'; fi
  if [ -n "$extra" ]; then rc=1; echo "Q2 FAIL $v: unexpected pages:"; echo "$extra" | sed 's/^/  /'; fi

  # A .md file must be a page's Markdown output: page /x/ -> x.md, section
  # /s/ -> s/index.md (Hextra's markdown format is ugly with baseName index).
  stray=$(cd "$PUBLIC/$v" && find . -type f ! -path './pagefind/*' | sed 's|^\./||' | sort | while IFS= read -r f; do
    case "$f" in
      *.html|*.xml|*.txt|*.css|*.js|*.json|*.woff2|*.svg|*.png|*.ico|*.webmanifest) ;;
      index.md) grep -qxF / "$tmp/$v.have" || echo "$f" ;;
      */index.md) grep -qxF "/${f%index.md}" "$tmp/$v.have" || echo "$f" ;;
      *.md) grep -qxF "/${f%.md}/" "$tmp/$v.have" || echo "$f" ;;
      *) echo "$f" ;;
    esac
  done)
  if [ -n "$stray" ]; then rc=1; echo "STRAY FAIL $v: files that are no known output:"; echo "$stray" | sed 's/^/  /'; fi

  mkdir -p ".check/$v"
  home="$PUBLIC/$v/docs/index.html"
  if [ -f "$home" ]; then
    tr '\n' ' ' < "$home" | sed -n 's#.*<aside[^>]*hextra-sidebar-container##p' | sed 's#</aside>.*##' |
      grep -oE 'href="?[^" >]+' | sed -E 's#^href="?##' | grep '^/' > ".check/$v/nav-order.txt" || true
  else
    : > ".check/$v/nav-order.txt"
  fi
  echo "$v: $(wc -l < "$tmp/$v.want" | tr -d ' ') pages expected, $(wc -l < "$tmp/$v.have" | tr -d ' ') built, $(wc -l < ".check/$v/nav-order.txt" | tr -d ' ') sidebar links in .check/$v/nav-order.txt"
done
if [ $rc -eq 0 ]; then echo "check-pages ($mode): OK"; else echo "check-pages ($mode): FAILED"; fi
exit $rc
