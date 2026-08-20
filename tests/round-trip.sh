#!/bin/bash
# round-trip.sh — Verify multi-format output consistency
# Checks that heading counts, image counts, and code block counts
# are consistent across Markdown and HTML outputs.
# Allows ±1 tolerance (HTML template adds a title <h1>, etc.).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILTER="$REPO_ROOT/templates/guide/guide-pandoc.lua"
HTML_TMPL="$REPO_ROOT/templates/guide/guide-template.html"
PASS=0; FAIL=0

# Safe grep count: grep -c prints "0" and exits 1 when no matches,
# so we suppress the error and capture just the number.
count() { local n; n=$(grep -c "$1" "$2" 2>/dev/null || true); echo "${n:-0}"; }

check() {
  local label=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $label ($actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

check_tol() {
  local label=$1 expected=$2 actual=$3
  local diff=$((expected > actual ? expected - actual : actual - expected))
  if [ "$diff" -le 1 ]; then
    echo "  PASS: $label (md=$expected html=$actual, ±1 ok)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (md=$expected html=$actual, diff=$diff)"
    FAIL=$((FAIL + 1))
  fi
}

for sample in examples/guide/en examples/guide/pt; do
  name=$(basename "$(dirname "$sample")")/$(basename "$sample")
  echo "=== $name ==="

  # Generate Markdown and HTML
  pandoc -f latex+raw_tex --lua-filter="$FILTER" -t markdown --wrap=none \
    "$REPO_ROOT/$sample/main.tex" -o /tmp/rt.md 2>/dev/null
  pandoc -f latex+raw_tex --lua-filter="$FILTER" --template="$HTML_TMPL" -s -t html5 \
    "$REPO_ROOT/$sample/main.tex" -o /tmp/rt.html 2>/dev/null

  # Count headings
  md_h1=$(count '^# ' /tmp/rt.md)
  md_h2=$(count '^## ' /tmp/rt.md)
  html_h1=$(count '<h1' /tmp/rt.html)
  html_h2=$(count '<h2' /tmp/rt.html)

  check_tol "H1 count MD vs HTML" "$md_h1" "$html_h1"
  check_tol "H2 count MD vs HTML" "$md_h2" "$html_h2"

  # Count images
  md_img=$(count '!\[' /tmp/rt.md)
  html_img=$(count '<img' /tmp/rt.html)
  check_tol "Image count MD vs HTML" "$md_img" "$html_img"

  # Count code blocks (MD uses ``` open+close, so divide by 2)
  md_code=$(count '^```' /tmp/rt.md)
  html_code=$(count '<pre><code' /tmp/rt.html)
  check_tol "Code block count MD vs HTML" "$((md_code / 2))" "$html_code"

  # Check no raw LaTeX in Markdown (hard check, must be 0)
  raw_latex=$(count '{=latex}' /tmp/rt.md)
  check "No raw LaTeX in MD" "0" "$raw_latex"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
rm -f /tmp/rt.md /tmp/rt.html
exit $FAIL
