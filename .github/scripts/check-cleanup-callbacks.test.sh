#!/usr/bin/env bash
# Test for check-cleanup-callbacks.sh (ADR-062). Builds fixture model files
# and doc in a temp dir, then checks exit code + output needle. Run manually:
#   bash .github/scripts/check-cleanup-callbacks.test.sh
# NOT wired into CI (keeps CI surface small); human-run test for guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-cleanup-callbacks.sh"
fails=0

# mk <doc-body> <model-files...> → prints temp dir path
# model-files format: "filename.rb:content"
mk() {
  local tmp; tmp="$(mktemp -d)"
  local doc_body="$1"; shift
  mkdir -p "$tmp/models"
  printf '%s\n' "$doc_body" > "$tmp/doc.md"
  for entry in "$@"; do
    local fname="${entry%%:*}"
    local content="${entry#*:}"
    printf '%s\n' "$content" > "$tmp/models/$fname"
  done
  printf '%s' "$tmp"
}

# assert <label> <expected-exit> <tmp-dir> [needle]
assert() {
  local label="$1" expected="$2" tmp="$3" needle="${4:-}"
  local out rc
  out="$(bash "$SCRIPT" "$tmp/models" "$tmp/doc.md" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

DOC_TABLE='| Thực thể | Cleanup khi discard |
|---|---|
| ContactPoint | Hard delete meter_readings |
| Meter | Hard delete meter_readings |
| Zone | Hard delete main_meter_readings |'

# 1. PASS: all models with callbacks are in doc
tmp="$(mk "$DOC_TABLE" \
  "contact_point.rb:before_discard :cleanup" \
  "meter.rb:before_discard :cleanup" \
  "zone.rb:before_discard :cleanup")"
assert "pass: all callbacks documented" 0 "$tmp" "all discard callbacks documented"

# 2. FAIL: model with callback not in doc and not in skip list
tmp="$(mk "$DOC_TABLE" \
  "contact_point.rb:before_discard :cleanup" \
  "meter.rb:before_discard :cleanup" \
  "zone.rb:before_discard :cleanup" \
  "main_meter.rb:before_discard :cleanup")"
assert "fail: undocumented callback" 1 "$tmp" "model MainMeter (main_meter.rb) has discard callback but no row"

# 3. PASS: model in skip list (Block) does not require doc entry
tmp="$(mk "$DOC_TABLE" \
  "contact_point.rb:before_discard :cleanup" \
  "meter.rb:before_discard :cleanup" \
  "zone.rb:before_discard :cleanup" \
  "block.rb:after_discard { nullify }")"
assert "pass: skip list model Block" 0 "$tmp" "all discard callbacks documented"

# 4. PASS: model in skip list (Group) does not require doc entry
tmp="$(mk "$DOC_TABLE" \
  "meter.rb:before_discard :cleanup" \
  "group.rb:after_discard { nullify }")"
assert "pass: skip list model Group" 0 "$tmp" "all discard callbacks documented"

# 5. PASS: model without discard callback is irrelevant
tmp="$(mk "$DOC_TABLE" \
  "contact_point.rb:before_discard :cleanup" \
  "user.rb:validates :username, presence: true")"
assert "pass: model without callback ignored" 0 "$tmp" "all discard callbacks documented"

# 6. PASS: no models have callbacks at all
DOC_EMPTY='just some doc content'
tmp="$(mk "$DOC_EMPTY" \
  "user.rb:validates :username")"
assert "pass: no callbacks found" 0 "$tmp" "no discard callbacks found"

# 7. FAIL: multiple undocumented models
DOC_PARTIAL='| Thực thể | Cleanup |
|---|---|
| Zone | Hard delete |'
tmp="$(mk "$DOC_PARTIAL" \
  "zone.rb:before_discard :cleanup" \
  "meter.rb:before_discard :cleanup" \
  "contact_point.rb:after_discard :cascade")"
assert "fail: multiple undocumented" 1 "$tmp" "2 undocumented discard callback(s)"

# 8. PASS: after_discard also detected
DOC_WITH_UNIT='| Thực thể | Cleanup |
|---|---|
| Unit | Hard delete unit_configs |'
tmp="$(mk "$DOC_WITH_UNIT" \
  "unit.rb:after_discard :cascade_blocks")"
assert "pass: after_discard detected and documented" 0 "$tmp" "all discard callbacks documented"

# 9. PASS: multi-word model name (snake_case → PascalCase)
DOC_MAIN='| Thực thể | Cleanup |
|---|---|
| MainMeter | Hard delete |'
tmp="$(mk "$DOC_MAIN" \
  "main_meter.rb:before_discard :cleanup")"
assert "pass: multi-word PascalCase conversion" 0 "$tmp" "all discard callbacks documented"

# 10. FAIL: models dir missing
tmp="$(mktemp -d)"
printf 'doc\n' > "$tmp/doc.md"
out="$(bash "$SCRIPT" "$tmp/no_such_dir" "$tmp/doc.md" 2>&1)"; rc=$?
if [[ "$rc" -ne 1 ]] || ! printf '%s' "$out" | grep -qF "not found"; then
  echo "✗ fail: missing models dir — expected exit 1 with 'not found'"; fails=$((fails + 1))
else
  echo "✓ fail: missing models dir"
fi
rm -rf "$tmp"

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
