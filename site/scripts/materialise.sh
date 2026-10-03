#!/bin/sh
# materialise: the source trees and the git dates of every resolved site
# version, on the host, after resolve-versions.sh (task versions:prepare).
# git cannot read a worktree's history inside the build container, so every
# git call of the build happens here. POSIX sh, git, tar and awk.
#
#   materialise.sh    reads site/.versions/versions.tsv; with OPM_VERSIONS set (explicit mode) does nothing
#
# Writes, only under site/.versions/:
#   <v>/<repo>/docs/site/   git archive of the SHA an anchored or line version resolved,
#                           per repository (every kind but source = main, which reads
#                           the working trees); <v>/<repo>/.sha skips an archive that is
#                           already there, so a branch head that moved is archived again
#   <v>/lastmod.tsv         "<key>\t<v>\t<ISO date>" for every page of the version:
#                           <repo>/docs/site/<path> dated at the version's SHA for that
#                           repository (a source = main version: the root's HEAD), and
#                           opmodel.dev/site/content/<path> dated at this checkout's HEAD
#                           (the site-owned pages, mounted once for every version)
#   enhancements/tree/      when versions.tsv holds the "# section enhancements" line: a
#                           git archive, at the SHA it names, of only the files the
#                           section publishes (INDEX.md, GRAPH.md, and of every entry
#                           NNNN/ and archive/NNNN/ but the 0000/ template its
#                           config.yaml, README.md and seven numbered documents); not
#                           experiments, research, schemas or the gitignored diagrams/
#   enhancements/paths.txt  every file and directory of the repository at that SHA,
#                           "blob\t<path>" or "tree\t<path>", one per line: the section's link hook maps a link to a file
#                           it does not publish to GitHub at that SHA, and knows a path
#                           that names nothing
#   enhancements/.sha       the SHA archived; an archive already there is kept
# and removes the directory of a vN.N version the manifest no longer lists (and
# enhancements/ when the manifest names no section). A page that git cannot
# date (not committed yet) gets no row; gen-lastmod.sh counts it as a miss.
# The section's pages are dated from each entry's config.yaml, not from git.
set -euf
export LC_ALL=C
SCRIPTS=$(cd "$(dirname "$0")" && pwd -P)
SITE=$(cd "$SCRIPTS/.." && pwd -P)
V=$SITE/.versions
TSV=$V/versions.tsv

if [ -n "${OPM_VERSIONS:-}" ]; then
  echo "materialise: OPM_VERSIONS is set: explicit mode, nothing to materialise"
  exit 0
fi
[ -f "$TSV" ] || { echo "materialise: no $TSV; run resolve-versions.sh first" >&2; exit 1; }

