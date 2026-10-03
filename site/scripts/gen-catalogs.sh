#!/bin/sh
# Writes the Catalogs section's one derived input, from the docs bundles'
# lock (docs-kit C7) and each bundle's manifest.json (C3):
#
#   gen-catalogs.sh              (reads CAT_DIR, set by sections.sh; SITE_DIR)
#
#   data/opm/catalogs.json       every template and check reads only this file
#   .gen/catalogs/_index.md      the /catalogs/ section page (an adapter cannot
#                                add the empty path, as for /enhancements/)
#
# Without CAT_DIR (no section) it removes both and writes nothing.
#
#   { "lock": "sha256:<hex of lock.json>",
#     "catalogs": [ { "project", "name", "root", "repo", "newest", "majors": {"4": "4.5"},
#                     "history": {"path", "digest"} or null,
#                     "segments": [ { "segment", "label", "major", "edge", "indexed",
#                                     "version", "revision", "commit", "digest", "local",
#                                     "dir" }, ... ] } ] }
#
# Segments are newest first by numeric MAJOR.MINOR (4.10 after 4.9), edge
# last, whatever order the lock lists them in. "indexed" is true for exactly
# the newest minor of each major; "name" is the last segment of root; edge's
# label is "main (unreleased)"; "newest" is the newest minor ("" for a tab
# with only edge). Every refusal fails the build naming project, segment and
# digest (or "local"): a lock that is not docs.opmodel.dev/lock/v1; an entry
# whose dir is missing or holds no manifest.json; a manifest whose project,
# version, revision or source.commit differs from its lock entry; a project
# whose entries disagree on root, a root that is not /catalogs/<name>/, or a
# manifest whose placement is not that tab root; a segment that is not
# MAJOR.MINOR of the version (or edge for an edge build); a segment listed
# twice; two projects placed at one root; a lock "history" that is not a list,
# or an entry whose history.json is missing, at another digest, of another
# schema or project, or holding a value C13 does not allow (below).
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$SITE_DIR"
CAT_DIR=${CAT_DIR:-}
rm -rf .gen/catalogs data/opm/catalogs.json
[ -n "$CAT_DIR" ] || exit 0
L=$CAT_DIR/lock.json
die() { echo "gen-catalogs: $*" >&2; exit 1; }
[ -f "$L" ] || die "$L is missing"
schema=$(jq -r '.schema // ""' "$L") || die "$L is not JSON"
[ "$schema" = docs.opmodel.dev/lock/v1 ] || die "$L: schema is \"$schema\", not docs.opmodel.dev/lock/v1"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# One line per lock entry, checked against its manifest; the manifests'
# fields the section needs go to $tmp/rows.json.
jq -c '.bundles[]' "$L" > "$tmp/entries"
: > "$tmp/rows"
while IFS= read -r e; do
  get() { printf '%s' "$e" | jq -r "$1"; }
  project=$(get '.project // ""'); segment=$(get '.segment // ""'); dir=$(get '.dir // ""')
  id=$(get 'if .local then "local" else (.digest // "no digest") end')
  who="$project $segment ($id)"
  [ -n "$project" ] && [ -n "$segment" ] && [ -n "$dir" ] || die "$L: an entry lacks project, segment or dir: $e"
  case "$dir" in /*|*..*) die "$who: dir \"$dir\" is not a path under the lock's directory" ;; esac
  m=$CAT_DIR/$dir/manifest.json
  [ -f "$m" ] || die "$who: $dir/manifest.json is missing"
  jq -e . "$m" >/dev/null 2>&1 || die "$who: $dir/manifest.json is not JSON"
  for k in project version revision; do
    a=$(get ".$k"); b=$(jq -r ".$k" "$m")
    [ "$a" = "$b" ] || die "$who: the lock says $k $a, $dir/manifest.json says $b"
  done
  a=$(get '.commit'); b=$(jq -r '.source.commit' "$m")
  [ "$a" = "$b" ] || die "$who: the lock says commit $a, $dir/manifest.json says source.commit $b"
  root=$(get '.root // ""')
  printf '%s\n' "$root" | grep -Eq '^/catalogs/[a-z0-9]+(-[a-z0-9]+)*/$' || die "$who: root \"$root\" is not /catalogs/<name>/"
  kind=$(jq -r '.placement.kind // ""' "$m"); proot=$(jq -r '.placement.root // ""' "$m")
  [ "$kind" = tab ] && [ "$proot" = "$root" ] || die "$who: $dir/manifest.json places the bundle as $kind at \"$proot\", the lock's root is $root"
  version=$(get '.version')
  case "$version" in
    edge) [ "$segment" = edge ] || die "$who: an edge build in segment $segment" ;;
    *) mm=$(printf '%s' "$version" | sed -nE 's/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-.*)?$/\1.\2/p')
       [ -n "$mm" ] && [ "$mm" = "$segment" ] || die "$who: segment $segment is not MAJOR.MINOR of version $version" ;;
  esac
  printf '%s\t%s\n' "$project" "$root" >> "$tmp/roots"
  printf '%s' "$e" | jq -c --slurpfile m "$m" '{project, root, segment, version, revision, commit,
      digest: (.digest // ""), local: (.local // false), dir, repo: $m[0].source.repo}' >> "$tmp/rows"
done < "$tmp/entries"
[ -s "$tmp/rows" ] || die "$L lists no bundles"
bad=$(sort -u "$tmp/roots" | cut -f1 | uniq -d)
[ -z "$bad" ] || die "project $bad: its entries name more than one root"
bad=$(sort -u "$tmp/roots" | cut -f2 | sort | uniq -d)
[ -z "$bad" ] || die "root $bad: more than one project is placed there"
dup=$(jq -r '"\(.project) \(.segment)"' "$tmp/rows" | sort | uniq -d)
[ -z "$dup" ] || die "$dup: the lock lists the segment twice"

# Version history (docs-kit C13): a tab project's <project>/history.json,
# written by opm-docs pull and recorded in the lock's optional "history" key
# (C7). The site reads it, never computes it. An entry needs its file at the
# digest it records, of schema docs.opmodel.dev/history/v1 and its own
# project; a file the lock does not record (left by an older pull) is
# ignored, and its project gets no history. Values the site words or links
# by must be C13's: every compared mode full or paths, every member's first
# one of the file's segments, every change op one of C13's seven, every
# presence change between two different presences (regular, optional,
# required), every removed lastIn one of the segments.
jq -c '.history // [] | if type == "array" then .[] else error("not a list") end' "$L" > "$tmp/hentries" 2>/dev/null || die "$L: \"history\" is not a list"
echo '{}' > "$tmp/history.json"
while IFS= read -r e; do
  get() { printf '%s' "$e" | jq -r "$1"; }
  project=$(get '.project // ""'); path=$(get '.path // ""'); want=$(get '.digest // ""')
  [ -n "$project" ] || die "$L: a history entry lacks project: $e"
  cut -f1 "$tmp/roots" | grep -qxF "$project" || die "$project: the lock records history.json, but no bundles of the project"
  [ "$path" = "$project/history.json" ] || die "$project: the lock records history at \"$path\", not $project/history.json"
  f=$CAT_DIR/$path
  [ -f "$f" ] || die "$project: the lock records history.json, but $(dirname "$f") has none"
  have=sha256:$(sha256sum "$f" | cut -c1-64)
  [ "$have" = "$want" ] || die "$project: history.json is $have, the lock records $want; run task bundles:pull"
  hs=$(jq -r '.schema // ""' "$f" 2>/dev/null) || die "$project: history.json is not JSON"
  [ "$hs" = docs.opmodel.dev/history/v1 ] || die "$project: history.json schema is \"$hs\", not docs.opmodel.dev/history/v1"
  hp=$(jq -r '.project // ""' "$f")
  [ "$hp" = "$project" ] || die "$project: history.json is for project \"$hp\""
  bad=$(jq -r '
    def presence: . == "regular" or . == "optional" or . == "required";
    (.segments // []) as $segs | def seg: . as $x | any($segs[]; . == $x);
    [ ((.compared // [])[] | select(.mode != "full" and .mode != "paths")
        | "compared \(.from) -> \(.to): mode \(.mode | tojson) is not full or paths"),
      ((.members // {}) | to_entries[] | .key as $f | .value
        | (select(.first | seg | not) | "member \($f): first \(.first | tojson) is not one of the segments \($segs | join(" "))"),
          ((.changes // {}) | to_entries[] | .value[]
            | (select(.op | IN("added", "removed", "presence", "type", "default", "ref", "spec") | not)
                | "member \($f): change op \(.op | tojson) is not one of C13'"'"'s"),
              (select(.op == "presence" and ((.from | presence | not) or (.to | presence | not) or .from == .to))
                | "member \($f): presence change of \(.path) from \(.from | tojson) to \(.to | tojson) is not between two different presences"))),
      ((.removed // {}) | to_entries[] | .value[] | select(.lastIn | seg | not)
        | "removed \(.fqn): lastIn \(.lastIn | tojson) is not one of the segments")
    ] | .[0] // empty' "$f") || die "$project: history.json is not C13's shape"
  [ -z "$bad" ] || die "$project: history.json: $bad"
  jq --arg p "$project" --arg path "$path" --arg digest "$have" \
    '.[$p] = {path: $path, digest: $digest}' "$tmp/history.json" > "$tmp/h" && mv "$tmp/h" "$tmp/history.json"
done < "$tmp/hentries"

mkdir -p data/opm .gen/catalogs
jq -s --arg lock "sha256:$(sha256sum "$L" | cut -c1-64)" --slurpfile hist "$tmp/history.json" '
  def key: if .segment == "edge" then [1, 0, 0]
           else (.segment | split(".") | map(tonumber)) as $v | [0, -$v[0], -$v[1]] end;
  {lock: $lock,
   catalogs: (group_by(.project) | map(
     (sort_by(key)) as $s
     | ([$s[] | select(.segment != "edge")]) as $minors
     | ($minors | group_by(.segment | split(".")[0] | tonumber)
                | map({key: (.[0].segment | split(".")[0]), value: (sort_by(key) | .[0].segment)}) | from_entries) as $majors
     | {project: $s[0].project, name: ($s[0].root | split("/")[2]), root: $s[0].root, repo: $s[0].repo,
        newest: ($minors[0].segment // ""), majors: $majors, history: ($hist[0][$s[0].project] // null),
        segments: [$s[] | . as $r | {segment, label: (if .segment == "edge" then "main (unreleased)" else .segment end),
          major: (if .segment == "edge" then "" else (.segment | split(".")[0]) end), edge: (.segment == "edge"),
          indexed: (.segment != "edge" and $majors[.segment | split(".")[0]] == .segment),
          version, revision, commit, digest, local, dir}]}))}
' "$tmp/rows" > data/opm/catalogs.json

# The /catalogs/ section page. Its description, one sentence, is the lead;
# in HTML the catalog cards (layouts/_partials/opm/catalog-picker.html)
# replace the body, so the body below, one line per catalog linking its bare
# tab root (its newest minor; edge for a tab that has no release yet) and
# edge, feeds only the page's Markdown twin. Its date is the newest lastmod
# among the indexed segments' pages, so edge never dates it (Hugo would
# otherwise date a section by its newest descendant).
newest=$(jq -r '.catalogs[] | .segments[] | select(.indexed) | .dir' data/opm/catalogs.json | while IFS= read -r d; do
  jq -r '.pages[].lastmod // empty' "$CAT_DIR/$d/manifest.json"; done | sort | tail -n 1)
{
  printf -- '---\ntitle: Catalogs\n'
  printf 'description: Pick a catalog to read the reference of its newest release.\n'
  printf 'url: /catalogs/\n'
  [ -z "$newest" ] || printf 'date: %s\nlastmod: %s\n' "$newest" "$newest"
  printf 'params:\n  llms: true\n  cards: false\n---\n\n'
  printf 'Pick a catalog to read the reference of its newest release.\n\n'
  jq -r '.catalogs[] | .newest as $nw | (first(.segments[] | select(.edge)) // null) as $edge
    | "- [\(.name) catalog](\(.root)\(if $nw != "" then "" else "edge/" end)): "
      + (if $nw != "" then "newest release \(first(.segments[] | select(.segment == $nw)) | .version)"
           + (if $edge then " ([main, unreleased](\(.root)edge/))" else "" end)
         else "no release yet, main (unreleased) only" end)
      + ", from `\(.repo)`"' data/opm/catalogs.json
} > .gen/catalogs/_index.md
echo "gen-catalogs: wrote data/opm/catalogs.json and .gen/catalogs/_index.md ($(jq -r '[.catalogs[] | "\(.name): \([.segments[].segment] | join(" "))"] | join("; ")' data/opm/catalogs.json))"
