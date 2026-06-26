#!/usr/bin/env bash
# Guardrail cleanup callbacks (ADR-062): every model with before_discard or
# after_discard callbacks must appear in the "Cleanup khi discard" table of
# V2_THIET_KE_HE_THONG.md. FAIL-LOUD: undocumented callback → exit 1.
set -uo pipefail

MODELS_DIR="${1:-app/models}"
DOC="${2:-docs/V2_THIET_KE_HE_THONG.md}"

LABEL="check-cleanup-callbacks"

# Models whose discard callbacks are documented in the "Xóa dữ liệu" section
# (nullify children's block_id/group_id), not in the "Cleanup khi discard"
# table (hard delete data kỳ đang mở). Checked manually — do not remove
# without verifying the doc covers them elsewhere.
SKIP_MODELS="Block|Group"

# snake_case filename → PascalCase model name: contact_point.rb → ContactPoint
to_pascal() {
  local s="${1%.rb}"
  printf '%s' "$s" | awk -F_ '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1' OFS=''
}

if [[ ! -d "$MODELS_DIR" ]]; then
  echo "✗ $LABEL: $MODELS_DIR not found"
  exit 1
fi
if [[ ! -f "$DOC" ]]; then
  echo "✗ $LABEL: $DOC not found"
  exit 1
fi

# Find model files containing before_discard or after_discard.
models_with_callbacks="$(grep -rlE '(before|after)_discard' "$MODELS_DIR"/*.rb 2>/dev/null \
  | xargs -I{} basename {} \
  | sort -u)"

if [[ -z "$models_with_callbacks" ]]; then
  echo "✓ $LABEL: no discard callbacks found."
  exit 0
fi

violations=0
documented=0

while IFS= read -r filename; do
  model="$(to_pascal "$filename")"

  # Skip models documented in a different section.
  if printf '%s' "$model" | grep -qE "^($SKIP_MODELS)$"; then
    continue
  fi

  # Check for "| ModelName |" in the cleanup table.
  if ! grep -qE "^\| *${model} *\|" "$DOC"; then
    echo "✗ $LABEL: model $model (${filename}) has discard callback but no row in cleanup table"
    violations=$((violations + 1))
  else
    documented=$((documented + 1))
  fi
done <<< "$models_with_callbacks"

if (( violations > 0 )); then
  echo "✗ $LABEL: $violations undocumented discard callback(s)."
  exit 1
fi

echo "✓ $LABEL: all discard callbacks documented ($documented model(s) in table, skip list applied)."
