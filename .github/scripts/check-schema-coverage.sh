#!/usr/bin/env bash
# Guardrail schema coverage (ADR-062): every application table in db/schema.rb
# must have a corresponding #### heading in V2_THIET_KE_HE_THONG.md.
# FAIL-LOUD: undocumented table → exit 1.
set -uo pipefail

SCHEMA="${1:-db/schema.rb}"
DOC="${2:-docs/V2_THIET_KE_HE_THONG.md}"

LABEL="check-schema-coverage"

# Rails / PaperTrail internals — not application tables.
SKIP="schema_migrations|ar_internal_metadata|versions"

if [[ ! -f "$SCHEMA" ]]; then
  echo "✗ $LABEL: $SCHEMA not found"
  exit 1
fi
if [[ ! -f "$DOC" ]]; then
  echo "✗ $LABEL: $DOC not found"
  exit 1
fi

# Extract table names from create_table "xxx" lines, skip internals.
tables="$(grep -oE 'create_table "[a-z_]+"' "$SCHEMA" \
  | sed 's/create_table "//; s/"//' \
  | grep -vE "^($SKIP)$" \
  | sort)"

if [[ -z "$tables" ]]; then
  echo "✗ $LABEL: no application tables found in $SCHEMA"
  exit 1
fi

violations=0

while IFS= read -r table; do
  # Match #### tablename followed by space, ( or end of line.
  if ! grep -qE "^#### ${table}( |\(|$)" "$DOC"; then
    echo "✗ $LABEL: table \"$table\" has no #### heading in $DOC"
    violations=$((violations + 1))
  fi
done <<< "$tables"

if (( violations > 0 )); then
  echo "✗ $LABEL: $violations undocumented table(s)."
  exit 1
fi

total="$(printf '%s\n' "$tables" | wc -l | tr -d ' ')"
echo "✓ $LABEL: all $total schema tables documented."
