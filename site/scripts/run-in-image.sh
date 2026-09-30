#!/bin/sh
# Host side of the site tasks: resolves the workspace and the six source
# roots, checks them before any container starts, and runs one step in the
# build image. POSIX sh; needs git and docker on the host, nothing else.
#
#   run-in-image.sh image    build opmodel-dev-hugo:<first 12 hex of sha256(Dockerfile)> if missing (network)
#   run-in-image.sh tag      print that tag
#   run-in-image.sh build    build-all.sh in the image, --network none -> site/public/
#   run-in-image.sh serve    serve.sh in the image, published on 127.0.0.1:${SITE_PORT:-1313} only
#   run-in-image.sh preview  a static server over the built site/public/, on 127.0.0.1:${SITE_PORT:-1313} only
#   run-in-image.sh lint     the source lint over the six source roots, --network none
#   run-in-image.sh test     test-site.sh in the image, --network none; reads fixtures only, mounts no source root
#   run-in-image.sh qa-image build opmodel-dev-qa:<first 12 hex of sha256(site/tests/browser/Dockerfile)> if missing (network)
#   run-in-image.sh qa-tag   print that tag
#   run-in-image.sh shots    site/tests/browser/shots.py over the built site/public/, --network none -> site/.shots/
#   run-in-image.sh qa       shots.py, then a11y.py and search.py, --network none, no published port
#
# Environment. Each is read from the environment first; an empty value counts as unset.
#   OPM_WS             workspace root. Default: the parent of the opmodel.dev main checkout, from
#                      git's common directory, so it is right inside a worktree.
#   OPM_SRC_<REPO>     one source root per repo: OPM_SRC_OPM, OPM_SRC_CORE, OPM_SRC_CATALOG_OPM,
#                      OPM_SRC_CLI, OPM_SRC_LIBRARY, OPM_SRC_OPM_OPERATOR. Default:
#                      $OPM_WS/<repo>/.claude/worktrees/$OPM_SRC_WORKTREE when OPM_SRC_WORKTREE is set,
#                      else $OPM_WS/<repo>.
#   OPM_SRC_WORKTREE   worktree name used for every unset OPM_SRC_<REPO>.
#   SITE_PORT          host port for serve (default 1313).
#   OPM_REQUIRE_DATES  1 fails the build when a page has no git date (default 0).
#   OPM_VERSIONS       name=root ... (roots are container paths). Passed into the container only
#                      when the caller set it; otherwise build-all.sh and serve.sh use v1.0=/src.
# OPM_BUILD_REFS (repo=sha ..., "none" for a root that is not its own git top level) is resolved
# here from each root on the host, where git works in a worktree; never set it by hand.
#
# Containers: --rm --init --user <uid>:<gid>, no --name. The repo is mounted at /work/repo and
# each source root read-only at /src/<repo>, never with :z.
set -eu
REPOS="opm core catalog_opm cli library opm-operator"
DOCKERFILE=site/Dockerfile
QA_DOCKERFILE=site/tests/browser/Dockerfile

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
mode=${1:-}

die() { echo "run-in-image: $*" >&2; exit 1; }
envval() { printenv "$1" 2>/dev/null || true; }

tag() { echo "opmodel-dev-hugo:$(sha256sum "$DOCKERFILE" | cut -c1-12)"; }
qa_tag() { echo "opmodel-dev-qa:$(sha256sum "$QA_DOCKERFILE" | cut -c1-12)"; }

# build_image TAG DOCKERFILE: build it with no context, only when the tag is missing.
build_image() {
  if docker image inspect "$1" >/dev/null 2>&1; then
    echo "image: $1 present"
  else
    echo "image: building $1 from $2"
    docker build --quiet --tag "$1" - < "$2" >/dev/null
    echo "image: built $1"
  fi
}
image() { build_image "$(tag)" "$DOCKERFILE"; }
qa_image() { build_image "$(qa_tag)" "$QA_DOCKERFILE"; }

