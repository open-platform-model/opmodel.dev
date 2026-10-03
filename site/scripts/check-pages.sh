#!/bin/sh
# Page-set checks.
#
#   check-pages.sh pre  VERSION=ROOT [...]   before hugo build: A1, reserved prefixes
#   check-pages.sh post VERSION=ROOT [...]   after the build and its root files: A1, reserved
#                                            prefixes, Q2, stray files, nav order, links
#
# Lists the URL every page should publish at: the site-owned content/ at /,
# a version's generated reference in .gen/<version>/ at /, and each source
# repo's ROOT/<repo>/docs/site/ at /docs/ (x/_index.md is /x/, x.md is /x/).
# Then:
#   A1     fails when two files publish one URL, x.md against x/_index.md
#          included (Hugo lets the first mount win, silently);
#   placeholder  a site-owned page whose front matter holds `placeholder: true`
#          yields to a source page at the same URL, as gen-mounts.sh mounts it:
#          that pair is no A1 collision;
#   Q2     fails when a listed URL has no index.html under public/<version>/,
#          or public/<version>/ holds a page nobody listed (a section with no
#          _index.md, a swallowed page);
#   stray  fails on a file under public/<version>/ that is not a known output
#          type, or a .md that is not a page's Markdown output;
#   enhancements  with ENH_TREE set (build-all.sh: the build has the
#          Enhancements section), Q2 and stray for public/enhancements/, which
#          belongs to no version: the section page, the graph when GRAPH.md
#          exists, and per entry (NNNN/ and archive/NNNN/ holding config.yaml,
#          but the 0000 template) /enhancements/NNNN/ and its seven documents;
#          besides each page's index.html and index.md (its Markdown output)
#          only the section's Pagefind bundle. Without ENH_TREE,
#          public/enhancements/ must not exist;
#   catalogs  with CAT_DIR set (the build has the Catalogs section), Q2
#          and stray for public/catalogs/, which belongs to no version: the
#          /catalogs/ page and every page each segment's manifest.json lists;
#          the alias stubs (custom/head-end.html: /catalogs/<name>/ and
#          /catalogs/<name>/<MAJOR>/<page>/ for every page of the newest minor
#          of that major), each refreshing to its target under BASE_PATH with
#          a robots noindex tag, else REDIRECT FAIL;
#          besides each page's index.html and index.md only the segments'
#          Pagefind bundles; and nav-order-catalogs-<segment>.txt under
#          CHECK_DIR/catalogs/. Without CAT_DIR, public/catalogs/ must not
#          exist;
#   nav    writes SITE_DIR/.check/<version>/nav-order.txt (CHECK_DIR, default
#          .check): the sidebar's links on the version's docs home, in
#          document order, as site-root paths (BASE_PATH stripped), so the
#          file is the same for every base URL; and nav-order-reference.txt,
#          the same for the Reference home, whose tree the docs home leaves
#          out (Reference is its own tab);
#   links  fails when a URL in the published output names nothing the site
#          serves. This covers the links layouts, shortcodes and stylesheets
#          write, which the link render hook (check Q1) never sees. Pagefind's
#          bundles are skipped. It reads:
#            - in every published HTML file (every version, the /latest/
#              stubs, the root files): the root-relative values of href, src,
#              data-url, poster, data, xlink:href and every srcset entry (check
#              11's attributes), and of every url() in a style attribute or a
#              <style> block;
#            - in every published CSS file: every url(). A relative one is
#              resolved against the stylesheet's directory and printed as a
#              site-root path; one that climbs above public/ fails.
#          data: URLs, fragments and protocol-relative //host URLs are skipped.
#          A root-relative URL must start with BASE_PATH (the base URL's path,
#          exported by build-all.sh; "" at a host root): anything else names
#          another site on the host and fails. Without BASE_PATH, it must name
#          a file under public/, or a directory holding index.html. /latest/
#          URLs are looked up as written, as the stub pages: a host that
#          ignores public/_redirects serves nothing else there.
#          Under a path (BASE_PATH set), every http://, https:// or //host URL
#          on the base URL's host, in every published HTML, XML, TXT, Markdown,
#          JSON and web manifest file, must start with BASE_URL (a literal
#          prefix, never a regex): meta tags, sitemaps and llms.txt included.
#          One line per distinct URL, naming the first file that holds it.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
mode=$1; shift
PUBLIC=${PUBLIC:-public}
CHECK_DIR=${CHECK_DIR:-.check}
BASE_URL=${BASE_URL:-}
BASE_PATH=${BASE_PATH:-}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
rc=0

