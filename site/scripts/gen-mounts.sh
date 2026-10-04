#!/bin/sh
# Writes the Hugo module mounts and the versions config for the site versions.
#
#   gen-mounts.sh OUT VERSION [VERSION ...]    (OUT relative to SITE_DIR; reads CAT_DIR)
#
# The site-owned content/ is mounted once, for every version. Every page of a
# version outside content/ comes from a docs bundle (data/opm/docs-bundles.json,
# written by gen-docs-bundles.sh from the lock's "docs" key; docs-kit C16):
# each bundle's <CAT_DIR>/<dir>/content is mounted at content/docs for its
# version, read-only. Version names are listed exactly: in a version glob, *
# does not cross ".". There is no file filter and no index.md remap: opm-docs
# pull linted every bundle page against the dialect, which rejects every form
# Hugo would misread. The catalogs mount below matches only
# <project>/<segment>/ (a * does not cross /), so the tab adapter never sees
# _versions/<v>/<project>/.
#
# Beside OUT (config/<env>/module.toml) it writes config/<env>/hugo.toml: the
# default version, each version's weight and its label (params.opm.versions,
# in weight order), from .gen/versions.tsv (sections.sh, from versions.conf).
#
# The enhancements section, when ENH_DIR names its section bundle
# (sections.sh, from the lock entry rooted at /enhancements/; docs-kit C21):
# the bundle's files are already under assets/bundles (the catalogs mount
# below matches <project>/<segment>/), where the content adapter
# site/enhancements/_content.gotmpl reads them; the adapter and the section
# page go to content/enhancements in the default version only, so the
# section publishes once and keeps its URLs when the default version
# changes. A content adapter cannot add the section page itself (the empty
# path is the home page's), so this writes it, .gen/enhancements/_index.md:
# the bundle's content/_index.md with url, lastmod (the newest entry's
# updated date) and the section's params added to its front matter. It
# checks the bundle first, failing the build naming the file: placement
# section at /enhancements/, project and commit as the lock says, content/
# holding exactly the pages manifest.json lists, data/enhancements.json of
# schema docs.opmodel.dev/data/enhancements/v1, and a data entry for every
# entry page (content/<NNNN>/...). The hugo.toml written below gains the
# Enhancements menu entry, so the tab exists only in a build with the
# section. Hugo cannot merge a slice across config directories, so an
# environment's menus.main replaces _default's whole: the entry is written
# together with a copy of _default's [menus] block (the last table of
# config/_default/hugo.toml, which stays the one place the other entries
# are written).
#
# The Catalogs section, when CATALOGS is set (sections.sh: the lock names a
# tab bundle; gen-catalogs.sh has written data/opm/catalogs.json from it): the
# bundles are mounted at assets/bundles (always: the enhancements adapter
# reads its bundle there too), only manifest.json, content/ and
# data/*.json of each <project>/<segment>/, and each <project>/history.json
# (docs-kit C13; read only when the lock records it) (all of content/, so the adapter
# sees, and refuses, a file there that is no listed page; a narrower glob
# hides nested directories from resources.Match), where the content adapter
# site/catalogs/_content.gotmpl reads them; the adapter and the section page
# gen-catalogs.sh wrote (.gen/catalogs/_index.md) go to content/catalogs in
# the default version only, as for the enhancements section. The hugo.toml
# below gains the Catalogs menu entry (weight 3, before Enhancements at 4), so
# the tab exists only in a build with the section.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$SITE_DIR"
out=$1; shift

names=""
for v in "$@"; do names="$names${names:+, }\"$v\""; done

# The versions config: "<name>\t<label>\t<weight>\t<default>" per version.
[ -f .gen/versions.tsv ] || { echo "gen-mounts: .gen/versions.tsv is missing (sections.sh writes it)" >&2; exit 1; }
list=$(for v in "$@"; do
  awk -F'\t' -v v="$v" '$1 == v { print; f = 1; exit } END { if (!f) exit 1 }' .gen/versions.tsv ||
    { echo "gen-mounts: .gen/versions.tsv has no version $v" >&2; exit 1; }
done) || exit 1
def=$(printf '%s\n' "$list" | awk -F'\t' 'NF == 4 && $4 == "true" { print $1; exit }')
[ -n "$def" ] || { echo "gen-mounts: no versions, or no default version" >&2; exit 1; }

