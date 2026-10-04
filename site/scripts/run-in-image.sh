#!/bin/sh
# Host side of the site tasks: runs one step in the build image. POSIX sh;
# needs git (this repository's own commit and the site-owned pages' dates),
# jq and docker on the host, nothing else. No step reads another repository:
# every source page arrives in a signed docs bundle (task bundles:pull).
#
#   run-in-image.sh image    build opmodel-dev-hugo:<first 12 hex of sha256(Dockerfile)> if missing (network)
#   run-in-image.sh tag      print that tag
#   run-in-image.sh pull     opm-docs pull of site/bundles.cue in the image -> site/.bundles/ (network,
#                            unless every tab and docs bundle is local; OPM_BUNDLES_CONFIG and
#                            OPM_BUNDLES_OUT choose another config and output)
#   run-in-image.sh build    build-all.sh in the image, --network none -> site/public/
#   run-in-image.sh serve    serve.sh in the image, published on 127.0.0.1:${SITE_PORT:-1313} only
#   run-in-image.sh preview  a static server over the built site/public/, on 127.0.0.1:${SITE_PORT:-1313} only
#   run-in-image.sh test     test-site.sh in the image, --network none; reads fixtures only
#   run-in-image.sh qa-image build opmodel-dev-qa:<first 12 hex of sha256(site/tests/browser/Dockerfile)> if missing (network)
#   run-in-image.sh qa-tag   print that tag
#   run-in-image.sh shots    site/tests/browser/shots.py and diagrams.py over the built site/public/, --network none -> site/.shots/
#   run-in-image.sh qa       shots.py and diagrams.py, then a11y.py, search.py and theme_reveal.py, --network none, no published port
#
# Environment. Each is read from the environment first; an empty value counts as unset.
#   SITE_PORT          host port for serve (default 1313).
#   OPM_REQUIRE_DATES  1 fails the build when a site-owned page has no git date (default 0).
#   OPM_BASE_URL       the site's base URL, an absolute http(s) URL ending in /, which may carry
#                      a path (https://example.org/docs/). Passed into the container in build
#                      mode only, and only when set; unset, the build uses hugo.toml's baseURL.
#                      serve, test and the two-version test never see it.
#   OPM_BUNDLES        a directory of unpacked docs bundles with their lock.json (what opm-docs
#                      pull writes: task build:edge's site/.edge/bundles, the test fixtures
#                      site/tests/fixtures/bundles), relative to the repo or absolute. Build and
#                      serve mount it read-only at /bundles and pass OPM_BUNDLES=/bundles, so
#                      every bundle comes from it instead of site/.bundles/
#                      (site/scripts/sections.sh). Build and serve only: pull never reads it
#                      (pull sweeps its output, so a tree a build reads is never a target).
#   OPM_BUNDLES_CONFIG pull mode only: the pull config, relative to the repo or absolute; default
#                      site/bundles.cue. task build:edge names site/.edge/bundles.cue
#                      (site/scripts/edge-config.sh). When it is set, a committed
#                      site/bundles.frozen.json is not applied (it was pulled for bundles.cue);
#                      an explicit OPM_BUNDLES_FROZEN still is.
#   OPM_BUNDLES_OUT    pull mode only: the directory the pull writes and sweeps, with its
#                      lock.json, relative to the repo or absolute; default site/.bundles. It must
#                      be a dot-directory under site/ that holds no tracked file and, when not
#                      empty, a lock.json (the sweep removes whatever the pull did not write).
#   OPM_BUNDLES_LOCAL  pull mode only: <project>@<segment>=<host dir> ..., space-separated, each a
#                      local bundle tree (an opm-docs build output) pull takes instead of the
#                      registry (docs-kit C7 --local): a tab's segment (4.5, edge), or, for a docs
#                      project, the site version it is placed in (cli@v1.0=<dir>, C16). Each is
#                      mounted read-only. A pull whose every tab and every docs project of every
#                      site version of the pull config is named here runs with --network none.
#   OPM_BUNDLES_FROZEN pull mode only: a lock to pull exactly (opm-docs pull --frozen), e.g. the
#                      build job's lock in CI; default site/bundles.frozen.json when it exists and
#                      OPM_BUNDLES_CONFIG is unset.
# Build and serve first run site/scripts/gen-site-dates.sh here, on the host (git cannot read a
# worktree's history in the container), and pass this repository's commit as OPM_SITE_COMMIT
# (the build stamp); never set it by hand.
#
# Containers: --rm --init --user <uid>:<gid>, no --name. The repo is mounted at /work/repo,
# never with :z, and OPM_BUNDLES read-only at /bundles.
set -eu
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

