#!/bin/sh
# Rebuilds the Enhancements section bundle fixture (bundles/enhancements/edge/)
# from site/tests/fixtures/ws/enhancements/ with the pinned opm-docs, as the
# enhancements repository's docs.yml would: the tree is committed once in a
# throwaway git repository (author and committer "fixture", date
# 2026-09-20T12:00:00Z, origin the enhancements repository, the C21
# docs-kit.cue entry added), so the commit, every lastmod and every resolved
# link are the same on every run.
#
#   regen-enhancements.sh [OUT]   OUT defaults to bundles/enhancements/edge/; it is replaced
#
# It lives outside bundles/, which must stay byte-identical to what an
# all-local opm-docs pull writes.
#
# Needs opm-docs and git: in the build image it runs in place (task
# test:site rebuilds into a scratch directory and diffs it with the fixture); on
# the host it re-runs itself in the build image, with no network. After a
# fixture edit, run it on the host, then re-pull the fixture lock (README
# "The Enhancements section").
set -eu
here=$(cd "$(dirname "$0")" && pwd -P)
site=$(cd "$here/../.." && pwd -P)
out=${1:-$here/bundles/enhancements/edge}
if ! command -v opm-docs >/dev/null 2>&1; then
  repo=$(dirname "$site")
  case "$out" in /*) ;; *) out=$PWD/$out ;; esac
  case "$out" in "$repo"/*) ;; *) echo "regen-enhancements.sh: on the host, OUT must lie in the repository ($repo)" >&2; exit 1 ;; esac
  tag=$(sh "$site/scripts/run-in-image.sh" tag)
  exec docker run --rm --init --user "$(id -u):$(id -g)" --network none --env HOME=/tmp \
    --volume "$repo:/work/repo" --entrypoint sh "$tag" \
    /work/repo/site/tests/fixtures/regen-enhancements.sh "/work/repo${out#"$repo"}"
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
src=$tmp/enhancements
cp -R "$site/tests/fixtures/ws/enhancements" "$src"
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
echo "regen-enhancements.sh: wrote $out"