# The source roots, from run-in-image.sh's own resolution, as in
# resolve-versions.sh: sourced in a subshell with mode "tag" (which only
# prints the image tag, discarded), then sources() leaves MOUNTS.
mounts=$(sh -c '. "$0" >/dev/null
  sources
  for m in $MOUNTS; do [ "$m" = -v ] || printf "%s\n" "$m"; done' "$SCRIPTS/run-in-image.sh" tag)
root_of() { printf '%s\n' "$mounts" | awk -v r="$1" '{ m = $0; sub(/:\/src\/.*/, "", m); d = $0; sub(/.*:\/src\//, "", d); sub(/:ro$/, "", d); if (d == r) print m }'; }

# dates DIR GITDIR REV PREFIX KEYPREFIX VERSION: a row per *.md under DIR, dated
# by git -C GITDIR log -1 REV -- PREFIX/<path>.
dates() {
  [ -d "$1" ] || return 0
  (cd "$1" && find . -type f -name '*.md') | sed 's|^\./||' | sort | while IFS= read -r f; do
    d=$(git -C "$2" log -1 --format=%cI "$3" -- "$4/$f" 2>/dev/null || true)
    [ -z "$d" ] || printf '%s/%s\t%s\t%s\n' "$5" "$f" "$6" "$d"
  done
}

# The site-owned pages: the same dates in every version.
site_rows=$(dates "$SITE/content" "$SITE" HEAD content opmodel.dev/site/content @)

versions=$(awk -F'\t' '/^#/ { next } !($1 in seen) { seen[$1]; print $1 "\t" $5 }' "$TSV")
archived=0; kept=0
while IFS="$(printf '\t')" read -r v kind; do
  mkdir -p "$V/$v"
  rows=$(printf '%s\n' "$site_rows" | awk -F'\t' -v v="$v" 'NF == 3 { print $1 "\t" v "\t" $3 }')
  for r in $(awk -F'\t' -v v="$v" '!/^#/ && $1 == v { print $6 }' "$TSV"); do
    root=$(root_of "$r")
    sha=$(awk -F'\t' -v v="$v" -v r="$r" '!/^#/ && $1 == v && $6 == r { print $8 }' "$TSV")
    if [ "$kind" != main ]; then
      dir=$V/$v/$r
      if [ -d "$dir/docs/site" ] && [ "$(cat "$dir/.sha" 2>/dev/null || true)" = "$sha" ]; then
        kept=$((kept + 1))
      else
        rm -rf "$dir"; mkdir -p "$dir"
        git -C "$root" archive "$sha" docs/site | tar -x -C "$dir"
        printf '%s\n' "$sha" > "$dir/.sha"
        archived=$((archived + 1))
      fi
      tree=$dir/docs/site
    else
      rm -rf "${V:?}/$v/$r"   # a version that moved to source = main keeps no archive
      tree=$root/docs/site
    fi
    rows="$rows
$(dates "$tree" "$root" "$sha" docs/site "$r/docs/site" "$v")"
  done
  # A repository the version no longer reads from git (from-bundles: its docs
  # bundle replaces it) keeps no archive.
  for r in opm core catalog_opm cli library opm-operator; do
    awk -F'\t' -v v="$v" -v r="$r" '!/^#/ && $1 == v && $6 == r { f = 1 } END { exit !f }' "$TSV" || rm -rf "${V:?}/$v/$r"
  done
  printf '%s\n' "$rows" | sed '/^$/d' > "$V/$v/lastmod.tsv.tmp"
  mv "$V/$v/lastmod.tsv.tmp" "$V/$v/lastmod.tsv"
  echo "materialise: $v ($kind): $(grep -c . "$V/$v/lastmod.tsv" | tr -d ' ') dated pages -> .versions/$v/lastmod.tsv"
done <<EOF
$versions
EOF

# The enhancements section.
E=$V/enhancements
esha=$(awk -F'\t' '$1 == "# section" && $2 == "enhancements" { print $4; exit }' "$TSV")
if [ -z "$esha" ]; then
  rm -rf "$E"
elif [ -d "$E/tree" ] && [ -f "$E/paths.txt" ] && [ "$(cat "$E/.sha" 2>/dev/null || true)" = "$esha" ]; then
  echo "materialise: enhancements at $esha unchanged"
else
  eroot=$(root_of enhancements)
  [ -n "$eroot" ] || { echo "materialise: versions.tsv names the enhancements section, but there is no enhancements root" >&2; exit 1; }
  rm -rf "$E"; mkdir -p "$E/tree"
  git -C "$eroot" ls-tree -r -t "$esha" | awk -F'\t' '{ split($1, a, " "); print a[2] "\t" $2 }' > "$E/paths.txt"
  files=$(cut -f2 "$E/paths.txt" | grep -E '^(INDEX\.md|GRAPH\.md|(archive/)?[0-9]{4}/(config\.yaml|README\.md|0[1-7]-[a-z0-9-]+\.md))$' | grep -vE '^(archive/)?0000/')
  case "$files" in *" "*) echo "materialise: an enhancements path holds a space" >&2; exit 1 ;; esac
  # shellcheck disable=SC2086 # one path per word
  git -C "$eroot" archive "$esha" -- $files | tar -x -C "$E/tree"
  printf '%s\n' "$esha" > "$E/.sha"
  echo "materialise: enhancements at $esha: $(printf '%s\n' "$files" | grep -c .) files -> .versions/enhancements/tree"
fi

# Remove the directory of a version the manifest no longer lists (vN.N names
# only; nothing outside site/.versions/ is touched).
names=" $(printf '%s\n' "$versions" | cut -f1 | tr '\n' ' ')"
find "$V" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r d; do
  n=${d##*/}
  printf '%s' "$n" | grep -Eq '^v[0-9]+\.[0-9]+$' || continue
  case "$names" in *" $n "*) ;; *) rm -rf "${V:?}/$n"; echo "materialise: removed .versions/$n (not in the manifest)" ;; esac
done
echo "materialise: $archived archive(s) written, $kept unchanged"
