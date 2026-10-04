#!/bin/sh
# Writes data/opm/docs-bundles.json: the docs bundles each site version reads
# (docs-kit C15, C16), and each bundle's page data, from the docs bundles'
# lock (its "docs" key, C16) and each bundle's manifest.json (C3). The lock
# is the only source of truth inside the build (openspec
# pull-reference-bundles, design Decision 1).
#
#   gen-docs-bundles.sh VERSION [VERSION ...]   (reads CAT_DIR; SITE_DIR)
#
#   { "lock": "sha256:<hex of lock.json>",
#     "versions": { "<v>": { "<project>": {
#         "project", "tree", "role", "tag", "version", "revision", "commit", "ref",
#         "digest", "local", "repo", "dir", "pins",
#         "pages": { "<path under content/>": {"source", "lastmod", "edit", "generated"} } } } } }
#
# "tree" is the source repository the bundle documents, from the fixed table
# below; "repo" the bundle's source.repo; "ref" its source.ref (the release
# tag); "digest" "" and "local" true for a local bundle; "pins" {} unless the
# bundle is an anchor with pins. gen-mounts.sh, check-pages.sh, gen-stamp.sh
# and the page templates (opm/source.html) read this file.
#
# Every refusal fails the build naming the site version, the project and the
# digest (or "local"): a lock that is not docs.opmodel.dev/lock/v1; an entry
# for a site version this build does not build, a project the table does not
# know, one version and project twice, or two projects that document one
# repository; a dir that is missing or holds no manifest.json; a manifest
# whose project, version, revision or source.commit differs from its lock
# entry, or whose source.repo is not the repo site/bundles.cue names for that
# project under docs (the repository the pull verified the signature for;
# read from its quoted keys, as run-in-image.sh reads them; with OPM_BUNDLES
# the lock was pulled for another config, the edge build's or a test's, and
# bundles.cue is still the trust policy it was derived from); a placement
# that is not docs at /docs/; a page under content/ the manifest does not
# list, or a listed page that is missing (C3 says they are equal; checked
# again because the site mounts content/ whole).
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$SITE_DIR"
CAT_DIR=${CAT_DIR:-}
OUTF=data/opm/docs-bundles.json
die() { echo "gen-docs-bundles: $*" >&2; exit 1; }
mkdir -p data/opm
rm -f "$OUTF"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# The fixed table: docs project -> the source repository it documents.
tree_of() {
  case "$1" in
    cli|core|library|opm-operator|opm) echo "$1" ;;
    catalog-opm-docs) echo catalog_opm ;;
    *) return 1 ;;
  esac
}

# The repo site/bundles.cue allows to sign a docs project: the quoted key's
# line in its docs block, {repo: "<owner>/<name>"}.
repo_in_config() {
  [ -f bundles.cue ] || return 0
  awk -v p="$1" '/^docs:[[:space:]]*\{/ { on = 1; next } on && /^\}/ { on = 0 }
    on && index($0, "\"" p "\"") && match($0, /repo:[[:space:]]*"[^"]+"/) { r = substr($0, RSTART, RLENGTH); sub(/^repo:[[:space:]]*"/, "", r); sub(/"$/, "", r); print r; exit }' bundles.cue
}

built=" "
for v in "$@"; do built="$built$v "; done