urls() { # $1 dir, $2 URL prefix, $3 label
  [ -d "$1" ] || return 0
  (cd "$1" && find . -type f -name '*.md') | sed 's|^\./||' | sort | while IFS= read -r f; do
    u=$(printf '%s' "$f" | sed -E 's#(^|/)_index\.md$#\1#; s#\.md$#/#')
    printf '%s%s\t%s/%s\n' "$2" "$u" "$3" "$f"
  done
}

# Site-owned placeholders: content/ pages whose front matter holds
# `placeholder: true` (see gen-mounts.sh).
placeholders=$(grep -rlx 'placeholder: true' content 2>/dev/null | sed 's#^content/##' | sort | tr '\n' ' ' || true)

# The transition (gen-mounts.sh): with the catalog-opm tab, catalog_opm's
# Reference copies of the members are not mounted, so they publish nothing.
catexcl=""
if [ -n "${CAT_DIR:-}" ] && [ -f data/opm/catalogs.json ] && jq -e '[.catalogs[] | select(.project == "catalog-opm")] | length > 0' data/opm/catalogs.json >/dev/null; then
  catexcl=1
fi

for pair in "$@"; do
  v=${pair%%=*}; root=${pair#*=}
  {
    urls content / site
    urls ".gen/$v" / generated
    for r in $REPOS; do urls "$root/$r/docs/site" /docs/ "$r"; done
  } | awk -F'\t' -v X="$catexcl" '!(X && $2 ~ /^catalog_opm\/reference\/(catalog-members\/|catalog-members\.md$|catalog-contract\.md$)/)' > "$tmp/$v.src"
  # A placeholder yields to a source page at its URL (gen-mounts.sh mounts it
  # only where none exists), so it takes no part in A1 there.
  awk -F'\t' -v ph="$placeholders" '
    BEGIN { n = split(ph, a, " "); for (i = 1; i <= n; i++) isph["site/" a[i]] = 1 }
    { line[NR] = $0; url[NR] = $1; lab[NR] = $2; if (!($2 in isph)) other[$1] = 1 }
    END { for (i = 1; i <= NR; i++) if (!(lab[i] in isph && other[url[i]])) print line[i] }
  ' "$tmp/$v.src" > "$tmp/$v.src2" && mv "$tmp/$v.src2" "$tmp/$v.src"
  awk -F'\t' -v v="$v" '
    { n[$1]++; src[$1] = src[$1] " " $2 }
    END { for (u in n) { if (n[u] > 1) print "A1 FAIL " v ": " u " is published by:" src[u] > "/dev/stderr"; print u } }
  ' "$tmp/$v.src" 2> "$tmp/$v.a1" | sort > "$tmp/$v.want"
  if [ -s "$tmp/$v.a1" ]; then cat "$tmp/$v.a1"; rc=1; fi
  if [ "$mode" != post ]; then
    echo "$v: $(wc -l < "$tmp/$v.want" | tr -d ' ') pages expected"
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

  mkdir -p "$CHECK_DIR/$v"
  for nav in "docs nav-order.txt" "docs/reference nav-order-reference.txt"; do
    home="$PUBLIC/$v/${nav% *}/index.html"; navf="$CHECK_DIR/$v/${nav#* }"
    if [ -f "$home" ]; then
      tr '\n' ' ' < "$home" | sed -n 's#.*<aside[^>]*hextra-sidebar-container##p' | sed 's#</aside>.*##' |
        grep -oE 'href="?[^" >]+' | sed -E 's#^href="?##' | grep '^/' |
        awk -v B="$BASE_PATH" 'B != "" && index($0, B "/") == 1 { $0 = substr($0, length(B) + 1) } { print }' > "$navf" || true
    else
      : > "$navf"
    fi
  done
  echo "$v: $(wc -l < "$tmp/$v.want" | tr -d ' ') pages expected, $(wc -l < "$tmp/$v.have" | tr -d ' ') built, $(wc -l < "$CHECK_DIR/$v/nav-order.txt" | tr -d ' ') docs and $(wc -l < "$CHECK_DIR/$v/nav-order-reference.txt" | tr -d ' ') reference sidebar links in $CHECK_DIR/$v/"
done

if [ "$mode" = post ]; then
  E=$PUBLIC/enhancements
  if [ -n "${ENH_TREE:-}" ]; then
    {
      echo /enhancements/
      if [ -f "$ENH_TREE/GRAPH.md" ]; then echo /enhancements/graph/; fi
      for c in "$ENH_TREE"/[0-9][0-9][0-9][0-9]/config.yaml "$ENH_TREE"/archive/[0-9][0-9][0-9][0-9]/config.yaml; do
        [ -f "$c" ] || continue
        id=${c%/config.yaml}; id=${id##*/}
        [ "$id" != 0000 ] || continue
        echo "/enhancements/$id/"
        for d in problem design decisions graduation risks operational questions; do echo "/enhancements/$id/$d/"; done
      done
    } | sort > "$tmp/enh.want"
    if [ -d "$E" ]; then
      (cd "$PUBLIC" && find enhancements -type f -name index.html ! -path 'enhancements/pagefind/*') | sed 's|^|/|; s|index\.html$||' | sort > "$tmp/enh.have"
    else
      : > "$tmp/enh.have"
    fi
    missing=$(comm -23 "$tmp/enh.want" "$tmp/enh.have")
    extra=$(comm -13 "$tmp/enh.want" "$tmp/enh.have")
    if [ -n "$missing" ]; then rc=1; echo "Q2 FAIL enhancements: no page built for:"; echo "$missing" | sed 's/^/  /'; fi
    if [ -n "$extra" ]; then rc=1; echo "Q2 FAIL enhancements: unexpected pages:"; echo "$extra" | sed 's/^/  /'; fi
    stray=""
    [ ! -d "$E" ] || stray=$( (cd "$PUBLIC" && find enhancements -type f ! -path 'enhancements/pagefind/*') | sort | while IFS= read -r f; do
      case "$f" in
        */index.html) ;;
        */index.md) grep -qxF "/${f%index.md}" "$tmp/enh.have" || echo "$f" ;;
        *) echo "$f" ;;
      esac
    done)
    if [ -n "$stray" ]; then rc=1; echo "STRAY FAIL enhancements: files that are no known output:"; echo "$stray" | sed 's/^/  /'; fi
    echo "enhancements: $(wc -l < "$tmp/enh.want" | tr -d ' ') pages expected, $(wc -l < "$tmp/enh.have" | tr -d ' ') built"
  elif [ -e "$E" ]; then
    rc=1; echo "Q2 FAIL enhancements: $E exists, but the build has no enhancements section"
  fi

  # The Catalogs section (CAT_DIR set: data/opm/catalogs.json lists its
  # bundles): the /catalogs/ page and, per segment, every page its
  # manifest.json lists, at <root><segment>/<page URL>/ (docs-kit C8);
  # besides each page's index.html and index.md only the segments' Pagefind
  # bundles. Without CAT_DIR, public/catalogs/ must not exist.
  K=$PUBLIC/catalogs
  if [ -n "${CAT_DIR:-}" ]; then
    {
      echo /catalogs/
      jq -r '.catalogs[] | .root as $r | .segments[] | "\($r)\t\(.segment)\t\(.dir)"' data/opm/catalogs.json |
        while IFS='	' read -r croot seg dir; do
          jq -r '.pages[].path' "$CAT_DIR/$dir/manifest.json" | sed -E 's#(^|/)_index\.md$#\1#; s#\.md$#/#' | sed "s#^#$croot$seg/#"
        done
    } | sort > "$tmp/cat.want"
    # The alias stubs (custom/head-end.html): "<stub>\t<target>", for every
    # page of the newest minor of each major, and the tab root.
    jq -r '.catalogs[] | .root as $r | .newest as $n | .segments[] | select(.indexed) | "\($r)\t\(.segment)\t\(.major)\t\(.dir)\t\(.segment == $n)"' data/opm/catalogs.json |
      while IFS='	' read -r croot seg major dir newest; do
        [ "$newest" != true ] || printf '%s\t%s\n' "$croot" "$croot$seg/"
        jq -r '.pages[].path' "$CAT_DIR/$dir/manifest.json" | sed -E 's#(^|/)_index\.md$#\1#; s#\.md$#/#' |
          awk -v R="$croot" -v S="$seg" -v M="$major" '{ printf "%s%s/%s\t%s%s/%s\n", R, M, $0, R, S, $0 }'
      done | sort > "$tmp/cat.stubs"
    cut -f1 "$tmp/cat.stubs" > "$tmp/cat.stubs.urls"
    if [ -d "$K" ]; then
      (cd "$PUBLIC" && find catalogs -type f -name index.html ! -path '*/pagefind/*') | sed 's|^|/|; s|index\.html$||' | sort > "$tmp/cat.have"
    else
      : > "$tmp/cat.have"
    fi
    missing=$(comm -23 "$tmp/cat.want" "$tmp/cat.have")
    sort -u "$tmp/cat.want" "$tmp/cat.stubs.urls" > "$tmp/cat.all"
    extra=$(comm -13 "$tmp/cat.all" "$tmp/cat.have")
    if [ -n "$missing" ]; then rc=1; echo "Q2 FAIL catalogs: no page built for:"; echo "$missing" | sed 's/^/  /'; fi
    if [ -n "$extra" ]; then rc=1; echo "Q2 FAIL catalogs: unexpected pages:"; echo "$extra" | sed 's/^/  /'; fi
    stubs=$(while IFS='	' read -r u to; do
      f="$PUBLIC${u}index.html"
      if [ ! -f "$f" ]; then echo "  $u: no stub"; continue; fi
      got=$(grep -oE 'url=[^"> ]+' "$f" | head -n 1 | cut -c5-)
      [ "$got" = "$BASE_PATH$to" ] || echo "  $u: refreshes to ${got:-nothing}, not $BASE_PATH$to"
      grep -q 'content="\{0,1\}noindex' "$f" || echo "  $u: no robots noindex"
    done < "$tmp/cat.stubs")
    if [ -n "$stubs" ]; then rc=1; echo "REDIRECT FAIL catalogs: alias stubs:"; echo "$stubs"; fi
    stray=""
    [ ! -d "$K" ] || stray=$( (cd "$PUBLIC" && find catalogs -type f) | sort | while IFS= read -r f; do
      case "$f" in
        */pagefind/*) jq -e --arg d "${f%%/pagefind/*}" '[.catalogs[] | .root as $r | .segments[] | ($r + .segment)] | index("/" + $d) != null' data/opm/catalogs.json >/dev/null || echo "$f" ;;
        */index.html) ;;
        */index.md) grep -qxF "/${f%index.md}" "$tmp/cat.have" || echo "$f" ;;
        *) echo "$f" ;;
      esac
    done)
    if [ -n "$stray" ]; then rc=1; echo "STRAY FAIL catalogs: files that are no known output:"; echo "$stray" | sed 's/^/  /'; fi
    # nav-order-catalogs-<segment>.txt: the sidebar's links on each
    # segment's landing, as for the docs home.
    mkdir -p "$CHECK_DIR/catalogs"
    jq -r '.catalogs[] | .root as $r | .segments[] | "\($r)\t\(.segment)"' data/opm/catalogs.json | while IFS='	' read -r croot seg; do
      home="$PUBLIC${croot}$seg/index.html"; navf="$CHECK_DIR/catalogs/nav-order-catalogs-$seg.txt"
      if [ -f "$home" ]; then
        tr '\n' ' ' < "$home" | sed -n 's#.*<aside[^>]*hextra-sidebar-container##p' | sed 's#</aside>.*##' |
          grep -oE 'href="?[^" >]+' | sed -E 's#^href="?##' | grep '^/' |
          awk -v B="$BASE_PATH" 'B != "" && index($0, B "/") == 1 { $0 = substr($0, length(B) + 1) } { print }' > "$navf" || true
      else
        : > "$navf"
      fi
    done
    echo "catalogs: $(wc -l < "$tmp/cat.want" | tr -d ' ') pages and $(wc -l < "$tmp/cat.stubs" | tr -d ' ') alias stubs expected, $(wc -l < "$tmp/cat.have" | tr -d ' ') built, sidebar order in $CHECK_DIR/catalogs/"
  elif [ -e "$K" ]; then
    rc=1; echo "Q2 FAIL catalogs: $K exists, but the build has no catalogs section"
  fi

  # Each extractor prints "<file>\t<kind>\t<url>": kind "root" is a
  # root-relative URL as written; "site" a relative CSS url() resolved to a
  # site-root path; "up" a relative one that climbs above public/.
  # shellcheck disable=SC2016 # awk programs, not shell expansions
  css_urls='
    # every url() in the CSS text s, unquoted, passed to found()
    function css_urls(s,  u, q, i) {
      while (match(s, /[Uu][Rr][Ll][(][ \t]*/)) {
        s = substr(s, RSTART + RLENGTH); u = s; q = substr(u, 1, 1)
        if (q == "\"" || q == Q) { u = substr(u, 2); i = index(u, q); if (i) u = substr(u, 1, i - 1) }
        else sub(/[ \t)].*$/, "", u)
        found(u)
      }
    }'
  find "$PUBLIC" -type f -name '*.html' ! -path "$PUBLIC/*/pagefind/*" | sort | while IFS= read -r f; do
    tr '\n' ' ' < "$f" | awk -v F="${f#"$PUBLIC"/}" -v Q="'" "$css_urls"'
      function found(u) {
        sub(/^[ \t]+/, "", u); sub(/[ \t]+$/, "", u)
        if (u ~ /^\// && u !~ /^\/\//) print F "\troot\t" u
      }
      function unent(s) {
        gsub(/&quot;|&#34;|&#x22;/, "\"", s); gsub(/&#39;|&#x27;|&apos;/, Q, s); return s
      }
      {
        s = $0
        re = "[ \t](href|src|data-url|srcset|poster|data|xlink:href|style)=(\"[^\"]*\"|" Q "[^" Q "]*" Q "|[^ \t>\"" Q "]+)"
        while (match(s, re)) {
          a = substr(s, RSTART + 1, RLENGTH - 1); s = substr(s, RSTART + RLENGTH)
          name = a; sub(/=.*/, "", name); v = a; sub(/^[^=]*=/, "", v)
          q = substr(v, 1, 1); if (q == "\"" || q == Q) v = substr(v, 2, length(v) - 2)
          if (name == "style") css_urls(unent(v))
          else if (name == "srcset") {
            n = split(v, parts, ",")
            for (i = 1; i <= n; i++) { u = parts[i]; sub(/^[ \t]+/, "", u); sub(/[ \t].*$/, "", u); found(u) }
          } else found(v)
        }
        s = $0
        while (match(s, /<style[^>]*>/)) {
          s = substr(s, RSTART + RLENGTH); i = index(s, "</style")
          css_urls(i ? substr(s, 1, i - 1) : s)
        }
      }'
  done > "$tmp/links"
  find "$PUBLIC" -type f -name '*.css' ! -path "$PUBLIC/*/pagefind/*" | sort | while IFS= read -r f; do
    rel=${f#"$PUBLIC"/}; dir=${rel%/*}; [ "$dir" = "$rel" ] && dir=""
    tr '\n' ' ' < "$f" | awk -v F="$rel" -v D="$dir" -v Q="'" "$css_urls"'
      function found(u,  p, n, seg, k, i, out) {
        sub(/^[ \t]+/, "", u); sub(/[ \t]+$/, "", u)
        if (u == "" || u ~ /^(#|\/\/|[A-Za-z][A-Za-z0-9+.-]*:)/) return
        if (u ~ /^\//) { print F "\troot\t" u; return }
        p = u; sub(/[?#].*$/, "", p); p = (D == "" ? p : D "/" p)
        n = split(p, seg, "/"); k = 0
        for (i = 1; i <= n; i++) {
          if (seg[i] == "" || seg[i] == ".") continue
          if (seg[i] == "..") { if (k == 0) { print F "\tup\t" u; return } k--; continue }
          out[++k] = seg[i]
        }
        p = ""; for (i = 1; i <= k; i++) p = p "/" out[i]
        print F "\tsite\t" (p == "" ? "/" : p)
      }
      { css_urls($0) }'
  done >> "$tmp/links"
  bad=$(awk -F'\t' '!(($2 FS $3) in seen) { seen[$2 FS $3] = 1; print $2 "\t" $3 "\t" $1 }' "$tmp/links" | while IFS='	' read -r kind u from; do
    p=${u%%#*}; p=${p%%\?*}
    case "$kind" in
      up) echo "  $u (in $from): climbs above the site root"; continue ;;
      root)
        if [ -n "$BASE_PATH" ]; then
          case "$p" in
            "$BASE_PATH") p=/ ;;
            "$BASE_PATH"/*) p=${p#"$BASE_PATH"} ;;
            *) echo "  $u (in $from): outside the base path $BASE_PATH"; continue ;;
          esac
        fi ;;
    esac
    case "$p" in
      */) [ -f "$PUBLIC${p}index.html" ] && continue ;;
      *) { [ -f "$PUBLIC$p" ] || [ -f "$PUBLIC$p/index.html" ]; } && continue ;;
    esac
    echo "  $u (in $from)"
  done)
  # Under a path, an absolute URL on the base URL's own host must stay inside
  # the base URL, in every published text file. Compared with index(), never
  # as a regex built from the URL.
  abs=""
  if [ -n "$BASE_PATH" ]; then
    host=${BASE_URL#*://}; host=${host%%/*}; scheme=${BASE_URL%%://*}
    abs=$(find "$PUBLIC" -type f \( -name '*.html' -o -name '*.xml' -o -name '*.txt' -o -name '*.md' -o -name '*.json' -o -name '*.webmanifest' \) ! -path "$PUBLIC/*/pagefind/*" | sort | while IFS= read -r f; do
      grep -oE '(https?:)?//[^][:space:]"<>(){}\\`'"'"'[]+' "$f" | awk -v F="${f#"$PUBLIC"/}" '{ print F "\t" $0 }' || true
    done | awk -F'\t' -v B="$BASE_URL" -v H="$host" -v S="$scheme" '
      {
        u = $2; a = (u ~ /^\/\//) ? S ":" u : u
        h = a; sub(/^[A-Za-z]+:\/\//, "", h); sub(/[\/?#].*$/, "", h)
        if (tolower(h) != tolower(H) || index(a, B) == 1 || (u in seen)) next
        seen[u] = 1; print "  " u " (in " $1 "): outside the base URL " B
      }')
  fi
  if [ -n "$bad$abs" ]; then
    rc=1; echo "LINK FAIL: published pages link to URLs nothing serves:"
    printf '%s\n%s\n' "$bad" "$abs" | sed '/^$/d'
  fi
  echo "links: $(cut -f3 "$tmp/links" | sort -u | wc -l | tr -d ' ') distinct URLs in $(cut -f1 "$tmp/links" | sort -u | wc -l | tr -d ' ') HTML and CSS files${BASE_PATH:+ under $BASE_PATH}$( [ -z "$bad$abs" ] && echo ', all resolve')"
fi
if [ $rc -eq 0 ]; then echo "check-pages ($mode): OK"; else echo "check-pages ($mode): FAILED"; fi
exit $rc
