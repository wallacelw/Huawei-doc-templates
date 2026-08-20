#!/bin/bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILTER="$REPO_ROOT/templates/guide/guide-pandoc.lua"
TESTS_DIR="$REPO_ROOT/tests"
PASS=0; FAIL=0

for tex_file in "$TESTS_DIR/cases/"*.tex; do
  name=$(basename "$tex_file" .tex)
  expected="$TESTS_DIR/expected/$name.md.expected"
  if [ ! -f "$expected" ]; then
    echo "SKIP: $name (no expected output)"
    continue
  fi
  actual=$(pandoc -f latex+raw_tex --lua-filter="$FILTER" -t markdown --wrap=none "$tex_file" 2>/dev/null)
  if [ "$actual" = "$(cat "$expected")" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    diff <(cat "$expected") <(echo "$actual") | head -10
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
