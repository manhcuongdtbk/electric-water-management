#!/usr/bin/env bash
# Test for check-role-count.sh (ADR-062). Builds fixture schema, matrix, and doc
# files in a temp dir, then checks exit code + output needle. Run manually:
#   bash .github/scripts/check-role-count.test.sh
# NOT wired into CI (keeps CI surface small); human-run test for guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-role-count.sh"
fails=0

# mk <schema-enum-line> <matrix-roles-line> <hanh-vi> <chieu-test> <agents> <thiet-ke>
# → prints temp dir path with 6 fixture files
mk() {
  local tmp; tmp="$(mktemp -d)"
  printf '%s\n' "$1" > "$tmp/schema.rb"
  printf '%s\n' "$2" > "$tmp/matrix.rb"
  printf '%s\n' "$3" > "$tmp/hanh_vi.md"
  printf '%s\n' "$4" > "$tmp/chieu_test.md"
  printf '%s\n' "$5" > "$tmp/agents.md"
  printf '%s\n' "$6" > "$tmp/thiet_ke.md"
  printf '%s' "$tmp"
}

# assert <label> <expected-exit> <tmp-dir> [needle]
assert() {
  local label="$1" expected="$2" tmp="$3" needle="${4:-}"
  local out rc
  out="$(bash "$SCRIPT" "$tmp/schema.rb" "$tmp/matrix.rb" "$tmp/hanh_vi.md" "$tmp/chieu_test.md" "$tmp/agents.md" "$tmp/thiet_ke.md" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

SCHEMA_5='  create_enum "user_role", ["technician", "system_admin", "unit_admin", "commander", "division_commander"]'
MATRIX_7='  ROLES = %i[sa dc ua_zm ua cmd_zm cmd tech].freeze'

# 1. PASS: all numbers match (enum=5, effective=7)
tmp="$(mk \
  "$SCHEMA_5" \
  "$MATRIX_7" \
  "## 1. 7 vai trò thực tế" \
  "Hệ thống có 5 enum nhưng 7 vai trò thực tế:" \
  "hệ thống có 7 vai trò thực tế (5 enum)" \
  "5 vai trò: 4 nghiệp vụ + 1 kỹ thuật"
)"
assert "pass: all counts match" 0 "$tmp" "role counts consistent (enum=5, effective=7)"

# 2. FAIL: doc says wrong effective count (says 6 instead of 7)
tmp="$(mk \
  "$SCHEMA_5" \
  "$MATRIX_7" \
  "## 1. 6 vai trò thực tế" \
  "Hệ thống có 7 vai trò thực tế:" \
  "hệ thống có 7 vai trò thực tế" \
  "5 vai trò: 4 nghiệp vụ + 1 kỹ thuật"
)"
assert "fail: wrong effective count in hanh vi" 1 "$tmp" "says 6 vai"

# 3. FAIL: doc says wrong enum count (says 4 instead of 5)
tmp="$(mk \
  "$SCHEMA_5" \
  "$MATRIX_7" \
  "## 1. 7 vai trò thực tế" \
  "7 vai trò thực tế:" \
  "7 vai trò thực tế" \
  "4 vai trò: 3 nghiệp vụ + 1 kỹ thuật"
)"
assert "fail: wrong enum count in thiet ke" 1 "$tmp" "says 4 vai"

# 4. PASS: docs have no role count mentions (no matches = no violations)
tmp="$(mk \
  "$SCHEMA_5" \
  "$MATRIX_7" \
  "Some unrelated content" \
  "No role mentions here" \
  "Just regular text" \
  "Also unrelated"
)"
assert "pass: no role mentions in docs" 0 "$tmp" "role counts consistent"

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