# The enhancements section's generated inputs (see the header).
ENH_DIR=${ENH_DIR:-}
rm -rf .gen/enhancements data/opm/enhancements.json
if [ -n "$ENH_DIR" ]; then
  enh_fail() { echo "gen-mounts: enhancements bundle ($ENH_HOW): $*" >&2; exit 1; }
  M=$ENH_DIR/manifest.json; D=$ENH_DIR/data/enhancements.json
  jq -e . "$M" >/dev/null 2>&1 || enh_fail "manifest.json is missing or not JSON"
  [ "$(jq -r '.placement.kind + " " + .placement.root' "$M")" = "section /enhancements/" ] ||
    enh_fail "manifest.json places the bundle as $(jq -r '.placement.kind' "$M") at \"$(jq -r '.placement.root' "$M")\", not as section at /enhancements/"
  [ "$(jq -r '.project' "$M")" = enhancements ] || enh_fail "manifest.json says project $(jq -r '.project' "$M"), not enhancements"
  [ "$(jq -r '.source.commit' "$M")" = "$ENH_SHA" ] || enh_fail "manifest.json says source.commit $(jq -r '.source.commit' "$M"), the lock says $ENH_SHA"
  have=$(cd "$ENH_DIR" && { [ ! -d content ] || find content -type f; } | sed 's#^content/##' | sort)
  want=$(jq -r '.pages[].path' "$M" | sort)
  extra=$(printf '%s\n' "$have" | grep . | grep -vxF "$want" || true)
  missing=$(printf '%s\n' "$want" | grep . | grep -vxF "$have" || true)
  [ -z "$extra" ] || enh_fail "content/ holds pages manifest.json does not list: $(printf '%s' "$extra" | tr '\n' ' ')"
  [ -z "$missing" ] || enh_fail "manifest.json lists pages content/ does not hold: $(printf '%s' "$missing" | tr '\n' ' ')"
  printf '%s\n' "$want" | grep -qxF _index.md || enh_fail "manifest.json lists no _index.md (the section page)"
  [ "$(jq -r '.schema // ""' "$D" 2>/dev/null)" = docs.opmodel.dev/data/enhancements/v1 ] ||
    enh_fail "data/enhancements.json is missing, or not docs.opmodel.dev/data/enhancements/v1"
  # Every entry page (content/<NNNN>/_index.md or <NNNN>/<document>.md) has
  # its data entry, as page or documents[].page.
  known=$(jq -r '.entries[] | .page, (.documents[]?.page)' "$D" | sort -u)
  orphans=$(printf '%s\n' "$want" | grep -E '^[0-9]{4}/' | sed -E 's#/_index\.md$##; s#\.md$##' | grep -vxF "$known" || true)
  [ -z "$orphans" ] || enh_fail "data/enhancements.json has no entry for the pages $(printf '%s' "$orphans" | tr '\n' ' ')"
  mkdir -p .gen/enhancements
  updated=$(jq -r '[.entries[].updated] | max // ""' "$D")
  src=$(jq -r '.pages[] | select(.path == "_index.md") | .source // ""' "$M")
  awk -v U="$updated" -v S="$src" '
    NR == 1 { if ($0 != "---") { bad = 1; exit 1 } print; next }
    !done && $0 == "---" {
      print "url: /enhancements/"
      if (U != "") print "lastmod: " U
      print "params:\n  llms: false\n  cards: false"
      if (S != "") print "  repoPath: " S
      print; done = 1; next
    }
    { print }
    END { if (bad || !done) exit 1 }' "$ENH_DIR/content/_index.md" > .gen/enhancements/_index.md ||
    enh_fail "content/_index.md has no front matter (--- on line 1, closed by ---)"
  echo "gen-mounts: wrote .gen/enhancements/_index.md for the enhancements section ($(printf '%s\n' "$want" | grep -c .) pages, commit $ENH_SHA)"
fi

# The docs bundles of a version: "<tree>\t<dir>" per bundle-backed repository.
DB=data/opm/docs-bundles.json
[ -f "$DB" ] || { echo "gen-mounts: $DB is missing (gen-docs-bundles.sh runs first)" >&2; exit 1; }
bundles_of() { jq -r --arg v "$1" '.versions[$v] // {} | .[] | "\(.tree)\t\(.dir)"' "$DB"; }
[ -n "${CAT_DIR:-}" ] || { echo "gen-mounts: CAT_DIR is not set (sections.sh sets it)" >&2; exit 1; }

