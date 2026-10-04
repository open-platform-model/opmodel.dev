#!/bin/sh
# Host side of the site tasks: resolves the workspace and the six source
# roots, checks them before any container starts, and runs one step in the
# build image. POSIX sh; needs git and docker on the host, nothing else.
#
#   run-in-image.sh image    build opmodel-dev-hugo:<first 12 hex of sha256(Dockerfile)> if missing (network)
#   run-in-image.sh tag      print that tag
#   run-in-image.sh pull     opm-docs pull of site/bundles.cue in the image -> site/.bundles/ (network,
#                            unless every tab and docs bundle is local; OPM_BUNDLES_CONFIG and
#                            OPM_BUNDLES_OUT choose another config and output)
#   run-in-image.sh build    build-all.sh in the image, --network none -> site/public/
#   run-in-image.sh serve    serve.sh in the image, published on 127.0.0.1:${SITE_PORT:-1313} only
#   run-in-image.sh preview  a static server over the built site/public/, on 127.0.0.1:${SITE_PORT:-1313} only
#   run-in-image.sh lint     the source lint over the six source roots, --network none
#   run-in-image.sh test     test-site.sh in the image, --network none; reads fixtures only, mounts no source root
#   run-in-image.sh qa-image build opmodel-dev-qa:<first 12 hex of sha256(site/tests/browser/Dockerfile)> if missing (network)
#   run-in-image.sh qa-tag   print that tag
#   run-in-image.sh shots    site/tests/browser/shots.py and diagrams.py over the built site/public/, --network none -> site/.shots/
#   run-in-image.sh qa       shots.py and diagrams.py, then a11y.py, search.py and theme_reveal.py, --network none, no published port
#
# Environment. Each is read from the environment first; an empty value counts as unset.
#   OPM_WS             workspace root. Default: the parent of the opmodel.dev main checkout, from
#                      git's common directory, so it is right inside a worktree.
#   OPM_SRC_<REPO>     one source root per repo: OPM_SRC_OPM, OPM_SRC_CORE, OPM_SRC_CATALOG_OPM,
#                      OPM_SRC_CLI, OPM_SRC_LIBRARY, OPM_SRC_OPM_OPERATOR. Default:
#                      $OPM_WS/<repo>/.claude/worktrees/$OPM_SRC_WORKTREE when OPM_SRC_WORKTREE is set,
#                      else $OPM_WS/<repo>.
#   OPM_SRC_WORKTREE   worktree name used for every unset OPM_SRC_<REPO>.
#   OPM_SRC_ENHANCEMENTS  the enhancements repository (the design record, built as the
#                      unversioned /enhancements/ section). Default: $OPM_WS/enhancements;
#                      OPM_SRC_WORKTREE does not apply. Optional here: a root without INDEX.md is
#                      not mounted, and a build in explicit mode then has no such section;
#                      resolve-versions.sh fails when the manifest names the section and the
#                      root is missing.
#   SITE_PORT          host port for serve (default 1313).
#   OPM_REQUIRE_DATES  1 fails the build when a page has no git date (default 0).
#   OPM_VERSIONS       name=root ... (roots are container paths). Passed into the container only
#                      when the caller set it; otherwise build-all.sh and serve.sh use v1.0=/src.
#   OPM_BASE_URL       the site's base URL, an absolute http(s) URL ending in /, which may carry
#                      a path (https://example.org/docs/). Passed into the container in build
#                      mode only, and only when set; unset, the build uses hugo.toml's baseURL.
#                      serve, test, lint and the two-version test never see it.
#   OPM_DOCS_BUNDLES   1: an explicit build (OPM_VERSIONS) reads the lock's docs bundles too
#                      (gen-docs-bundles.sh); unset, explicit mode reads every repository from git.
#                      Passed into the container in build and serve mode.
#   OPM_BUNDLES        a directory of unpacked docs bundles with their lock.json (what opm-docs
#                      pull writes; the test fixtures site/tests/fixtures/bundles), relative to the
#                      repo or absolute. Build and serve mount it read-only at /bundles and pass
#                      OPM_BUNDLES=/bundles, so the Catalogs section comes from it instead of
#                      site/.bundles/ (site/scripts/sections.sh). Build and serve only: pull never
#                      reads it (pull sweeps its output, so a tree a build reads is never a target).
#   OPM_BUNDLES_CONFIG pull mode only: the pull config, relative to the repo or absolute; default
#                      site/bundles.cue. task build:edge names site/.edge/bundles.cue
#                      (site/scripts/edge-config.sh). When it is set, a committed
#                      site/bundles.frozen.json is not applied (it was pulled for bundles.cue);
#                      an explicit OPM_BUNDLES_FROZEN still is.
#   OPM_BUNDLES_OUT    pull mode only: the directory the pull writes and sweeps, with its
#                      lock.json, relative to the repo or absolute; default site/.bundles.
#   OPM_BUNDLES_LOCAL  pull mode only: <project>@<segment>=<host dir> ..., space-separated, each a
#                      local bundle tree (an opm-docs build output) pull takes instead of the
#                      registry (docs-kit C7 --local): a tab's segment (4.5, edge), or, for a docs
#                      project, the site version it is placed in (cli@v1.0=<dir>, C16). Each is
#                      mounted read-only. A pull whose every tab and every docs project of every
#                      site version of the pull config is named here runs with --network none.
#   OPM_BUNDLES_FROZEN pull mode only: a lock to pull exactly (opm-docs pull --frozen), e.g. the
#                      build job's lock in CI; default site/bundles.frozen.json when it exists and
#                      OPM_BUNDLES_CONFIG is unset.
# OPM_BUILD_REFS (repo=sha ..., "none" for a root that is not its own git top level) is resolved
# here from each root on the host, where git works in a worktree; never set it by hand.
#
# Containers: --rm --init --user <uid>:<gid>, no --name. The repo is mounted at /work/repo and
# each source root read-only at /src/<repo> (the enhancements root at /src/enhancements),
# never with :z.
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

