#!/usr/bin/env bash
set -euo pipefail

# openspec-check-test.sh: test openspec-check.sh on sandbox trees. Each case builds one
# active change and states whether the check must pass (0) or fail (1).

here="$(cd "$(dirname "$0")" && pwd)"
check="$here/openspec-check.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
n=0
bad=0

# run_case <name> <expected exit> <design.md text>; the tree also holds AGENTS.md, README.md and CONSTITUTION.md.
run_case() {
  local name="$1" want="$2" text="$3" dir="$tmp/case$n"
  n=$((n + 1))
  mkdir -p "$dir/openspec/changes/c"
  : > "$dir/AGENTS.md"; mkdir -p "$dir/references"; : > "$dir/references/site-urls.md"; : > "$dir/README.md"; : > "$dir/CONSTITUTION.md"
  printf '%s\n' "$text" > "$dir/openspec/changes/c/design.md"
  local got=0
  bash "$check" "$dir" >/dev/null 2>&1 || got=$?
  if [ "$got" != "$want" ]; then
    echo "openspec-check-test: FAIL $name: want exit $want, got $got" >&2
    bad=1
  fi
}

run_case "missing section" 1 $'## Context\n\nx'
# The comment names every root file the tree holds, so only the empty section fails it.
run_case "unfilled template (comment only)" 1 $'## Durable decisions\n\n<!-- Every decision, and where it lands:\n     AGENTS.md, CONSTITUTION.md, README.md, or "stays with the change". Write "None." if empty. -->'
run_case "None." 0 $'## Durable decisions\n\nNone.'
run_case "stays with the change" 0 $'## Durable decisions\n\n- A pitfall. It stays with the change.'
run_case "existing file in backticks" 0 $'## Durable decisions\n\n- Lands in `AGENTS.md`.'
run_case "missing file in backticks" 1 $'## Durable decisions\n\n- Lands in `AGENTS.md` and `TODO.md`.'
run_case "existing file without backticks" 0 $'## Durable decisions\n\n- Lands in AGENTS.md, section 2.'
run_case "one existing and one missing file" 1 $'## Durable decisions\n\n- Lands in AGENTS.md and TODO.md.'
run_case "existing references file" 0 $'## Durable decisions\n\n- Lands in `references/site-urls.md`.'
run_case "missing references file" 1 $'## Durable decisions\n\n- Lands in `references/nope.md`.'
run_case "no target named" 1 $'## Durable decisions\n\n- A rule that matters.'

if [ "$bad" = 0 ]; then
  echo "OK: openspec-check.sh passes its $n cases."
fi
exit "$bad"
