#!/usr/bin/env bash
# Test for check-nv-traceability.sh (ADR-065). Build temp fixtures then verify
# exit code + output for each rule. Run manually:
#   bash .github/scripts/check-nv-traceability.test.sh
# NOT wired into CI (keep CI surface small); human-run test for guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-nv-traceability.sh"
fails=0

# mk <canonical-body> <test-file-body> [deferred-body]
# → prints path to temp root dir with canonical.md, spec/, and deferred.txt
mk() {
  local tmp; tmp="$(mktemp -d)"
  printf '%s\n' "$1" > "$tmp/canonical.md"
  mkdir -p "$tmp/spec"
  printf '%s\n' "$2" > "$tmp/spec/fixture_spec.rb"
  if [[ $# -ge 3 ]]; then
    printf '%s\n' "$3" > "$tmp/deferred.txt"
  else
    # Create empty deferred file (comments only)
    printf '# empty deferred\n' > "$tmp/deferred.txt"
  fi
  printf '%s' "$tmp"
}

# assert <label> <expected-exit> <canonical-body> <test-body> [deferred-body] [needle]
assert() {
  local label="$1" expected="$2" canonical="$3" testbody="$4"
  local deferred_body="${5:-}" needle="${6:-}"
  local tmp out rc
  if [[ -n "$deferred_body" ]]; then
    tmp="$(mk "$canonical" "$testbody" "$deferred_body")"
  else
    tmp="$(mk "$canonical" "$testbody")"
  fi
  out="$(bash "$SCRIPT" "$tmp/canonical.md" "$tmp/spec" "$tmp/deferred.txt" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

# --- Test cases ---

# 1. PASS: all anchors have tests (via it descriptions)
assert "pass: all anchors have tests" 0 \
  'Some text <a id="NV-alpha"></a> and <a id="NV-beta"></a> more text' \
  'it "NV-alpha: tests alpha behavior" do; end
it "NV-beta: tests beta behavior" do; end'

# 2. FAIL R1: anchor without test
assert "fail: R1 anchor without test" 1 \
  'Some text <a id="NV-lonely"></a> end' \
  'it "does something unrelated" do; end' \
  "" \
  "R1 missing test: NV-lonely"

# 3. PASS: anchor deferred with #issue
assert "pass: anchor deferred" 0 \
  'Some text <a id="NV-later"></a> end' \
  'it "unrelated" do; end' \
  "NV-later #123"

# 4. FAIL R2: deferred without #issue
assert "fail: R2 deferred without issue" 1 \
  'Some text <a id="NV-oops"></a> end' \
  'it "NV-oops: has test" do; end' \
  "NV-oops" \
  "R2 unlinked deferred: NV-oops"

# 5. FAIL R3: orphan test tag (no anchor in canonical)
assert "fail: R3 orphan test tag" 1 \
  'Some text <a id="NV-real"></a> end' \
  'it "NV-real: ok" do; end
it "NV-nonexistent: ghost" do; end' \
  "" \
  "R3 orphan test tag: NV-nonexistent"

# 6. FAIL R4: orphan deferred (no anchor in canonical)
assert "fail: R4 orphan deferred" 1 \
  'Some text <a id="NV-real"></a> end' \
  'it "NV-real: ok" do; end' \
  "NV-nonexistent #99" \
  "R4 orphan deferred: NV-nonexistent"

# 7. PASS: coverage via demo_nv (not in it description)
assert "pass: coverage via demo_nv" 0 \
  'Some text <a id="NV-demo-item"></a> end' \
  'describe "something", demo_nv: %w[NV-demo-item] do; end'

# 8. PASS: empty deferred file (comments only)
assert "pass: empty deferred file" 0 \
  'Some text <a id="NV-covered"></a> end' \
  'it "NV-covered: has test" do; end' \
  "# Just comments here
# Another comment"

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