# Resolves and checks every source root; sets MOUNTS (docker -v flags) and REFS.
sources() {
  ws=$(envval OPM_WS)
  if [ -z "$ws" ]; then
    common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)
    ws=$(dirname "$(dirname "$common")")
  fi
  wt=$(envval OPM_SRC_WORKTREE)
  MOUNTS=""; REFS=""; missing=""
  for r in $REPOS; do
    var=OPM_SRC_$(printf '%s' "$r" | tr 'a-z-' 'A-Z_')
    root=$(envval "$var")
    if [ -z "$root" ]; then
      if [ -n "$wt" ]; then root=$ws/$r/.claude/worktrees/$wt; else root=$ws/$r; fi
    fi
    if [ ! -d "$root/docs/site" ]; then
      missing="$missing
  $var: $root has no docs/site"
      continue
    fi
    abs=$(cd "$root" && pwd -P)
    case "$abs" in *[:,\ ]*) die "$var: $abs contains ':', ',' or a space; docker -v cannot mount it" ;; esac
    MOUNTS="$MOUNTS -v $abs:/src/$r:ro"
    top=$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" = "$abs" ]; then
      REFS="$REFS $r=$(git -C "$abs" rev-parse HEAD)"
    else
      REFS="$REFS $r=none"
    fi
  done
  if [ -n "$missing" ]; then
    die "source roots missing (set OPM_WS, OPM_SRC_WORKTREE or OPM_SRC_<REPO>):$missing"
  fi
  REFS=${REFS# }
}

# Common docker run flags; the caller adds the network, mounts and command.
run() {
  versions=$(envval OPM_VERSIONS)
  set -- --rm --init --user "$(id -u):$(id -g)" \
    --env HOME=/tmp \
    --env "OPM_REQUIRE_DATES=$(envval OPM_REQUIRE_DATES)" \
    --volume "$repo:/work/repo" \
    "$@"
  if [ -n "$versions" ]; then set -- --env "OPM_VERSIONS=$versions" "$@"; fi
  exec docker run "$@"
}

case "$mode" in
  tag) tag ;;
  image) image ;;
  build)
    sources; image >/dev/null
    echo "run-in-image: build, sources $REFS"
    # shellcheck disable=SC2086 # MOUNTS is a list of -v flags without spaces inside paths
    run --network none --env "OPM_BUILD_REFS=$REFS" $MOUNTS \
      --entrypoint sh "$(tag)" /work/repo/site/scripts/build-all.sh ;;
  serve)
    sources; image >/dev/null
    port=$(envval SITE_PORT); port=${port:-1313}
    echo "run-in-image: serving on http://127.0.0.1:$port/ (Ctrl+C stops it)"
    # shellcheck disable=SC2086
    run --env TINI_KILL_PROCESS_GROUP=1 --env "SITE_PORT=$port" --env "OPM_BUILD_REFS=$REFS" \
      --publish "127.0.0.1:$port:1313" $MOUNTS \
      --entrypoint sh "$(tag)" /work/repo/site/scripts/serve.sh </dev/null ;;
  preview)
    [ -f site/public/index.html ] || die "site/public/ holds no build; run the build task first"
    image >/dev/null
    port=$(envval SITE_PORT); port=${port:-1313}
    echo "run-in-image: previewing site/public/ on http://127.0.0.1:$port/ (Ctrl+C stops it)"
    run --env TINI_KILL_PROCESS_GROUP=1 --publish "127.0.0.1:$port:1313" \
      --entrypoint sh "$(tag)" -c 'printf "E404:404.html\n" > /tmp/httpd.conf && exec httpd -f -p 1313 -h /work/repo/site/public -c /tmp/httpd.conf' </dev/null ;;
  lint)
    sources; image >/dev/null
    dirs=""; for r in $REPOS; do dirs="$dirs /src/$r/docs/site"; done
    # shellcheck disable=SC2086
    run --network none $MOUNTS --entrypoint sh "$(tag)" /work/repo/site/scripts/lint-sources.sh $dirs ;;
  test)
    image >/dev/null
    run --network none --entrypoint sh "$(tag)" /work/repo/site/scripts/test-site.sh ;;
  qa-tag) qa_tag ;;
  qa-image) qa_image ;;
  shots|qa)
    [ -f site/public/_redirects ] || die "site/public/ holds no build; run the build task first"
    qa_image >/dev/null
    b=/work/repo/site/tests/browser
    if [ "$mode" = shots ]; then cmd="python3 $b/shots.py"; else cmd="python3 $b/shots.py && python3 $b/a11y.py && python3 $b/search.py"; fi
    run --network none --env PYTHONDONTWRITEBYTECODE=1 --entrypoint sh "$(qa_tag)" -c "$cmd" ;;
  *) sed -n '2,15p' "$0" >&2; exit 2 ;;
esac
