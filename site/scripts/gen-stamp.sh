#!/bin/sh
# Writes SITE_DIR/data/opm/build.json, the build stamp.
#
#   gen-stamp.sh [VERSION=ROOT ...]
#
#   { "sources": { "opm": "<sha>", ... },
#     "site": "<opmodel.dev sha>",
#     "versions": { "<v>": { "label": "...", "default": true, "kind": "line",
#                            "refs": { "<repo>": { "ref": "...", "sha": "...", "how": "...",
#                                                  "docs": "..." } } } } }
#
# "sources" comes from OPM_BUILD_REFS ("repo=sha ...", resolved on the host by
# run-in-image.sh; a root that is not its own git checkout is "none"; unset in
# test-site.sh, so no source): each root's checked-out HEAD. Only a source =
# main version, an explicit build and a fixture build read those trees; for
# an anchored or a line version "versions.<v>.refs" and "site" are the
# record. "versions" comes from .versions/versions.tsv (site/versions.conf,
# resolved on the host) unless OPM_VERSIONS is set: kind "main" (every root at
# HEAD), "anchored" (fixed refs) or "line" (resolved from release lines on
# every build), each repo's ref (the release the stamp names), the SHA of the
# tree built, how it was found (head, anchor, explicit, pin:<repo> <file>,
# line:<rule>, override:<reason>, with "; docs: <rule>" for every released
# repository (cli, library, opm-operator, core, catalog_opm) in a line
# version) and, from column 10, where that tree came
# from ("docs": tag, sha, main, release/<prefix>vX.Y, or worktree). "site" is
# the opmodel.dev commit, from the "# site" line of versions.tsv; it is absent
# when there is no versions.tsv. With OPM_VERSIONS set, or no versions.tsv,
# the versions are the arguments, kind "explicit", label = name, the first the
# default, no refs. layouts/_partials/opm/build-stamp.html shows it in the
# footer, opm/source.html builds "View source" and "Edit" links from the
# refs, and build-all.sh publishes it as public/build-stamp.json.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$SITE_DIR"
mkdir -p data/opm
site=""
if [ -z "${OPM_VERSIONS:-}" ] && [ -f .versions/versions.tsv ]; then
  rows=$(awk -F'\t' '!/^#/' .versions/versions.tsv)
  site=$(awk -F'\t' '$1 == "# site" { print $2; exit }' .versions/versions.tsv)
  case "$site" in
    *[!0-9a-f]*) echo "gen-stamp: the # site line of .versions/versions.tsv is not a commit SHA: $site" >&2; exit 1 ;;
  esac
else
  [ $# -gt 0 ] || set -- v1.0=/src
  rows=$(n=0; for pair in "$@"; do
    n=$((n + 1)); printf '%s\t%s\t%s\t%s\texplicit\t\t\t\t\n' "${pair%%=*}" "${pair%%=*}" "$n" "$([ $n = 1 ] && echo true || echo false)"
  done)
fi
{
  printf '{\n  "sources": {'
  sep=''
  for pair in ${OPM_BUILD_REFS:-}; do
    repo=${pair%%=*}; sha=${pair#*=}
    case "$sha" in
      none) ;;
      *[!0-9a-f]*|'') echo "gen-stamp: $repo: not a commit SHA: $sha" >&2; exit 1 ;;
    esac
    printf '%s\n    "%s": "%s"' "$sep" "$repo" "$sha"
    sep=,
  done
  [ -z "$sep" ] || printf '\n  '
  printf '},\n'
  [ -z "$site" ] || printf '  "site": "%s",\n' "$site"
  printf '  "versions": {'
  printf '%s\n' "$rows" | awk -F'\t' '
    NF < 5 { next }
    $1 != cur {
      if (cur != "") printf "}},"
      cur = $1; first = 1
      printf "\n    \"%s\": {\"label\": \"%s\", \"default\": %s, \"kind\": \"%s\", \"refs\": {", $1, $2, ($4 == "true" ? "true" : "false"), $5
    }
    $6 != "" {
      printf "%s\n      \"%s\": {\"ref\": \"%s\", \"sha\": \"%s\", \"how\": \"%s\"", (first ? "" : ","), $6, $7, $8, $9
      if ($10 != "") printf ", \"docs\": \"%s\"", $10
      printf "}"
      first = 0
    }
    END { if (cur != "") printf "}}\n  " }'
  printf '}\n}\n'
} > data/opm/build.json
echo "gen-stamp: data/opm/build.json ($(grep -c '^    "[a-z_-]*": "' data/opm/build.json | tr -d ' ') sources, ${site:+site $site, }versions $(awk -F'\t' 'NF >= 5 && !s[$1]++ { printf "%s%s", (n++ ? " " : ""), $1 }' <<ROWS
$rows
ROWS
))"
