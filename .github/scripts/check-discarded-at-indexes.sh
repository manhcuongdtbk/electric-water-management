#!/usr/bin/env bash
# Guardrail discarded_at indexes (ADR-062): every table with a discarded_at
# column in db/schema.rb must have a (discarded_at) | Regular index entry
# in the Database indexes section of V2_THIET_KE_HE_THONG.md.
# FAIL-LOUD: missing index entry → exit 1.
set -uo pipefail

SCHEMA="${1:-db/schema.rb}"
DOC="${2:-docs/V2_THIET_KE_HE_THONG.md}"

LABEL="check-discarded-at-indexes"

if [[ ! -f "$SCHEMA" ]]; then
  echo "✗ $LABEL: $SCHEMA not found"
  exit 1
fi
if [[ ! -f "$DOC" ]]; then
  echo "✗ $LABEL: $DOC not found"
  exit 1
fi

# Parse schema.rb: track current table, collect tables that have discarded_at.
tables_with_discarded=()
current_table=""

while IFS= read -r line; do
  if [[ "$line" =~ create_table\ \"([a-z_]+)\" ]]; then
    current_table="${BASH_REMATCH[1]}"
  elif [[ -n "$current_table" && "$line" =~ t\.datetime\ \"discarded_at\" ]]; then
    tables_with_discarded+=("$current_table")
  elif [[ -n "$current_table" && "$line" =~ ^[[:space:]]*end[[:space:]]*$ ]]; then
    current_table=""
  fi
done < "$SCHEMA"

if [[ ${#tables_with_discarded[@]} -eq 0 ]]; then
  echo "✗ $LABEL: no tables with discarded_at found in $SCHEMA"
  exit 1
fi

violations=0

for table in "${tables_with_discarded[@]}"; do
  # Match: | tablename | (discarded_at) | Regular |
  if ! grep -qE "^\|[[:space:]]*${table}[[:space:]]*\|[[:space:]]*\(discarded_at\)[[:space:]]*\|[[:space:]]*Regular[[:space:]]*\|" "$DOC"; then
    echo "✗ $LABEL: table \"$table\" has discarded_at but no (discarded_at) Regular index in $DOC"
    violations=$((violations + 1))
  fi
done

if (( violations > 0 )); then
  echo "✗ $LABEL: $violations table(s) missing discarded_at index documentation."
  exit 1
fi

echo "✓ $LABEL: all discarded_at indexes documented."
