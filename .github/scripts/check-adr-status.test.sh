#!/usr/bin/env bash
# Test cho check-adr-status.sh (ADR-033). Dựng fixture spec tạm rồi kiểm exit code
# + thông báo cho R1/R2. Chạy tay: bash .github/scripts/check-adr-status.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-adr-status.sh"
fails=0

# mk <spec-body> → in ra thư mục specs fixture chứa 1 file design.md
mk() {
  local tmp; tmp="$(mktemp -d)"
  printf '%s\n' "$1" > "$tmp/fixture-design.md"
  printf '%s' "$tmp"
}

# assert <label> <expected-exit> <spec-body> [needle]
assert() {
  local label="$1" expected="$2" body="$3" needle="${4:-}"
  local tmp out rc
  tmp="$(mk "$body")"
  out="$(bash "$SCRIPT" "$tmp" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

CLEAN_FM=$'---\ntitle: x\nversion: 0.1.0\ndate: 2026-06-13\n---'

# 1. PASS: clean spec — no frontmatter status, ADR Accepted.
assert "pass: accepted, no fm status" 0 \
  "$CLEAN_FM"$'\n# X\n- **Trạng thái:** Accepted · 2026-06-13'

# 2. FAIL R1: frontmatter has a status: key.
assert "fail: R1 frontmatter status" 1 \
  $'---\ntitle: x\nversion: 0.1.0\nstatus: draft (chờ duyệt)\n---'$'\n- **Trạng thái:** Accepted · 2026-06-13' \
  "R1 frontmatter"

# 3. FAIL R2: inline Proposed without a #issue marker.
assert "fail: R2 undeferred proposed" 1 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Proposed · 2026-06-13' \
  "R2 undeferred"

# 4. PASS: Proposed WITH a genuine deferred-marker ("chờ quyết" + #issue).
assert "pass: deferred proposed" 0 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Proposed (chờ quyết #42)'

# 4b. FAIL R2: Proposed with a mere provenance "(Issue #N)" — NOT a deferral.
#     A merged ADR that cites its origin issue must still be Accepted.
assert "fail: R2 provenance not deferral" 1 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Proposed · 2026-06-11 (Issue #320)' \
  "R2 undeferred"

# 5. PASS: '**Trạng thái khách:**' is a different field, never flagged.
assert "pass: trang thai khach ignored" 0 \
  "$CLEAN_FM"$'\n- **Trạng thái khách:** Proposed — nghiệm thu sau'

# 6. PASS: a prose mention of Proposed wrapped in backticks (inline-code stripped).
assert "pass: backticked prose proposed" 0 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Accepted · 2026-06-13\nVí dụ: `**Trạng thái:** Proposed` chỉ là minh hoạ.'

# 7. PASS: Proposed inside a fenced code block is ignored.
assert "pass: fenced proposed" 0 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Accepted · 2026-06-13\n```\n- **Trạng thái:** Proposed\n```'

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