# Resolves and checks every source root; sets MOUNTS (docker -v flags) and REFS,
# and CAT (the OPM_BUNDLES mount and variable, or nothing).
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
  # The enhancements root: mounted only when it holds INDEX.md; its HEAD joins REFS.
  enh=$(envval OPM_SRC_ENHANCEMENTS); enh=${enh:-$ws/enhancements}
  if [ -f "$enh/INDEX.md" ]; then
    abs=$(cd "$enh" && pwd -P)
    case "$abs" in *[:,\ ]*) die "OPM_SRC_ENHANCEMENTS: $abs contains ':', ',' or a space; docker -v cannot mount it" ;; esac
    MOUNTS="$MOUNTS -v $abs:/src/enhancements:ro"
    top=$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" = "$abs" ]; then
      REFS="$REFS enhancements=$(git -C "$abs" rev-parse HEAD)"
    else
      REFS="$REFS enhancements=none"
    fi
  fi
  REFS=${REFS# }
  # The docs bundles, when OPM_BUNDLES names them: CAT holds the docker flags.
  CAT=""
  b=$(envval OPM_BUNDLES)
  if [ -n "$b" ]; then
    [ -f "$b/lock.json" ] || die "OPM_BUNDLES: $b holds no lock.json"
    abs=$(cd "$b" && pwd -P)
    case "$abs" in *[:,\ ]*) die "OPM_BUNDLES: $abs contains ':', ',' or a space; docker -v cannot mount it" ;; esac
    CAT="-v $abs:/bundles:ro --env OPM_BUNDLES=/bundles"
  fi
}

