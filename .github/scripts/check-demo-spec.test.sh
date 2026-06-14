#!/usr/bin/env bash
# Test cho check-demo-spec.sh (ADR-040 block + ADR-052 Lớp C advisory). Dựng một
# git repo tạm với hai commit (base → head) rồi chạy script với LABELS_JSON +
# BASE_SHA/HEAD_SHA trỏ vào repo đó. Chạy tay:
#   bash .github/scripts/check-demo-spec.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-demo-spec.sh"
fails=0

# make_repo <head-file-path> → in ra "<repo>\t<base_sha>\t<head_sha>"
# Tạo repo có một file nền (app/models/seed.rb), commit base, rồi thêm
# <head-file-path> và commit head. Truyền path rỗng để head == base (no-op diff).
make_repo() {
  local headpath="$1" repo base head
  repo="$(mktemp -d)"
  (
    cd "$repo"
    git init -q
    git config user.email t@t.t; git config user.name t
    mkdir -p app/models; printf 'x\n' > app/models/seed.rb
    git add -A; git commit -qm base
  )
  base="$(cd "$repo" && git rev-parse HEAD)"
  if [[ -n "$headpath" ]]; then
    (
      cd "$repo"
      mkdir -p "$(dirname "$headpath")"; printf 'y\n' > "$headpath"
      git add -A; git commit -qm head
    )
  fi
  head="$(cd "$repo" && git rev-parse HEAD)"
  printf '%s\t%s\t%s' "$repo" "$base" "$head"
}

assert() {
  # assert <label> <labels-json> <head-file-path> <expected-exit> <needle>
  local label="$1" labels="$2" headpath="$3" expected="$4" needle="$5"
  local info repo base head out rc
  info="$(make_repo "$headpath")"
  repo="${info%%$'\t'*}"; info="${info#*$'\t'}"; base="${info%%$'\t'*}"; head="${info#*$'\t'}"
  out="$(cd "$repo" && LABELS_JSON="$labels" BASE_SHA="$base" HEAD_SHA="$head" bash "$SCRIPT" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$repo"
}

LBL='[{"name":"customer-facing"}]'
NONE='[]'

# 1. Labelled + demo spec changed → OK.
assert "labelled + demo change → pass" "$LBL" "spec/demo/x_demo_spec.rb" 0 "touches spec/demo"

# 2. Labelled + no demo change → BLOCK.
assert "labelled + no demo → block" "$LBL" "app/views/x.html.erb" 1 "but adds/modifies no spec/demo"

# 3. Unlabelled + touches app/views, no demo → ADVISORY (exit 0).
assert "unlabelled + views → advisory" "$NONE" "app/views/x.html.erb" 0 "advisory, ADR-052"

# 4. Unlabelled + touches Stimulus controller → ADVISORY.
assert "unlabelled + stimulus → advisory" "$NONE" "app/javascript/controllers/x_controller.js" 0 "advisory, ADR-052"

# 5. Unlabelled + internal-only path (app/models) → not required, no advisory.
assert "unlabelled + internal → exempt" "$NONE" "app/models/other.rb" 0 "demo spec not required"

# 6. Unlabelled + views BUT also a demo spec present → no advisory (already has demo).
assert "unlabelled + views + demo → exempt" "$NONE" "spec/demo/x_demo_spec.rb" 0 "demo spec not required"

if (( fails > 0 )); then
  echo "✗ check-demo-spec.test: $fails failing case(s)."
  exit 1
fi
echo "✓ check-demo-spec.test: all cases passed."
