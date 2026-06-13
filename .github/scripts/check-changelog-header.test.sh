#!/usr/bin/env bash
# Test cho check-changelog-header.sh (#339). Dựng fixture spec tạm rồi kiểm exit
# code + thông báo. Chạy tay: bash .github/scripts/check-changelog-header.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-changelog-header.sh"
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

# 1. PASS: canonical header.
assert "pass: canonical header" 0 \
  $'# X\n\n## Lịch sử thay đổi\n\n- **0.1.0:** đầu.'

# 2. FAIL: '## Changelog' header.
assert "fail: ## Changelog header" 1 \
  $'# X\n\n## Changelog\n\n- **0.1.0:** đầu.' \
  "non-canonical changelog header"

# 3. FAIL: a different heading level still flagged (### Changelog).
assert "fail: ### Changelog header" 1 \
  $'# X\n\n### Changelog\n\n- a' \
  "non-canonical changelog header"

# 4. PASS: '## Changelog' inside a fenced code block is ignored.
assert "pass: fenced Changelog" 0 \
  $'# X\n\n## Lịch sử thay đổi\n\n```\n## Changelog\n```'

# 5. PASS: a prose mention of `## Changelog` (backticked, not a heading).
assert "pass: prose mention" 0 \
  $'# X\n\nDùng `## Lịch sử thay đổi`, không dùng `## Changelog`.\n\n## Lịch sử thay đổi\n\n- a'

# 6. PASS: a heading that merely contains the word changelog in a phrase is not the bare header.
assert "pass: heading phrase not bare header" 0 \
  $'# X\n\n## Tự động hoá changelog cấp dự án\n\n## Lịch sử thay đổi\n\n- a'

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
