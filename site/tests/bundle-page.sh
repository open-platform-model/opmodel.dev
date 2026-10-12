# Helpers that edit a copy of the fixture docs bundles the way a producer's
# next build would, for test-site.sh and the check cases' setup.sh. Sourced,
# never run. POSIX sh and jq. Every function takes the bundles directory B
# (a site copy's .bundles/, which holds lock.json and _versions/) first.
#
#   add_page B PROJECT PATH FILE   copy FILE to _versions/v1.0/PROJECT/content/PATH and list it
#                                  in the manifest (source and edit docs/site/PATH, authored)
#   drop_page B PROJECT PATH       remove that page and its manifest entry, in every version
#   drop_tabs B                    remove every Catalogs tab bundle: the lock's tab entries and
#                                  history, and their trees (a build with no Catalogs section)
#   add_version B NAME             copy v1.0's docs bundles as site version NAME: the trees under
#                                  _versions/NAME/ and the lock's docs entries with site NAME

add_page() {
  _d=$1/_versions/v1.0/$2
  [ -f "$_d/manifest.json" ] || { echo "add_page: $_d holds no manifest.json" >&2; return 1; }
  mkdir -p "$(dirname "$_d/content/$3")"
  cp "$4" "$_d/content/$3"
  jq --arg p "$3" '.pages = ([.pages[] | select(.path != $p)] + [{path: $p, source: ("docs/site/" + $p), generated: false, edit: ("docs/site/" + $p)}] | sort_by(.path))' \
    "$_d/manifest.json" > "$_d/manifest.tmp" && mv "$_d/manifest.tmp" "$_d/manifest.json"
}

drop_page() {
  for _d in "$1"/_versions/*/"$2"; do
    [ -f "$_d/manifest.json" ] || continue
    rm -f "$_d/content/$3"
    jq --arg p "$3" '.pages = [.pages[] | select(.path != $p)]' "$_d/manifest.json" > "$_d/manifest.tmp" && mv "$_d/manifest.tmp" "$_d/manifest.json"
  done
}

drop_tabs() {
  for _p in $(jq -r '[.bundles[] | select(.root | startswith("/catalogs/")) | .project] | unique | .[]' "$1/lock.json"); do
    rm -rf "${1:?}/$_p"
  done
  jq 'del(.bundles[] | select(.root | startswith("/catalogs/"))) | del(.history)' "$1/lock.json" > "$1/lock.tmp" && mv "$1/lock.tmp" "$1/lock.json"
}

add_version() {
  cp -R "$1/_versions/v1.0" "$1/_versions/$2"
  jq --arg v "$2" '.docs += [.docs[] | select(.site == "v1.0") | .site = $v | .dir = ("_versions/" + $v + "/" + .project)]' \
    "$1/lock.json" > "$1/lock.tmp" && mv "$1/lock.tmp" "$1/lock.json"
}
