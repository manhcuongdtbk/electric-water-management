#!/usr/bin/env bash
# Test for check-discarded-at-indexes.sh (ADR-062). Builds fixture schema and
# doc files in a temp dir, then checks exit code + output needle. Run manually:
#   bash .github/scripts/check-discarded-at-indexes.test.sh
# NOT wired into CI (keeps CI surface small); human-run test for guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-discarded-at-indexes.sh"
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

# --- Fixture data ---

SCHEMA_ALL='  create_table "blocks", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
  end

  create_table "zones", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "discarded_at"
  end

  create_table "units", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "discarded_at"
  end'

DOC_ALL='| Bảng | Index | Loại | Lý do |
|---|---|---|---|
| blocks | (discarded_at) | Regular | Filter soft delete |
| zones | (discarded_at) | Regular | Filter soft delete |
| units | (discarded_at) | Regular | Filter soft delete |'

# 1. PASS: all tables with discarded_at have index entries
tmp="$(mk "$SCHEMA_ALL" "$DOC_ALL")"
assert "pass: all tables with discarded_at documented" 0 "$tmp" "all discarded_at indexes documented"

# 2. FAIL: table has discarded_at but no index entry in doc
SCHEMA_WITH_EXTRA='  create_table "blocks", force: :cascade do |t|
    t.datetime "discarded_at"
  end

  create_table "meters", force: :cascade do |t|
    t.datetime "discarded_at"
  end'

DOC_MISSING='| Bảng | Index | Loại | Lý do |
|---|---|---|---|
| blocks | (discarded_at) | Regular | Filter soft delete |'

tmp="$(mk "$SCHEMA_WITH_EXTRA" "$DOC_MISSING")"
assert "fail: missing index entry for meters" 1 "$tmp" 'table "meters" has discarded_at but no'

# 3. PASS: table without discarded_at is irrelevant
SCHEMA_NO_DISCARD='  create_table "periods", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "closed", default: false
    t.datetime "created_at", null: false
  end

  create_table "blocks", force: :cascade do |t|
    t.datetime "discarded_at"
  end'

DOC_ONE='| Bảng | Index | Loại | Lý do |
|---|---|---|---|
| blocks | (discarded_at) | Regular | Filter soft delete |'

tmp="$(mk "$SCHEMA_NO_DISCARD" "$DOC_ONE")"
assert "pass: table without discarded_at is irrelevant" 0 "$tmp" "all discarded_at indexes documented"

# 4. PASS: multiple tables all documented (verifies array collection)
SCHEMA_SEVEN='  create_table "blocks", force: :cascade do |t|
    t.datetime "discarded_at"
  end
  create_table "contact_points", force: :cascade do |t|
    t.datetime "discarded_at"
  end
  create_table "groups", force: :cascade do |t|
    t.datetime "discarded_at"
  end
  create_table "main_meters", force: :cascade do |t|
    t.datetime "discarded_at"
  end
  create_table "meters", force: :cascade do |t|
    t.datetime "discarded_at"
  end
  create_table "units", force: :cascade do |t|
    t.datetime "discarded_at"
  end
  create_table "zones", force: :cascade do |t|
    t.datetime "discarded_at"
  end'

DOC_SEVEN='| Bảng | Index | Loại | Lý do |
|---|---|---|---|
| blocks | (discarded_at) | Regular | Filter soft delete |
| contact_points | (discarded_at) | Regular | Filter soft delete |
| groups | (discarded_at) | Regular | Filter soft delete |
| main_meters | (discarded_at) | Regular | Filter soft delete |
| meters | (discarded_at) | Regular | Filter soft delete |
| units | (discarded_at) | Regular | Filter soft delete |
| zones | (discarded_at) | Regular | Filter soft delete |'

tmp="$(mk "$SCHEMA_SEVEN" "$DOC_SEVEN")"
assert "pass: all 7 tables documented" 0 "$tmp" "all discarded_at indexes documented"

# 5. FAIL: doc has wrong index type (Unique instead of Regular)
DOC_WRONG_TYPE='| Bảng | Index | Loại | Lý do |
|---|---|---|---|
| blocks | (discarded_at) | Unique | Filter soft delete |'

SCHEMA_SINGLE='  create_table "blocks", force: :cascade do |t|
    t.datetime "discarded_at"
  end'

tmp="$(mk "$SCHEMA_SINGLE" "$DOC_WRONG_TYPE")"
assert "fail: wrong index type (Unique instead of Regular)" 1 "$tmp" 'table "blocks" has discarded_at but no'

# 6. FAIL: doc missing the (discarded_at) column name
DOC_WRONG_COL='| Bảng | Index | Loại | Lý do |
|---|---|---|---|
| blocks | (name) | Regular | Some reason |'

tmp="$(mk "$SCHEMA_SINGLE" "$DOC_WRONG_COL")"
assert "fail: wrong column in index entry" 1 "$tmp" 'table "blocks" has discarded_at but no'

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
