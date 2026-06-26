#!/usr/bin/env bash
# Test for check-schema-coverage.sh (ADR-062). Builds fixture schema and doc
# files in a temp dir, then checks exit code + output needle. Run manually:
#   bash .github/scripts/check-schema-coverage.test.sh
# NOT wired into CI (keeps CI surface small); human-run test for guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-schema-coverage.sh"
fails=0

# mk <schema-body> <doc-body> → prints temp dir path with 2 fixture files
mk() {
  local tmp; tmp="$(mktemp -d)"
  printf '%s\n' "$1" > "$tmp/schema.rb"
  printf '%s\n' "$2" > "$tmp/doc.md"
  printf '%s' "$tmp"
}

# assert <label> <expected-exit> <tmp-dir> [needle]
assert() {
  local label="$1" expected="$2" tmp="$3" needle="${4:-}"
  local out rc
  out="$(bash "$SCRIPT" "$tmp/schema.rb" "$tmp/doc.md" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

SCHEMA_ALL='  create_table "zones", force: :cascade do |t|
  create_table "units", force: :cascade do |t|
  create_table "meters", force: :cascade do |t|'

DOC_ALL='#### zones (khu vực)
#### units (đơn vị)
#### meters (công tơ)'

# 1. PASS: all tables documented
tmp="$(mk "$SCHEMA_ALL" "$DOC_ALL")"
assert "pass: all tables documented" 0 "$tmp" "all 3 schema tables documented"

# 2. FAIL: table in schema but no heading in doc
SCHEMA_EXTRA='  create_table "zones", force: :cascade do |t|
  create_table "units", force: :cascade do |t|
  create_table "meters", force: :cascade do |t|
  create_table "blocks", force: :cascade do |t|'

tmp="$(mk "$SCHEMA_EXTRA" "$DOC_ALL")"
assert "fail: undocumented table" 1 "$tmp" 'table "blocks" has no ####'

# 3. PASS: skipped tables (schema_migrations, ar_internal_metadata, versions)
SCHEMA_WITH_INTERNALS='  create_table "zones", force: :cascade do |t|
  create_table "schema_migrations", force: :cascade do |t|
  create_table "ar_internal_metadata", force: :cascade do |t|
  create_table "versions", force: :cascade do |t|'

DOC_ZONES='#### zones (khu vực)'

tmp="$(mk "$SCHEMA_WITH_INTERNALS" "$DOC_ZONES")"
assert "pass: internal tables skipped" 0 "$tmp" "all 1 schema tables documented"

# 4. PASS: extra headings in doc that aren't in schema are fine
DOC_EXTRA='#### zones (khu vực)
#### units (đơn vị)
#### meters (công tơ)
#### some_future_table (not in schema yet)'

tmp="$(mk "$SCHEMA_ALL" "$DOC_EXTRA")"
assert "pass: extra doc headings ok" 0 "$tmp" "all 3 schema tables documented"

# 5. FAIL: heading exists but wrong format (### instead of ####)
SCHEMA_ONE='  create_table "zones", force: :cascade do |t|'
DOC_WRONG='### zones (wrong heading level)'

tmp="$(mk "$SCHEMA_ONE" "$DOC_WRONG")"
assert "fail: wrong heading level" 1 "$tmp" 'table "zones" has no ####'

# 6. PASS: heading with table name at end of line (no parenthetical)
DOC_BARE='#### zones'

tmp="$(mk "$SCHEMA_ONE" "$DOC_BARE")"
assert "pass: bare heading without description" 0 "$tmp" "all 1 schema tables documented"

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
