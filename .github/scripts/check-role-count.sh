#!/usr/bin/env bash
# Guardrail role count (ADR-062): enum count from schema.rb + effective role count
# from role_access_matrix.rb must match numbers stated in 4 canonical docs.
# FAIL-LOUD: mismatch → exit 1.
set -uo pipefail

SCHEMA="${1:-db/schema.rb}"
MATRIX="${2:-spec/support/role_access_matrix.rb}"

HANH_VI="${3:-docs/V2_HANH_VI_HE_THONG.md}"
CHIEU_TEST="${4:-docs/V2_CHIEU_TEST.md}"
AGENTS="${5:-AGENTS.md}"
THIET_KE="${6:-docs/V2_THIET_KE_HE_THONG.md}"

LABEL="check-role-count"

# --- extract enum count from schema.rb ---
enum_line="$(grep 'create_enum "user_role"' "$SCHEMA" 2>/dev/null || true)"
if [[ -z "$enum_line" ]]; then
  echo "✗ $LABEL: cannot find create_enum \"user_role\" in $SCHEMA"
  exit 1
fi
# Count comma-separated values inside the array brackets.
# Extract the [...] part, remove brackets/quotes, count words.
enum_values="$(printf '%s' "$enum_line" | sed 's/.*\[//; s/\].*//' | tr ',' '\n' | sed 's/[" ]//g' | grep -c '.')"
enum_count="$enum_values"

# --- extract effective role count from role_access_matrix.rb ---
roles_line="$(grep 'ROLES = %i\[' "$MATRIX" 2>/dev/null || true)"
if [[ -z "$roles_line" ]]; then
  echo "✗ $LABEL: cannot find ROLES = %i[...] in $MATRIX"
  exit 1
fi
# Extract symbols between %i[ and ], count words.
effective_count="$(printf '%s' "$roles_line" | sed 's/.*%i\[//; s/\].*//' | tr ' ' '\n' | grep -c '.')"

# --- check docs ---
violations=0

# check_effective <file> — scan for "N vai trò thực tế", compare N with effective_count
check_effective() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # grep lines containing a digit followed by "vai trò thực tế"
  while IFS= read -r match; do
    # extract the number immediately before "vai trò thực tế"
    n="$(printf '%s' "$match" | grep -oE '[0-9]+ vai' | head -1 | grep -oE '[0-9]+')"
    [[ -z "$n" ]] && continue
    if [[ "$n" -ne "$effective_count" ]]; then
      echo "✗ $LABEL: $file says $n vai trò thực tế, code has $effective_count"
      violations=$((violations + 1))
    fi
  done < <(grep 'vai trò thực tế' "$file" 2>/dev/null || true)
}

# check_enum <file> — scan for "N vai trò:" (enum context), compare N with enum_count
check_enum() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # First occurrence of "N vai trò:" where N is a digit
  local match
  match="$(grep -m1 -E '[0-9]+ vai trò:' "$file" 2>/dev/null || true)"
  [[ -z "$match" ]] && return 0
  local n
  n="$(printf '%s' "$match" | grep -oE '[0-9]+ vai trò:' | head -1 | grep -oE '[0-9]+')"
  [[ -z "$n" ]] && return 0
  if [[ "$n" -ne "$enum_count" ]]; then
    echo "✗ $LABEL: $file says $n vai trò: (enum), code has $enum_count"
    violations=$((violations + 1))
  fi
}

check_effective "$HANH_VI"
check_effective "$CHIEU_TEST"
check_effective "$AGENTS"
check_enum "$THIET_KE"

if (( violations > 0 )); then
  echo "✗ $LABEL: $violations role count mismatch(es)."
  exit 1
fi
echo "✓ $LABEL: role counts consistent (enum=$enum_count, effective=$effective_count)."
