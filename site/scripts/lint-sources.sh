#!/bin/sh
# opm-dialect-lint: check source pages against the OPM page dialect
# (orchestration.md, "Dialect contract"). POSIX sh and awk, plus find, grep -E,
# sort and mktemp (GNU, BSD and busybox all work). Runs on the host and in Alpine.
#
#   sh opm-dialect-lint.sh DIR [DIR ...]    lint each docs/site tree; exit 0 clean, 1 violations
#
# Every violation prints as "<file>:<line>: <message>".
set -u
export LC_ALL=C
FIGURES="module-to-cluster roles-and-artifacts component-to-objects where-things-live three-ways-to-deploy helm-and-opm one-trait-any-provider"

[ $# -ge 1 ] || { echo "usage: $0 DIR [DIR ...]" >&2; exit 2; }

out=$(mktemp); trap 'rm -f "$out" "$out.files"' EXIT
for dir in "$@"; do
  [ -d "$dir" ] || { echo "$dir: not a directory" >> "$out"; continue; }
  find "$dir" \( -type f -o -type l \) | sort > "$out.files"
  while IFS= read -r f; do
    rel=${f#"$dir"/}
    if [ -L "$f" ]; then echo "$f:0: symlink; a page must be a regular file" >> "$out"; continue; fi
    case "$rel" in
      *.mdx) echo "$f:0: MDX file; rename to .md and replace components with {{< opm/... >}} shortcodes" >> "$out"; continue ;;
      index.md|*/index.md) echo "$f:0: index.md is a leaf bundle in Hugo; a section page is _index.md" >> "$out" ;;
      *.md) ;;
      *) echo "$f:0: not a page; docs/site holds only .md files (no images or data)" >> "$out"; continue ;;
    esac
    if ! printf '%s\n' "$rel" | grep -Eq '^([a-z0-9]+(-[a-z0-9]+)*/)*(_index|index|[a-z0-9]+(-[a-z0-9]+)*)\.md$'; then
      echo "$f:0: file and directory names are lower-case kebab-case (a-z, 0-9, -)" >> "$out"
    fi
    case "$rel" in _index.md|*/_index.md|index.md|*/index.md) leaf=0 ;; *) leaf=1 ;; esac
    awk -v F="$f" -v LEAF="$leaf" -v FIGS=" $FIGURES " -v Q="'" '
      function err(l, m) { printf "%s:%d: %s\n", F, l, m }
      function unq(s,  a, z) { sub(/[ \t]+#.*$/, "", s); sub(/[ \t]+$/, "", s)
                        a = substr(s, 1, 1); z = substr(s, length(s), 1)
                        if (length(s) >= 2 && a == z && (a == "\"" || a == Q)) s = substr(s, 2, length(s) - 2); return s }
      function dest(t) {
        if (t ~ /^(https?:|mailto:|#)/) return
        if (t ~ /^\/docs\//) { if (t !~ /^\/docs\/([a-z0-9-]+\/)*(#[^ ]*)?$/) err(NR, "internal link \"" t "\": write /docs/<section>/<page>/ with a trailing slash"); return }
        if (t ~ /^\/enhancements([\/#]|$)/) { if (t !~ /^\/enhancements\/([0-9][0-9][0-9][0-9]\/((problem|design|decisions|graduation|risks|operational|questions)\/)?)?(#[^ ]*)?$/) err(NR, "enhancement link \"" t "\": write /enhancements/, /enhancements/<NNNN>/ or /enhancements/<NNNN>/<document>/ with a trailing slash"); return }
        err(NR, "link \"" t "\": internal links are root-absolute /docs/<section>/<page>/ or /enhancements/<NNNN>/ (no relative, .md or version-prefixed links)")
      }
      NR == 1 { if ($0 != "---") { err(1, "front matter must open on line 1 with ---"); nofm = 1 } else { infm = 1; next } }
      infm {
        if ($0 ~ /^---[ \t]*$/) { infm = 0; fmdone = 1; next }
        if ($0 ~ /^[A-Za-z_][A-Za-z0-9_-]*:/) {
          k = $0; sub(/:.*/, "", k); v = $0; sub(/^[^:]*:[ \t]*/, "", v)
          line[k] = NR; val[k] = v
          if (k == "sidebar") err(NR, "sidebar: is Starlight front matter; write weight: N")
          else if (k !~ /^(title|description|type|weight)$/) err(NR, "front-matter key \"" k "\" is not allowed (title, description, type, weight)")
        } else if ($0 !~ /^[ \t]/ && $0 !~ /^#/ && $0 != "") err(NR, "front matter: expected \"key: value\"")
        next
      }
      {
        # Shortcodes are expanded even inside code fences, so check every line.
        s = $0
        while (match(s, /[{][{][<%][ \t]*\/?[ \t]*[^ \t>%}]*/)) {
          tok = substr(s, RSTART, RLENGTH); rest = substr(s, RSTART + RLENGTH); s = rest
          if (tok ~ /^[{][{][<%][ \t]*\/[*]/) continue
          name = tok; sub(/^[{][{][<%][ \t]*\/?[ \t]*/, "", name)
          if (name !~ /^opm\//) { err(NR, "shortcode \"" name "\": source pages use only {{< opm/<figure> >}}"); continue }
          fig = substr(name, 5)
          if (index(FIGS, " " fig " ") == 0) { err(NR, "unknown figure shortcode \"" name "\""); continue }
          if (tok !~ /^[{][{]<[ \t]*opm/ || rest !~ /^[ \t]*>[}][}]/) err(NR, "write the figure as {{< " name " >}} (no parameters, no closing tag)")
        }
      }
      # O4: any ::: line and any import ... from line fails, inside code fences too.
      /^[ \t]*:::/ { err(NR, "Starlight aside (:::); write a GitHub alert: > [!NOTE]") }
      /^[ \t]*import[ \t].*[ \t]from[ \t]/ { err(NR, "MDX import line") }
      /^ ? ? ?(```|~~~)/ {
        m = $0; sub(/^ */, "", m); c = substr(m, 1, 3)
        if (fence == "") {
          fence = c; tag = m; sub(/^[`~]*[ \t]*/, "", tag)
          if (tag == "") err(NR, "code fence without a language tag; write ```text for plain text")
          next
        } else if (c == fence) { fence = ""; next }
      }
      fence != "" { next }
      /^[ \t]*<[A-Z][A-Za-z0-9]*([ \t][^>]*)?\/?>[ \t]*$/ { err(NR, "component tag; use {{< opm/<figure> >}}") }
      /^[ \t]*>[ \t]*\[!/ {
        if ($0 !~ /^> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]$/) err(NR, "alert marker must be exactly \"> [!NOTE]\" (or TIP, IMPORTANT, WARNING, CAUTION) alone on its line")
      }
      /!\[/ || /<[Ii][Mm][Gg][ \t>\/]/ { err(NR, "image; docs/site pages carry no images") }
      /[Hh][Rr][Ee][Ff][ \t]*=|[Ss][Rr][Cc][ \t]*=/ { err(NR, "raw HTML link or source; write a Markdown link [text](/docs/<section>/<page>/)") }
      /^ ? ? ?\[[^]^][^]]*\]:/ {
        t = $0; sub(/^ ? ? ?\[[^]]+\]:[ \t]*/, "", t); sub(/[ \t].*$/, "", t); sub(/^</, "", t); sub(/>$/, "", t)
        if (t != "") dest(t)
      }
      {
        s = $0
        while (match(s, /[]][(][^) \t]*/)) {
          t = substr(s, RSTART + 2, RLENGTH - 2); s = substr(s, RSTART + RLENGTH)
          dest(t)
        }
      }
      END {
        if (nofm) exit
        if (!fmdone) { err(1, "front matter is not closed with ---"); exit }
        if (!("title" in val) || unq(val["title"]) == "") err(1, "missing title")
        if (!("description" in val) || unq(val["description"]) == "") err(1, "missing description")
        if (LEAF == 1) {
          if (!("type" in val)) err(1, "missing type (tutorial, how-to, explanation or reference)")
          else { t = unq(val["type"]); if (t !~ /^(tutorial|how-to|explanation|reference)$/) err(line["type"], "invalid type \"" t "\"") }
        } else if ("type" in val) err(line["type"], "a section overview (_index.md) declares no type")
        if ("weight" in val) { w = unq(val["weight"]); if (w !~ /^[1-9][0-9]*$/) err(line["weight"], "weight must be a positive integer") }
      }' "$f" >> "$out"
  done < "$out.files"
  rm -f "$out.files"
done
if [ -s "$out" ]; then
  cat "$out"; echo "opm-dialect-lint: $(wc -l < "$out" | tr -d ' ') violation(s)"; exit 1
fi
echo "opm-dialect-lint: OK ($*)"
