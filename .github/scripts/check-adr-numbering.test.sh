#!/usr/bin/env bash
# Test cho check-adr-numbering.sh (ADR-046). Dựng thư mục specs fixture tạm (nhiều
# file) rồi kiểm exit code + thông báo. Chạy tay: bash .github/scripts/check-adr-numbering.test.sh
# KHÔNG wire vào CI — test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-adr-numbering.sh"
fails=0

# assert <label> <expected-exit> <dir> [needle]
assert() {
  local label="$1" expected="$2" dir="$3" needle="${4:-}"
  local out rc
  out="$(bash "$SCRIPT" "$dir" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$dir"
}

# 1. PASS: distinct numbers across two specs.
d="$(mktemp -d)"
printf '%s\n' '### ADR-050: alpha' > "$d/a-design.md"
printf '%s\n' '### ADR-051: beta'  > "$d/b-design.md"
assert "pass: distinct numbers" 0 "$d"

# 2. FAIL: same number in two different specs.
d="$(mktemp -d)"
printf '%s\n' '### ADR-050: alpha' > "$d/a-design.md"
printf '%s\n' '### ADR-050: gamma' > "$d/b-design.md"
assert "fail: cross-file duplicate" 1 "$d" "Duplicate ADR number  ADR-050"

# 3. FAIL: mixed heading levels (## vs ###) — the bug that hid ADR-001/002.
d="$(mktemp -d)"
printf '%s\n' '## ADR-051: alpha'  > "$d/a-design.md"
printf '%s\n' '### ADR-051: gamma' > "$d/b-design.md"
assert "fail: mixed ## and ### levels" 1 "$d" "Duplicate ADR number  ADR-051"

# 4. PASS: a fenced code example of an ADR heading is not counted.
d="$(mktemp -d)"
printf '%s\n' '### ADR-052: alpha' > "$d/a-design.md"
printf '%s\n' 'prose' '```' '### ADR-052: example in a fence' '```' > "$d/b-design.md"
assert "pass: fenced example ignored" 0 "$d"

# 5. FAIL: same number twice within one spec.
d="$(mktemp -d)"
printf '%s\n' '### ADR-053: alpha' 'body' '### ADR-053: dup' > "$d/a-design.md"
assert "fail: duplicate within one file" 1 "$d" "Duplicate ADR number  ADR-053"

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
