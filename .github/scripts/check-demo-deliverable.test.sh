#!/usr/bin/env bash
# Test cho check-demo-deliverable.sh (ADR-052, Lớp B). Tạo fixture tạm rồi kiểm
# exit code + thông báo cho từng luật. Chạy tay:
#   bash .github/scripts/check-demo-deliverable.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-demo-deliverable.sh"
fails=0

# make_case <frontmatter-body> <section-body> <create-demo-file?> → in ra "$tmp"
#   frontmatter-body: các dòng giữa hai `---` (vd "customer_facing: true")
#   section-body: nội dung mục `## Truy vết demo` (rỗng = bỏ hẳn mục)
#   create-demo-file: "yes" → tạo spec/demo/fixture_demo_spec.rb dưới DEMO_ROOT
make_case() {
  local tmp specdir frontmatter="$1" section="$2" makefile="$3"
  tmp="$(mktemp -d)"
  specdir="$tmp/specs"
  mkdir -p "$specdir"
  {
    printf -- '---\ntitle: Fixture\nversion: 0.1.0\n%s\n---\n\n# Fixture spec\n\n' "$frontmatter"
    if [[ -n "$section" ]]; then
      printf '## Truy vết demo\n\n%s\n\n' "$section"
    fi
    printf '## Giới hạn\n\nkết section.\n'
  } > "$specdir/fixture-design.md"
  if [[ "$makefile" == "yes" ]]; then
    mkdir -p "$tmp/spec/demo"
    printf 'require "rails_helper"\n' > "$tmp/spec/demo/fixture_demo_spec.rb"
  fi
  printf '%s' "$tmp"
}

assert() {
  # assert <label> <expected-exit> <frontmatter> <section> <makefile> [needle]
  local label="$1" expected="$2" fm="$3" section="$4" makefile="$5" needle="${6:-}"
  local tmp out rc
  tmp="$(make_case "$fm" "$section" "$makefile")"
  out="$(bash "$SCRIPT" "$tmp/specs" "$tmp" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

# 1. PASS: customer-facing + section trỏ demo file tồn tại.
assert "pass: declares existing demo" 0 \
  "customer_facing: true" \
  "Demo: \`spec/demo/fixture_demo_spec.rb\`." "yes"

# 2. PASS: customer-facing + DEFERRED có issue.
assert "pass: deferred with issue" 0 \
  "customer_facing: true" \
  "DEFERRED #357 — demo hoãn sau khi engine sẵn sàng." "no"

# 3. PASS: opt-in — không có flag thì miễn, kể cả thiếu mục.
assert "pass: not customer-facing (no flag)" 0 \
  "date: 2026-06-14" \
  "" "no"

# 4. PASS: customer_facing: false → miễn.
assert "pass: customer_facing false" 0 \
  "customer_facing: false" \
  "" "no"

# 5. FAIL: customer-facing nhưng thiếu hẳn mục `## Truy vết demo`.
assert "fail: missing section" 1 \
  "customer_facing: true" \
  "" "no" \
  "Thiếu mục"

# 6. FAIL: customer-facing + trỏ demo file KHÔNG tồn tại.
assert "fail: demo file missing" 1 \
  "customer_facing: true" \
  "Demo: \`spec/demo/khong_ton_tai_demo_spec.rb\`." "no" \
  "không tồn tại"

# 7. FAIL: customer-facing + DEFERRED thiếu issue.
assert "fail: deferred without issue" 1 \
  "customer_facing: true" \
  "DEFERRED — chưa có demo." "no" \
  "DEFERRED thiếu Issue"

# 8. FAIL: customer-facing + mục có nhưng rỗng (không ref, không DEFERRED).
assert "fail: empty section" 1 \
  "customer_facing: true" \
  "Sẽ bổ sung sau khi xong UI." "no" \
  "rỗng/không khai"

if (( fails > 0 )); then
  echo "✗ check-demo-deliverable.test: $fails failing case(s)."
  exit 1
fi
echo "✓ check-demo-deliverable.test: all cases passed."
