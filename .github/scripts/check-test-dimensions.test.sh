#!/usr/bin/env bash
# Test cho check-test-dimensions.sh (ADR-030). Tạo fixture tạm rồi kiểm exit code
# + thông báo cho từng luật. Chạy tay: bash .github/scripts/check-test-dimensions.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-test-dimensions.sh"
fails=0

# make_case <specs-table-body> <test-file-body> → in ra "$tmp" (thư mục gốc fixture)
make_case() {
  local tmp specdir testdir
  tmp="$(mktemp -d)"
  specdir="$tmp/specs"; testdir="$tmp/spec"
  mkdir -p "$specdir" "$testdir"
  {
    printf '# Fixture spec\n\n## Truy vết chiều test\n\n'
    printf '| Mã | Chiều test | Trạng thái |\n|---|---|---|\n'
    printf '%s\n' "$1"
    printf '\n## Giới hạn\n\nkết section.\n'
  } > "$specdir/fixture-design.md"
  printf '%s\n' "$2" > "$testdir/fixture_spec.rb"
  printf '%s' "$tmp"
}

assert() {
  # assert <label> <expected-exit> <specs-table-body> <test-file-body> [grep-needle]
  local label="$1" expected="$2" body="$3" testbody="$4" needle="${5:-}"
  local tmp out rc
  tmp="$(make_case "$body" "$testbody")"
  out="$(bash "$SCRIPT" "$tmp/specs" "$tmp/spec" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

# 1. PASS: required row has a matching test; deferred row has an issue.
assert "pass: covered + deferred" 0 \
  '| `CHIEU-alpha` | mô tả | có test |
| `CHIEU-beta` | mô tả | DEFERRED #319 |' \
  'it "CHIEU-alpha: hành vi" do; end'

# 2. FAIL: required row with no test.
assert "fail: missing test" 1 \
  '| `CHIEU-alpha` | mô tả | có test |' \
  'it "khong co anchor" do; end' \
  "Thiếu test"

# 3. FAIL: deferred row without an issue number.
assert "fail: deferred without issue" 1 \
  '| `CHIEU-beta` | mô tả | DEFERRED |' \
  'it "noop" do; end' \
  "Deferred thiếu Issue"

# 4. FAIL: orphan anchor used in a test but not declared.
assert "fail: orphan" 1 \
  '| `CHIEU-alpha` | mô tả | có test |' \
  'it "CHIEU-alpha: ok" do; end
it "CHIEU-ghost: orphan" do; end' \
  "Orphan"

# 5. FAIL: collision — cùng anchor khai ở hai spec khác nhau (make_case chỉ tạo 1
# spec nên case này dựng fixture 2-spec riêng).
collision_case() {
  local tmp out rc
  tmp="$(mktemp -d)"; mkdir -p "$tmp/specs" "$tmp/spec"
  printf '## Truy vết chiều test\n| Mã | M | T |\n|---|---|---|\n| `CHIEU-dup` | x | có test |\n## Giới hạn\n' > "$tmp/specs/a-design.md"
  printf '## Truy vết chiều test\n| Mã | M | T |\n|---|---|---|\n| `CHIEU-dup` | y | có test |\n## Giới hạn\n' > "$tmp/specs/b-design.md"
  printf 'it "CHIEU-dup: ok" do; end\n' > "$tmp/spec/x_spec.rb"
  out="$(bash "$SCRIPT" "$tmp/specs" "$tmp/spec" 2>&1)"; rc=$?
  if [[ "$rc" -ne 1 ]]; then
    echo "✗ fail: collision — expected exit 1, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif ! printf '%s' "$out" | grep -qF "Đụng tên"; then
    echo "✗ fail: collision — output missing \"Đụng tên\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ fail: collision"
  fi
  rm -rf "$tmp"
}
collision_case

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
