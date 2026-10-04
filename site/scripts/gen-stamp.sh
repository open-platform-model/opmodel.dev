#!/bin/sh
# Writes SITE_DIR/data/opm/build.json, the build stamp.
#
#   gen-stamp.sh VERSION [VERSION ...]
#
#   { "site": "<opmodel.dev sha>",
#     "sections": { "enhancements": { "project", "ref", "sha", "how", "digest", "local" },
#                   "catalogs": { "lock": "...", "from": "...", "frozen": false, "bundles": [ ... ] } },
#     "versions": { "<v>": { "label": "...", "default": true, "bundles": [ ... ] } } }
#
# "site" is the opmodel.dev commit the build ran from, OPM_SITE_COMMIT
# (resolved on the host by run-in-image.sh, where git works in a worktree;
# unset in test-site.sh, so the key is absent). Every other input is a docs
# bundle, recorded by digest: the site reads no other repository.
# "versions" comes from .gen/versions.tsv (sections.sh, from versions.conf):
# each version's label, whether it is the default, and "bundles", the docs
# bundles it reads (data/opm/docs-bundles.json, gen-docs-bundles.sh, which
# runs first; docs-kit C16): [{project, role, tag, version, revision, digest,
# commit, local, pins}] in the lock's order, digest "" for a local bundle,
# pins {} but on an anchor. "sections.enhancements" comes from ENH_REF,
# ENH_SHA, ENH_HOW and ENH_DIGEST (set by sections.sh from the section
# bundle's lock entry when the build has the section): {project, ref (edge),
# sha (the commit the bundle was built from), how, digest ("" for a local
# bundle), local}, and "sections.catalogs" from data/opm/catalogs.json
# (gen-catalogs.sh, which runs first) when the build has the Catalogs
# section: {"lock": "sha256:...", "from": bundles | OPM_BUNDLES, "frozen":
# true when the bundles came from a frozen pull (run-in-image.sh writes
# <bundles>/frozen), "bundles": [{project, segment, version, revision,
# digest, commit, local}], "history": [{project, digest}]}, digest "" for a
# local bundle, history one entry per project whose history.json the lock
# records (docs-kit C13), the key absent when none does; "sections" is absent
# without either section. layouts/_partials/opm/build-stamp.html shows it in
# the footer, and build-all.sh publishes it as public/build-stamp.json.
set -eu
SITE_DIR=${SITE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$SITE_DIR"
mkdir -p data/opm
site=${OPM_SITE_COMMIT:-}
case "$site" in
  *[!0-9a-f]*) echo "gen-stamp: OPM_SITE_COMMIT is not a commit SHA: $site" >&2; exit 1 ;;
esac
[ -f .gen/versions.tsv ] || { echo "gen-stamp: .gen/versions.tsv is missing (sections.sh writes it)" >&2; exit 1; }
[ -f data/opm/docs-bundles.json ] || { echo "gen-stamp: data/opm/docs-bundles.json is missing (gen-docs-bundles.sh runs first)" >&2; exit 1; }
secs='{}'
if [ -n "${ENH_DIR:-}" ]; then
  case "${ENH_SHA:-}" in *[!0-9a-f]*|'') echo "gen-stamp: enhancements: not a commit SHA: ${ENH_SHA:-}" >&2; exit 1 ;; esac
  secs=$(jq -cn --arg ref "${ENH_REF:-}" --arg sha "$ENH_SHA" --arg how "${ENH_HOW:-}" --arg digest "${ENH_DIGEST:-}" \
    '{enhancements: {project: "enhancements", ref: $ref, sha: $sha, how: $how, digest: $digest, local: ($digest == "")}}')
fi
if [ -n "${CATALOGS:-}" ]; then
  [ -f data/opm/catalogs.json ] || { echo "gen-stamp: the build has the Catalogs section, but data/opm/catalogs.json is missing (gen-catalogs.sh runs first)" >&2; exit 1; }
  fz=false; [ ! -f "$CAT_DIR/frozen" ] || fz=true
  cat=$(jq -c --arg from "${CAT_FROM:-}" --argjson frozen "$fz" '{lock, from: $from, frozen: $frozen, bundles: [.catalogs[] | .project as $p | .segments[]
      | {project: $p, segment, version, revision, digest, commit, local}]}
      + ([.catalogs[] | select(.history) | {project, digest: .history.digest}] | if length > 0 then {history: .} else {} end)' data/opm/catalogs.json)
  secs=$(printf '%s' "$secs" | jq -c --argjson c "$cat" '. + {catalogs: $c}')
fi
rows=$(for v in "$@"; do awk -F'\t' -v v="$v" '$1 == v' .gen/versions.tsv; done)
printf '%s\n' "$rows" | jq -R -s --arg site "$site" --argjson secs "$secs" --slurpfile d data/opm/docs-bundles.json '
  [split("\n")[] | select(length > 0) | split("\t")] as $rows
  | (if $site != "" then {site: $site} else {} end)
  + (if ($secs | length) > 0 then {sections: $secs} else {} end)
  + {versions: ([$rows[] | {key: .[0], value: ({label: .[1], default: (.[3] == "true")}
      + (($d[0].versions[.[0]] // {}) as $b | if ($b | length) > 0
          then {bundles: [$b[] | {project, role, tag, version, revision, digest, commit, local, pins}]} else {} end))}]
      | from_entries)}' > data/opm/build.json
echo "gen-stamp: data/opm/build.json (${site:+site $site, }versions $*)"