mkdir -p "$(dirname "$out")"
{
  echo '# Generated by scripts/gen-mounts.sh from the version list. Do not edit.'
  for d in layouts assets static data i18n archetypes; do
    [ -d "$d" ] || continue
    printf '[[mounts]]\n  source = "%s"\n  target = "%s"\n' "$d" "$d"
  done
  printf '[[mounts]]\n  source = "content"\n  target = "content"\n  [mounts.sites.matrix]\n    versions = [%s]\n' "$names"
  if [ -n "$ENH_DIR" ]; then
    for d in enhancements .gen/enhancements; do
      printf '[[mounts]]\n  source = "%s"\n  target = "content/enhancements"\n  [mounts.sites.matrix]\n    versions = ["%s"]\n' "$d" "$def"
    done
  fi
  # The bundles as assets, only the files a bundle may hold, where the
  # adapters site/catalogs/_content.gotmpl and site/enhancements/_content.gotmpl
  # read them.
  printf '[[mounts]]\n  source = "%s"\n  target = "assets/bundles"\n  files = [%s]\n' "$CAT_DIR" \
    "'*/*/manifest.json', '*/*/content/**', '*/*/data/*.json', '*/history.json'"
  if [ -n "${CATALOGS:-}" ]; then
    [ -f data/opm/catalogs.json ] || { echo "gen-mounts: the build has the Catalogs section, but data/opm/catalogs.json is missing (gen-catalogs.sh runs first)" >&2; exit 1; }
    # The adapter and the section page into the default version only.
    for d in catalogs .gen/catalogs; do
      printf '[[mounts]]\n  source = "%s"\n  target = "content/catalogs"\n  [mounts.sites.matrix]\n    versions = ["%s"]\n' "$d" "$def"
    done
  fi
  for v in "$@"; do
    fromb=$(bundles_of "$v")
    [ -n "$fromb" ] || { echo "gen-mounts: $DB names no docs bundle for version $v" >&2; exit 1; }
    printf '%s\n' "$fromb" | while IFS='	' read -r r d; do
      [ -d "$CAT_DIR/$d/content" ] || { echo "gen-mounts: $CAT_DIR/$d/content is missing (version $v, $r from its docs bundle)" >&2; exit 1; }
      printf '[[mounts]]\n  source = "%s/%s/content"\n  target = "content/docs"\n  [mounts.sites.matrix]\n    versions = ["%s"]\n' "$CAT_DIR" "$d" "$v"
    done || exit 1
  done
} > "$out"
echo "gen-mounts: wrote $out ($(grep -c '^\[\[mounts\]\]' "$out") mounts, versions $names${ENH_DIR:+, the enhancements section in $def}${CATALOGS:+, the catalogs section in $def})"

cfg=$(dirname "$out")/hugo.toml
{
printf '%s\n' "$list" | awk -F'\t' -v Q="'" '
  NF == 4 { n++; name[n] = $1; label[n] = $2; weight[n] = $3; if ($4 == "true") def = $1 }
  END {
    print "# Generated by scripts/gen-mounts.sh from the version list. Do not edit."
    printf "defaultContentVersion = " Q "%s" Q "\n[versions]\n", def
    for (i = 1; i <= n; i++) printf "  [versions." Q "%s" Q "]\n    weight = %s\n", name[i], weight[i]
    for (i = 1; i <= n; i++) printf "[[params.opm.versions]]\n  name = " Q "%s" Q "\n  label = " Q "%s" Q "\n", name[i], label[i]
  }'
if [ -n "$ENH_DIR" ] || [ -n "${CATALOGS:-}" ]; then
  awk '/^\[menus\]/ { on = 1 } on && /^\[/ && !/^\[menus\]/ && !/^\[\[menus\./ { on = 0 } on' config/_default/hugo.toml | grep . ||
    { echo "gen-mounts: config/_default/hugo.toml has no [menus] table to copy" >&2; exit 1; }
  [ -z "${CATALOGS:-}" ] || printf "  [[menus.main]]\n    name = 'Catalogs'\n    pageRef = '/catalogs/'\n    weight = 3\n"
  [ -z "$ENH_DIR" ] || printf "  [[menus.main]]\n    name = 'Enhancements'\n    pageRef = '/enhancements/'\n    weight = 4\n"
fi
} > "$cfg"
echo "gen-mounts: wrote $cfg (default $(sed -n "s/^defaultContentVersion = '\(.*\)'$/\1/p" "$cfg")${CATALOGS:+, the Catalogs tab}${ENH_DIR:+, the Enhancements tab})"
