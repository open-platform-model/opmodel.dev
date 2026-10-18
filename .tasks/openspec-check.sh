#!/usr/bin/env bash
set -euo pipefail

# openspec-check.sh: check the "Durable decisions" section of every active change.
#
# openspec/config.yaml (operations.archive.guidance) says an archived change is never the
# only home of a site or authoring rule. This script is the check behind that rule. For each
# openspec/changes/<name>/design.md (the archive is not read):
#
#   1. the "## Durable decisions" section must exist;
#   2. HTML comments are removed first, so the unfilled template (a comment only) is empty;
#   3. if what is left is not "None.", it must name a target: a references/ file, AGENTS.md, CONSTITUTION.md,
#      README.md, a contributor note, or the words "stays with the change";
#   4. every root file it names (AGENTS.md, CONSTITUTION.md, README.md, TODO.md) must exist.
#
# Run from the repo root, or pass the root as the first argument.

export LC_ALL=C

root="${1:-.}"
fail=0

# strip_comments removes <!-- ... --> blocks, also across lines.
strip_comments() {
  awk '{
    line = $0; out = ""
    while (1) {
      if (inc) {
        i = index(line, "-->")
        if (!i) { line = ""; break }
        line = substr(line, i + 3); inc = 0
      } else {
        i = index(line, "<!--")
        if (!i) break
        out = out substr(line, 1, i - 1); line = substr(line, i + 4); inc = 1
      }
    }
    print out line
  }'
}

shopt -s nullglob
for design in "$root"/openspec/changes/*/design.md; do
  change="$(basename "$(dirname "$design")")"
  [ "$change" = "archive" ] && continue

  if ! grep -q '^## Durable decisions' "$design"; then
    echo "openspec-check: $change: design.md has no '## Durable decisions' section" >&2
    fail=1
    continue
  fi

  section="$(strip_comments < "$design" | awk '/^## Durable decisions/{f=1;next} /^## /{f=0} f')"

  # First non-blank line starting with "None" means nothing is promoted.
  first="$(printf '%s\n' "$section" | grep -v '^[[:space:]]*$' | head -n1 || true)"
  case "$first" in
    None.*|None\ *) continue ;;
    "") echo "openspec-check: $change: 'Durable decisions' is empty; write 'None.' or name a target" >&2
        fail=1
        continue ;;
  esac

  if ! printf '%s\n' "$section" | grep -q -E 'references/|AGENTS\.md|CONSTITUTION\.md|README\.md|contributor note|stays with the change'; then
    echo "openspec-check: $change: 'Durable decisions' names no target (a references/ file, AGENTS.md, CONSTITUTION.md, README.md, a contributor note or 'stays with the change')" >&2
    fail=1
  fi

  while IFS= read -r path; do
    if [ ! -e "$root/$path" ]; then
      echo "openspec-check: $change: 'Durable decisions' names $path, which does not exist" >&2
      fail=1
    fi
  done < <(printf '%s\n' "$section" | grep -o -E '\b(AGENTS|CONSTITUTION|README|TODO)\.md' | sort -u || true)
done

exit "$fail"
