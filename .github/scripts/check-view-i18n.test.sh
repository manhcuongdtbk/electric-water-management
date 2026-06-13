#!/usr/bin/env bash
# Test cho check-view-i18n.sh (ADR-032). Dựng fixture tạm rồi kiểm exit code +
# thông báo cho từng luật. Chạy tay: bash .github/scripts/check-view-i18n.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
# Cần perl (line scan Unicode) — có sẵn trên macOS và ubuntu-latest.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-view-i18n.sh"
fails=0

# mk <erb-line> <baseline-body> → in ra thư mục fixture (views/ + baseline.txt).
# Dùng printf '%s' để literal '%' của tag ERB không bị diễn giải.
mk() {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/views"
  printf '%s\n' "$1" > "$tmp/views/page.html.erb"
  printf '%s\n' "$2" > "$tmp/baseline.txt"
  printf '%s' "$tmp"
}

# run <fixture-dir> — chạy script với đường dẫn TƯƠNG ĐỐI (cd vào fixture)
# để find phát ra "views/page.html.erb" ổn định, không kèm tiền tố tmp tuyệt đối.
run() { (cd "$1" && bash "$SCRIPT" views baseline.txt 2>&1); }

# assert <label> <expected-exit> <erb-line> <baseline-body> [needle]
assert() {
  local label="$1" expected="$2" erb="$3" base="$4" needle="${5:-}"
  local tmp out rc
  tmp="$(mk "$erb" "$base")"
  out="$(run "$tmp")"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

# 1. FAIL: new diacritic line not in baseline.
assert "fail: new hard-coded literal" 1 \
  '<%= f.submit "Lưu" %>' \
  '' \
  "new hard-coded"

# 2. PASS: line's normalized text is already in the baseline.
assert "pass: grandfathered in baseline" 0 \
  '<%= f.submit "Lưu" %>' \
  'views/page.html.erb	<%= f.submit "Lưu" %>'

# 3. PASS: diacritic only inside an ERB comment.
assert "pass: diacritic only in ERB comment" 0 \
  '<%# ghi chú tiếng Việt %>' \
  ''

# 4. PASS: diacritic only inside an HTML comment.
assert "pass: diacritic only in HTML comment" 0 \
  '<!-- ghi chú tiếng Việt -->' \
  ''

# 5. FAIL: mixed line — code carries the diacritic, comment is stripped.
assert "fail: code diacritic on a mixed line" 1 \
  '<%= f.submit "Lưu" %> <%# nút lưu %>' \
  '' \
  "new hard-coded"

# 6. PASS: content-based — same text, shifted by a blank line, still matches baseline.
shift_case() {
  local tmp out rc
  tmp="$(mktemp -d)"; mkdir -p "$tmp/views"
  printf '\n\n<%%= f.submit "Lưu" %%>\n' > "$tmp/views/page.html.erb"
  printf '%s\n' 'views/page.html.erb	<%= f.submit "Lưu" %>' > "$tmp/baseline.txt"
  out="$(cd "$tmp" && bash "$SCRIPT" views baseline.txt 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "✗ pass: content-based (line shifted) — expected exit 0, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ pass: content-based (line shifted)"
  fi
  rm -rf "$tmp"
}
shift_case

# 7. PASS: UPDATE_BASELINE=1 captures current violations, then a normal run is green.
regen_case() {
  local tmp out rc
  tmp="$(mktemp -d)"; mkdir -p "$tmp/views"
  printf '%s\n' '<%= f.submit "Lưu" %>' > "$tmp/views/page.html.erb"
  (cd "$tmp" && UPDATE_BASELINE=1 bash "$SCRIPT" views baseline.txt >/dev/null 2>&1)
  out="$(cd "$tmp" && bash "$SCRIPT" views baseline.txt 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "✗ pass: regenerate then green — expected exit 0, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif ! grep -qF 'views/page.html.erb' "$tmp/baseline.txt"; then
    echo "✗ pass: regenerate then green — baseline missing the entry"; fails=$((fails + 1))
  else
    echo "✓ pass: regenerate then green"
  fi
  rm -rf "$tmp"
}
regen_case

# 8. PASS: plain ASCII English literal is not flagged (no diacritic).
assert "pass: ascii english not flagged" 0 \
  '<%= f.submit "Save" %>' \
  ''

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