# Common docker run flags; the caller adds the network, mounts and command.
run() {
  versions=$(envval OPM_VERSIONS)
  set -- --rm --init --user "$(id -u):$(id -g)" \
    --env HOME=/tmp \
    --env "OPM_REQUIRE_DATES=$(envval OPM_REQUIRE_DATES)" \
    --env "OPM_DOCS_BUNDLES=$(envval OPM_DOCS_BUNDLES)" \
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
    base=$(envval OPM_BASE_URL)
    if [ -n "$base" ]; then set -- --env "OPM_BASE_URL=$base"; else set --; fi
    # shellcheck disable=SC2086 # MOUNTS is a list of -v flags without spaces inside paths
    run --network none --env "OPM_BUILD_REFS=$REFS" "$@" $MOUNTS $CAT \
      --entrypoint sh "$(tag)" /work/repo/site/scripts/build-all.sh ;;
  serve)
    sources; image >/dev/null
    port=$(envval SITE_PORT); port=${port:-1313}
    echo "run-in-image: serving on http://127.0.0.1:$port/ (Ctrl+C stops it)"
    # shellcheck disable=SC2086
    run --env TINI_KILL_PROCESS_GROUP=1 --env "SITE_PORT=$port" --env "OPM_BUILD_REFS=$REFS" \
      --publish "127.0.0.1:$port:1313" $MOUNTS $CAT \
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
    cmd="python3 $b/shots.py && python3 $b/diagrams.py"
    if [ "$mode" = qa ]; then cmd="$cmd && python3 $b/a11y.py && python3 $b/search.py && python3 $b/theme_reveal.py"; fi
    run --network none --env PYTHONDONTWRITEBYTECODE=1 --entrypoint sh "$(qa_tag)" -c "$cmd" ;;
  pull)
    # The only network step besides the image builds and versions:fetch:
    # opm-docs resolves the tabs and site versions of the pull config
    # (OPM_BUNDLES_CONFIG, default site/bundles.cue) in GHCR, verifies each
    # signature, unpacks into the output (OPM_BUNDLES_OUT, default
    # site/.bundles/) and writes its lock.json there. It mounts only the
    # config, the output, its cache, the local trees and the frozen lock; no
    # source root, no repo-wide write, no token. OPM_BUNDLES is never read
    # here: it names a tree a build reads, and the pull sweeps its output.
    cfg=$(envval OPM_BUNDLES_CONFIG); out=$(envval OPM_BUNDLES_OUT)
    cfgset=${cfg:+yes}
    cfg=${cfg:-site/bundles.cue}; out=${out:-site/.bundles}
    [ -f "$cfg" ] || die "$cfg does not exist: there is no pull config${cfgset:+ (OPM_BUNDLES_CONFIG)}"
    image >/dev/null
    mkdir -p "$out" site/.cache
    cfgabs=$(cd "$(dirname "$cfg")" && pwd -P)/$(basename "$cfg")
    outabs=$(cd "$out" && pwd -P)
    set -- pull --config /in/bundles.cue --out /out --lock /out/lock.json
    vols="--volume $cfgabs:/in/bundles.cue:ro --volume $outabs:/out --volume $repo/site/.cache:/cache"
    for p in "$repo" "$cfgabs" "$outabs"; do
      case "$p" in *[:,\ ]*) die "$p contains ':', ',' or a space; docker -v cannot mount it" ;; esac
    done
    localproj=" "; localkeys=" "
    for pair in $(envval OPM_BUNDLES_LOCAL); do
      key=${pair%%=*}; dir=${pair#*=}
      case "$key" in *@*) ;; *) die "OPM_BUNDLES_LOCAL: $pair is not <project>@<segment>=<dir>" ;; esac
      [ "$key" != "$pair" ] && [ -f "$dir/manifest.json" ] || die "OPM_BUNDLES_LOCAL: $pair names no bundle tree (no manifest.json in ${dir:-the empty path})"
      abs=$(cd "$dir" && pwd -P)
      case "$abs" in *[:,\ ]*) die "OPM_BUNDLES_LOCAL: $abs contains ':', ',' or a space; docker -v cannot mount it" ;; esac
      proj=${key%@*}; seg=${key#*@}
      vols="$vols --volume $abs:/local/$proj/$seg:ro"
      set -- "$@" --local "$key=/local/$proj/$seg"
      case "$seg" in v*) ;; *) localproj="$localproj$proj " ;; esac
      localkeys="$localkeys$key "
    done
    # A frozen pull: exactly the digests of a lock (OPM_BUNDLES_FROZEN, else a
    # committed site/bundles.frozen.json), signatures and lint still checked.
    # It still fetches blobs and the Sigstore trusted root, so it does not
    # help through a GHCR or Sigstore outage; it pins what a build reads.
    # The committed file was pulled for site/bundles.cue, and opm-docs refuses
    # it for any other config (C7), so another config skips it.
    frozen=$(envval OPM_BUNDLES_FROZEN)
    if [ -z "$frozen" ] && [ -f site/bundles.frozen.json ]; then
      if [ -n "$cfgset" ]; then
        echo "run-in-image: site/bundles.frozen.json not applied: it was pulled for site/bundles.cue, and OPM_BUNDLES_CONFIG names $cfg (OPM_BUNDLES_FROZEN=<lock> pins this pull)"
      else
        frozen=site/bundles.frozen.json
      fi
    fi
    if [ -n "$frozen" ]; then
      [ -f "$frozen" ] || die "OPM_BUNDLES_FROZEN: $frozen is not a file"
      abs=$(cd "$(dirname "$frozen")" && pwd -P)/$(basename "$frozen")
      case "$abs" in *[:,\ ]*) die "the frozen lock $abs contains ':', ',' or a space; docker -v cannot mount it" ;; esac
      echo "run-in-image: frozen pull: exactly the digests $frozen names (remove it to resolve tags again)"
      vols="$vols --volume $abs:/in/frozen.json:ro"
      set -- "$@" --frozen /in/frozen.json
    fi
    # The tabs of bundles.cue: the quoted keys of its tabs block
    # ("catalog-opm": {...}; bundles.cue says to keep them quoted). Network
    # only when some tab is not local; when no key is found, network too, so
    # a misread never turns into an offline pull that cannot resolve. Docs
    # bundles (C16) the same way: the quoted keys of the docs block, each of
    # which must be local for every site version (the quoted keys of the
    # versions block), as <project>@<version>; a config without versions
    # pulls no docs bundle, so its docs block needs nothing local.
    keys_of() { awk -v b="$1" '$0 ~ "^" b ":[[:space:]]*\\{" { on = 1; next } on && /^\}/ { on = 0 } on && match($0, /^[[:space:]]*"[a-z0-9]+(-[a-z0-9]+)*"[[:space:]]*:/) { k = substr($0, RSTART, RLENGTH); gsub(/[[:space:]":]/, "", k); print k }' "$cfg"; }
    net=none; tabs=$(keys_of tabs)
    [ -n "$tabs" ] || net=bridge
    for proj in $tabs; do
      case "$localproj" in *" $proj "*) ;; *) net=bridge ;; esac
    done
    sites=$(awk 'match($0, /^versions:[[:space:]]*"v[0-9]+\.[0-9]+"/) { k = substr($0, RSTART, RLENGTH); sub(/^versions:[[:space:]]*/, "", k); gsub(/"/, "", k); print k; next } /^versions:[[:space:]]*\{/ { on = 1; next } on && /^\}/ { on = 0 } on && match($0, /^[[:space:]]*"v[0-9]+\.[0-9]+"[[:space:]]*:/) { k = substr($0, RSTART, RLENGTH); gsub(/[[:space:]":]/, "", k); print k }' "$cfg")
    if [ -n "$sites" ]; then
      dprojs=$(keys_of docs)
      [ -n "$dprojs" ] || net=bridge
      for sv in $sites; do
        for proj in $dprojs; do
          case "$localkeys" in *" $proj@$sv "*) ;; *) net=bridge ;; esac
        done
      done
    elif grep -q '^versions:' "$cfg"; then
      net=bridge
    fi
    # The frozen marker: gen-stamp.sh records "frozen": true while it exists.
    rm -f "$out/frozen"
    echo "run-in-image: pull of $cfg into $out/ (network: $net)"
    # shellcheck disable=SC2086 # vols is a list of --volume flags without spaces inside paths
    docker run --rm --init --user "$(id -u):$(id -g)" --network "$net" \
      --env HOME=/tmp --env XDG_CACHE_HOME=/cache $vols \
      --entrypoint opm-docs "$(tag)" "$@"
    if [ -n "$frozen" ]; then echo "$frozen" > "$out/frozen"; fi ;;
  *) sed -n '2,19p' "$0" >&2; exit 2 ;;
esac
