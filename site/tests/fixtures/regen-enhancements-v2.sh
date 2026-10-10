#!/bin/sh
# Rebuilds the schema v2 Enhancements section bundle fixture
# (bundles-v2/enhancements/edge/) from ws/enhancements-v2/ with an opm-docs
# that reads the OpenSpec layout (docs-kit C21), as the enhancements
# repository's docs.yml will once it adopts that release. The tree is
# committed once in a throwaway git repository exactly as
# regen-enhancements.sh does it (author and committer "fixture", date
# 2026-09-20T12:00:00Z, origin the enhancements repository), so the commit,
# every lastmod, every derived updated date and every resolved link are the
# same on every run.
#
#   regen-enhancements-v2.sh [OUT]   OUT defaults to bundles-v2/enhancements/edge/; it is replaced
#
# The pinned opm-docs of site/Dockerfile (0.7.0) reads schema v1 only, so this
# script is NOT part of task test:site and the bundle is committed as built.
# Run it with the opm-docs on PATH that you want to adopt (a build of docs-kit
# branch feat/read-openspec-enhancements, or its release); bundles-v2/ is never
# re-pulled by the tests, because the pinned pull would refuse it. When the pin
# moves to a release that reads v2, fold this fixture into
# regen-enhancements.sh and the fixture lock, and delete this script.
#
# The fixture committed with this change was built with opm-docs from
# docs-kit 9d768e85cdc004cc9fccf71ec3c53ad47189ab07 (branch
# feat/read-openspec-enhancements); manifest.json records the tool.
#
# ws/enhancements-v2/ started as docs-kit's own extractor test repository
# (internal/extract/enhancements/testdata/repo at that commit); this
# repository added 0043 (withdrawn), 0044 (superseded by two entries), two
# finished tasks in 0026 and the v2 INDEX.md.
set -eu
here=$(cd "$(dirname "$0")" && pwd -P)
out=${1:-$here/bundles-v2/enhancements/edge}
command -v opm-docs >/dev/null 2>&1 || { echo "regen-enhancements-v2.sh: opm-docs is not on PATH" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "regen-enhancements-v2.sh: git is not on PATH" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
src=$tmp/enhancements
cp -R "$here/ws/enhancements-v2" "$src"
cat > "$src/docs-kit.cue" <<'CUE'
bundles: enhancements: {
	placement: {kind: "section", root: "/enhancements/"}
	sources: [{kind: "enhancements", description: "The fixture design record."}]
}
CUE
(
  cd "$src"
  export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.org
  export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.org
  export GIT_AUTHOR_DATE=2026-09-20T12:00:00Z GIT_COMMITTER_DATE=2026-09-20T12:00:00Z
  git init -q -b main .
  git remote add origin https://github.com/open-platform-model/enhancements.git
  git add -A
  git -c commit.gpgsign=false commit -q -m fixture
  opm-docs build --source . --config docs-kit.cue --out "$tmp/out" >/dev/null
)
rm -rf "$out"
mkdir -p "$out"
cp -R "$tmp/out/enhancements/." "$out/"
echo "regen-enhancements-v2.sh: wrote $out"