# The docs bundles, when OPM_BUNDLES names them: CAT holds the docker flags.
bundles() {
  CAT=""
  b=$(envval OPM_BUNDLES)
  if [ -n "$b" ]; then
    [ -f "$b/lock.json" ] || die "OPM_BUNDLES: $b holds no lock.json"
    abs=$(cd "$b" && pwd -P)
    case "$abs" in *[:,\ ]*) die "OPM_BUNDLES: $abs contains ':', ',' or a space; docker -v cannot mount it" ;; esac
    CAT="-v $abs:/bundles:ro --env OPM_BUNDLES=/bundles"
  fi
}

# The host steps of a build or the dev server: the site-owned pages' dates
# (data/opm/lastmod.json) and this repository's commit (SITE, "" when git
# cannot name one).
host_steps() {
  sh "$repo/site/scripts/gen-site-dates.sh"
  SITE=$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)
}

# Common docker run flags; the caller adds the network, mounts and command.
run() {
  exec docker run --rm --init --user "$(id -u):$(id -g)" \
    --env HOME=/tmp \
    --env "OPM_REQUIRE_DATES=$(envval OPM_REQUIRE_DATES)" \
    --volume "$repo:/work/repo" \
    "$@"
}

case "$mode" in
  tag) tag ;;
  image) image ;;
  build)
    bundles; image >/dev/null; host_steps
    echo "run-in-image: build of opmodel.dev ${SITE:-(no commit)}"
    base=$(envval OPM_BASE_URL)
    if [ -n "$base" ]; then set -- --env "OPM_BASE_URL=$base"; else set --; fi
    # shellcheck disable=SC2086 # CAT is a list of flags without spaces inside paths
    run --network none --env "OPM_SITE_COMMIT=$SITE" "$@" $CAT \
      --entrypoint sh "$(tag)" /work/repo/site/scripts/build-all.sh ;;
  serve)
    bundles; image >/dev/null; host_steps
    port=$(envval SITE_PORT); port=${port:-1313}
    echo "run-in-image: serving on http://127.0.0.1:$port/ (Ctrl+C stops it)"
    # shellcheck disable=SC2086
    run --env TINI_KILL_PROCESS_GROUP=1 --env "SITE_PORT=$port" --env "OPM_SITE_COMMIT=$SITE" \
      --publish "127.0.0.1:$port:1313" $CAT \
      --entrypoint sh "$(tag)" /work/repo/site/scripts/serve.sh </dev/null ;;
  preview)
    [ -f site/public/index.html ] || die "site/public/ holds no build; run the build task first"
    image >/dev/null
    port=$(envval SITE_PORT); port=${port:-1313}
    echo "run-in-image: previewing site/public/ on http://127.0.0.1:$port/ (Ctrl+C stops it)"
    run --env TINI_KILL_PROCESS_GROUP=1 --publish "127.0.0.1:$port:1313" \
      --entrypoint sh "$(tag)" -c 'printf "E404:404.html\n" > /tmp/httpd.conf && exec httpd -f -p 1313 -h /work/repo/site/public -c /tmp/httpd.conf' </dev/null ;;
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
    # The only network step besides the image builds:
    # opm-docs resolves the tabs and site versions of the pull config
    # (OPM_BUNDLES_CONFIG, default site/bundles.cue) in GHCR, verifies each
    # signature, unpacks into the output (OPM_BUNDLES_OUT, default
    # site/.bundles/) and writes its lock.json there. It mounts only the
    # config, the output, its cache, the local trees and the frozen lock; no
    # repo-wide write, no token. OPM_BUNDLES is never read
    # here: it names a tree a build reads, and the pull sweeps its output.
    cfg=$(envval OPM_BUNDLES_CONFIG); out=$(envval OPM_BUNDLES_OUT)
    cfg=${cfg:-site/bundles.cue}; out=${out:-site/.bundles}
    [ -f "$cfg" ] || die "$cfg does not exist: there is no pull config (OPM_BUNDLES_CONFIG, default site/bundles.cue)"
    cfgabs=$(cd "$(dirname "$cfg")" && pwd -P)/$(basename "$cfg")
    # cfgset: the pull config is not site/bundles.cue (whatever names it).
    cfgset=""; [ "$cfgabs" = "$repo/site/bundles.cue" ] || cfgset=yes
    # The output is swept: opm-docs pull removes every entry it did not
    # write, subdirectories included. So it must be a dot-directory under
    # site/ (site/.bundles, site/.edge/bundles), hold no tracked file, and,
    # when it exists and is not empty, hold a lock.json (an earlier pull).
    case "$out" in /*) outabs=$out ;; *) outabs=$repo/$out ;; esac
    case "/$outabs/" in */../*|*/./*) die "OPM_BUNDLES_OUT=$out: name the directory without . or .. segments" ;; esac
    outabs=${outabs%/}
    if [ -e "$outabs" ] || [ -L "$outabs" ]; then
      [ -d "$outabs" ] || die "OPM_BUNDLES_OUT=$out is not a directory"
      outabs=$(cd "$outabs" && pwd -P)
    fi
    case "$outabs" in
      "$repo"/site/.[!.]*|"$repo"/site/..?*) ;;
      *) die "OPM_BUNDLES_OUT=$out: the pull sweeps its output, so name a dot-directory under site/ (site/.bundles, site/.edge/bundles)" ;;
    esac
    if [ -d "$outabs" ] && [ -n "$(ls -A "$outabs")" ] && [ ! -f "$outabs/lock.json" ]; then
      die "OPM_BUNDLES_OUT=$out holds files but no lock.json: it is not a pull's output, and the pull would sweep it"
    fi
    if git -C "$repo" ls-files --error-unmatch -- "$outabs" >/dev/null 2>&1; then
      die "OPM_BUNDLES_OUT=$out holds files git tracks; the pull would sweep them"
    fi
    image >/dev/null
    mkdir -p "$outabs" site/.cache
    # Again on the created path, in case a parent was a symbolic link.
    outabs=$(cd "$outabs" && pwd -P)
    case "$outabs" in
      "$repo"/site/.[!.]*|"$repo"/site/..?*) ;;
      *) die "OPM_BUNDLES_OUT=$out resolves to $outabs, outside the dot-directories under site/" ;;
    esac
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
        echo "run-in-image: site/bundles.frozen.json not applied: it was pulled for site/bundles.cue, and the pull config is $cfg (OPM_BUNDLES_FROZEN=<lock> pins this pull)"
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
    rm -f "$outabs/frozen"
    echo "run-in-image: pull of $cfg into $out/ (network: $net)"
    # shellcheck disable=SC2086 # vols is a list of --volume flags without spaces inside paths
    docker run --rm --init --user "$(id -u):$(id -g)" --network "$net" \
      --env HOME=/tmp --env XDG_CACHE_HOME=/cache $vols \
      --entrypoint opm-docs "$(tag)" "$@"
    if [ -n "$frozen" ]; then echo "$frozen" > "$outabs/frozen"; fi ;;
  *) sed -n '2,20p' "$0" >&2; exit 2 ;;
esac
