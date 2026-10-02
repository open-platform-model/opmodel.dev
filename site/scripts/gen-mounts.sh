#!/bin/sh
# Writes the Hugo module mounts and the versions config for a set of versions.
#
#   gen-mounts.sh OUT VERSION=ROOT [VERSION=ROOT ...]    (OUT relative to SITE_DIR)
#
# Each ROOT holds <repo>/docs/site for the six source repos (a source = main
# version passes /src, an anchored or a line one its archive in
# .versions/<version>).
# The site-owned content/ is mounted once, for every version; each repo's
# docs/site/ is mounted at content/docs for its own version. Version names are
# listed exactly: in a version glob, * does not cross ".". There is no file
# filter and no index.md remap: the source lint has already rejected every
# form Hugo would misread. A version's generated reference, when
# SITE_DIR/.gen/<version>/ exists, is mounted at content for that version (its
# tree starts at docs/reference/...).
#
# Beside OUT (config/<env>/module.toml) it writes config/<env>/hugo.toml: the
# default version, each version's weight and its label (params.opm.versions,
# in weight order). They come from .versions/versions.tsv (site/versions.conf,
# resolved on the host) unless OPM_VERSIONS is set; then, and with no
# versions.tsv, the label is the name, the weight the position, and the first
# version is the default.
#
# The enhancements section, when ENH_TREE names its tree (build-all.sh and
# serve.sh set it; the README "Site versions" and site/enhancements/ say why it
# belongs to no version): the tree is mounted at assets/enhancements, where the
# content adapter site/enhancements/_content.gotmpl reads it, and the adapter
# with the section page at content/enhancements, both into the default version
# only, so the section publishes once and keeps its URLs when the default
# version changes. A content adapter cannot add the section page itself (the
# empty path is the home page's), so this writes it, .gen/enhancements/_index.md:
# front matter, then INDEX.md without its HTML comments and its title line.
# Beside it, data/opm/enhancements.json lists every path of the repository
# ("blob" or "tree"), for the section's link hook: in manifest mode from
# materialise.sh's paths.txt (git ls-tree at the built SHA), in explicit mode
# from the tree read in place. The hugo.toml written below gains the
# Enhancements menu entry, so the tab exists only in a build with the section.
# Hugo cannot merge a slice across config directories, so an environment's
# menus.main replaces _default's whole: the entry is written together with a
# copy of _default's [menus] block (the last table of config/_default/hugo.toml,
# which stays the one place the other entries are written).
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
REPOS="opm core catalog_opm cli library opm-operator"
cd "$SITE_DIR"
out=$1; shift

names=""
for pair in "$@"; do names="$names${names:+, }\"${pair%%=*}\""; done

# The versions config: "<name>\t<label>\t<weight>\t<default>" per version.
if [ -z "${OPM_VERSIONS:-}" ] && [ -f .versions/versions.tsv ]; then
  list=$(for pair in "$@"; do
    awk -F'\t' -v v="${pair%%=*}" '!/^#/ && $1 == v { print $1 "\t" $2 "\t" $3 "\t" $4; exit }' .versions/versions.tsv
  done)
else
  list=$(n=0; for pair in "$@"; do n=$((n + 1)); v=${pair%%=*}; printf '%s\t%s\t%s\t%s\n' "$v" "$v" "$n" "$([ $n = 1 ] && echo true || echo false)"; done)
fi
def=$(printf '%s\n' "$list" | awk -F'\t' 'NF == 4 && $4 == "true" { print $1; exit }')
[ -n "$def" ] || { echo "gen-mounts: no versions, or no default version" >&2; exit 1; }