echo '{}' > "$tmp/versions.json"
lockd=""
[ -n "$CAT_DIR" ] || die "CAT_DIR is not set (sections.sh sets it)"
L=$CAT_DIR/lock.json
[ -f "$L" ] || die "$L is missing"
schema=$(jq -r '.schema // ""' "$L") || die "$L is not JSON"
[ "$schema" = docs.opmodel.dev/lock/v1 ] || die "$L: schema is \"$schema\", not docs.opmodel.dev/lock/v1"
jq -c '.docs // [] | if type == "array" then .[] else error("not a list") end' "$L" > "$tmp/entries" 2>/dev/null || die "$L: \"docs\" is not a list"
if [ -s "$tmp/entries" ]; then lockd=sha256:$(sha256sum "$L" | cut -c1-64); fi
: > "$tmp/seen"
while IFS= read -r e; do
  get() { printf '%s' "$e" | jq -r "$1"; }
  site=$(get '.site // ""'); project=$(get '.project // ""'); dir=$(get '.dir // ""')
  id=$(get 'if .local then "local" else (.digest // "no digest") end')
  who="$site: $project $(get '.version // ""') ($id)"
  [ -n "$site" ] && [ -n "$project" ] && [ -n "$dir" ] || die "$L: a docs entry lacks site, project or dir: $e"
  case "$built" in *" $site "*) ;; *) die "$who: the lock names site version $site, which this build does not build (versions:$built)" ;; esac
  tree=$(tree_of "$project") || die "$who: no source repository is known for docs project $project (cli, core, library, opm-operator, opm, catalog-opm-docs)"
  if grep -qxF "$site $project" "$tmp/seen"; then die "$who: the lock names $project twice for $site"; fi
  if grep -qxF "$site tree $tree" "$tmp/seen"; then die "$who: two docs projects of $site document the repository $tree"; fi
  printf '%s %s\n%s tree %s\n' "$site" "$project" "$site" "$tree" >> "$tmp/seen"
  case "$dir" in /*|*..*) die "$who: dir \"$dir\" is not a path under the lock's directory" ;; esac
  B=$CAT_DIR/$dir
  m=$B/manifest.json
  [ -f "$m" ] || die "$who: $dir/manifest.json is missing"
  jq -e . "$m" >/dev/null 2>&1 || die "$who: $dir/manifest.json is not JSON"
  for k in project version revision; do
    a=$(get ".$k"); b=$(jq -r ".$k" "$m")
    [ "$a" = "$b" ] || die "$who: the lock says $k $a, $dir/manifest.json says $b"
  done
  a=$(get '.commit'); b=$(jq -r '.source.commit' "$m")
  [ "$a" = "$b" ] || die "$who: the lock says commit $a, $dir/manifest.json says source.commit $b"
  want=$(repo_in_config "$project"); have=$(jq -r '.source.repo // ""' "$m")
  [ -n "$want" ] || die "$who: site/bundles.cue names no docs project $project (docs: {\"$project\": {repo: ...}})"
  [ "$want" = "$have" ] || die "$who: $dir/manifest.json says source.repo $have, site/bundles.cue allows only $want to sign $project"
  kind=$(jq -r '.placement.kind // ""' "$m"); proot=$(jq -r '.placement.root // ""' "$m")
  [ "$kind" = docs ] && [ "$proot" = /docs/ ] || die "$who: $dir/manifest.json places the bundle as $kind at \"$proot\", not as docs at /docs/"
  # content/ holds exactly the pages the manifest lists.
  (cd "$B" && { [ ! -d content ] || find content -type f; }) | sed 's#^content/##' | sort > "$tmp/have"
  jq -r '.pages[].path' "$m" | sort > "$tmp/want"
  extra=$(comm -13 "$tmp/want" "$tmp/have")
  missing=$(comm -23 "$tmp/want" "$tmp/have")
  [ -z "$extra" ] || die "$who: $dir/content/ holds pages its manifest.json does not list: $(printf '%s' "$extra" | tr '\n' ' ')"
  [ -z "$missing" ] || die "$who: $dir/manifest.json lists pages $dir/content/ does not hold: $(printf '%s' "$missing" | tr '\n' ' ')"
  printf '%s' "$e" | jq -c --slurpfile m "$m" --arg tree "$tree" '{site, project, tree: $tree, role, tag: (.tag // ""),
      version, revision, commit, ref: ($m[0].source.ref // ""), digest: (.digest // ""), local: (.local // false),
      repo: $m[0].source.repo, dir, pins: (.pins // {}),
      pages: ([$m[0].pages[] | {key: .path, value: {source: (.source // ""), lastmod: (.lastmod // ""), edit: (.edit // ""), generated}}] | from_entries)}' > "$tmp/row"
  jq --slurpfile r "$tmp/row" '.[$r[0].site][$r[0].project] = ($r[0] | del(.site))' "$tmp/versions.json" > "$tmp/v" && mv "$tmp/v" "$tmp/versions.json"
done < "$tmp/entries"
jq --arg lock "$lockd" '{lock: $lock, versions: .}' "$tmp/versions.json" > "$OUTF"

echo "gen-docs-bundles: wrote $OUTF ($(jq -r '[.versions | to_entries[] | "\(.key): \([.value[] | "\(.project) \(.version)"] | join(", "))"] | if length == 0 then "no docs bundle" else join("; ") end' "$OUTF"))"