# The enhancements section's generated inputs (see the header).
ENH_TREE=${ENH_TREE:-}
rm -rf .gen/enhancements data/opm/enhancements.json
if [ -n "$ENH_TREE" ]; then
  [ -f "$ENH_TREE/INDEX.md" ] || { echo "gen-mounts: ENH_TREE $ENH_TREE holds no INDEX.md" >&2; exit 1; }
  mkdir -p .gen/enhancements data/opm
  updated=$(cat "$ENH_TREE"/[0-9][0-9][0-9][0-9]/config.yaml "$ENH_TREE"/archive/[0-9][0-9][0-9][0-9]/config.yaml 2>/dev/null |
    sed -n 's/^updated:[[:space:]]*"\{0,1\}\([0-9-]*\)"\{0,1\}[[:space:]]*$/\1/p' | sort | tail -n 1)
  {
    printf -- '---\ntitle: Enhancements\n'
    printf 'description: The design record of OPM, every enhancement proposal, open and closed, with its status.\n'
    printf 'url: /enhancements/\n'
    [ -z "$updated" ] || printf 'lastmod: %s\n' "$updated"
    printf 'params:\n  repoPath: INDEX.md\n  llms: false\n  cards: false\n---\n'
    # INDEX.md without HTML comments and its first heading; a shortcode
    # delimiter fails here, as the adapter fails one in an entry.
    awk 'BEGIN { RS = "\001" }
      {
        s = $0; out = ""
        if (index(s, "{{<") || index(s, "{{%")) { print "gen-mounts: INDEX.md holds a Hugo shortcode delimiter ({{< or {{%)" > "/dev/stderr"; bad = 1; exit 1 }
        while ((i = index(s, "<!--")) > 0) {
          out = out substr(s, 1, i - 1); s = substr(s, i + 4)
          j = index(s, "-->"); if (j == 0) { print "gen-mounts: INDEX.md holds an unclosed <!--" > "/dev/stderr"; bad = 1; exit 1 }
          s = substr(s, j + 3)
        }
        out = out s
        sub(/^[ \t\n]*# [^\n]*\n/, "", out)
        printf "%s", out
      }' "$ENH_TREE/INDEX.md"
  } > .gen/enhancements/_index.md
  # Every path of the repository, "blob" or "tree".
  if [ -f "${ENH_PATHS:-}" ]; then
    cat "$ENH_PATHS"
  else
    (cd "$ENH_TREE" && { find . -mindepth 1 -type d | sed 's/^/tree /'; find . -type f | sed 's/^/blob /'; }) |
      awk '{ t = $1; p = substr($0, 8); if (p !~ /^\.git(\/|$)/) print t "\t" p }'
  fi | awk -F'\t' '
    $2 ~ /["\\]/ { print "gen-mounts: an enhancements path holds a quote or a backslash: " $2 > "/dev/stderr"; bad = 1; exit 1 }
    NF == 2 { printf "%s\n    \"%s\": \"%s\"", (n++ ? "," : "{\"paths\": {"), $2, $1 }
    END { if (!bad) printf "\n}}\n" }' > data/opm/enhancements.json
  echo "gen-mounts: wrote .gen/enhancements/_index.md and data/opm/enhancements.json ($(grep -c '": "' data/opm/enhancements.json | tr -d ' ') paths) for the enhancements section"
fi

mkdir -p "$(dirname "$out")"
{
  echo '# Generated by scripts/gen-mounts.sh from the version list. Do not edit.'
  for d in layouts assets static data i18n archetypes; do
    [ -d "$d" ] || continue
    printf '[[mounts]]\n  source = "%s"\n  target = "%s"\n' "$d" "$d"
  done
  printf '[[mounts]]\n  source = "content"\n  target = "content"\n  [mounts.sites.matrix]\n    versions = [%s]\n' "$names"
  if [ -n "$ENH_TREE" ]; then
    # Only the files the section publishes, so a tree read in place (its .git,
    # experiments and research included) adds nothing else to the build.
    printf '[[mounts]]\n  source = "%s"\n  target = "assets/enhancements"\n  files = [%s]\n' "$ENH_TREE" \
      "'INDEX.md', 'GRAPH.md', '[0-9][0-9][0-9][0-9]/{config.yaml,README.md,0[1-7]-*.md}', 'archive/[0-9][0-9][0-9][0-9]/{config.yaml,README.md,0[1-7]-*.md}'"
    for d in enhancements .gen/enhancements; do
      printf '[[mounts]]\n  source = "%s"\n  target = "content/enhancements"\n  [mounts.sites.matrix]\n    versions = ["%s"]\n' "$d" "$def"
    done
  fi
  for pair in "$@"; do
    v=${pair%%=*}; root=${pair#*=}
    if [ -d ".gen/$v" ]; then
      printf '[[mounts]]\n  source = ".gen/%s"\n  target = "content"\n  [mounts.sites.matrix]\n    versions = ["%s"]\n' "$v" "$v"
    fi
    for r in $REPOS; do
      [ -d "$root/$r/docs/site" ] || { echo "gen-mounts: $root/$r/docs/site is missing (version $v)" >&2; exit 1; }
      printf '[[mounts]]\n  source = "%s/%s/docs/site"\n  target = "content/docs"\n  [mounts.sites.matrix]\n    versions = ["%s"]\n' "$root" "$r" "$v"
    done
  done
} > "$out"
echo "gen-mounts: wrote $out ($(grep -c '^\[\[mounts\]\]' "$out") mounts, versions $names${ENH_TREE:+, the enhancements section in $def})"

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
if [ -n "$ENH_TREE" ]; then
  awk '/^\[menus\]/ { on = 1 } on && /^\[/ && !/^\[menus\]/ && !/^\[\[menus\./ { on = 0 } on' config/_default/hugo.toml | grep . ||
    { echo "gen-mounts: config/_default/hugo.toml has no [menus] table to copy" >&2; exit 1; }
  printf "  [[menus.main]]\n    name = 'Enhancements'\n    pageRef = '/enhancements/'\n    weight = 3\n"
fi
} > "$cfg"
echo "gen-mounts: wrote $cfg (default $(sed -n "s/^defaultContentVersion = '\(.*\)'$/\1/p" "$cfg")${ENH_TREE:+, the Enhancements tab})"
