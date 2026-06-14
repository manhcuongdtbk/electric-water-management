#!/usr/bin/env bash
# Guardrail demo-deliverable (ADR-052, Lớp B): mỗi spec trong
# docs/superpowers/specs/ tự khai mình hướng-khách bằng frontmatter
# `customer_facing: true`. Spec như vậy PHẢI có mục `## Truy vết demo` trỏ tới
# một demo spec dưới `spec/demo/*_demo_spec.rb` (file phải tồn tại — bắt drift
# đổi tên), hoặc `DEFERRED #<số>` (hoãn có gate, không bỏ im — cùng luật DEFERRED
# của check-test-dimensions). Đây là điểm ép sớm-nhất-chạy-bằng-máy: ngay khi
# spec hướng-khách vào PR, máy đòi nó trỏ demo, thay vì đợi tới PR-time của code.
#
# Opt-in: spec KHÔNG có `customer_facing: true` thì không bị ràng buộc.
# Portable bash (macOS 3.2: while-read, không mapfile/assoc-array). FAIL-LOUD:
# vi phạm/lỗi → exit 1.
set -uo pipefail

SPECS_DIR="${1:-docs/superpowers/specs}"
DEMO_ROOT="${2:-.}"                       # gốc để phân giải đường dẫn spec/demo/...
SECTION_HEADER='## Truy vết demo'

[[ -d "$SPECS_DIR" ]] || { echo "✗ check-demo-deliverable: specs dir not found: $SPECS_DIR"; exit 1; }

violations=0

section_file="$(mktemp)"
trap 'rm -f "$section_file"' EXIT

# Một spec là hướng-khách khi frontmatter (khối giữa hai dòng `---` đầu file) có
# dòng `customer_facing: true`. Chỉ quét trong frontmatter để không khớp nhầm
# phần thân spec (nơi có thể trích dẫn flag như ví dụ).
is_customer_facing() {
  local spec="$1" infm=0 seen=0
  while IFS= read -r raw; do
    case "$raw" in
      '---')
        seen=$((seen + 1))
        if [[ "$seen" -eq 1 ]]; then infm=1; continue; fi
        if [[ "$seen" -eq 2 ]]; then return 1; fi   # hết frontmatter, không thấy
        ;;
    esac
    (( infm )) || continue
    case "$raw" in
      customer_facing:*)
        # chuẩn hoá: bỏ khoảng trắng quanh giá trị
        local val="${raw#customer_facing:}"
        val="$(printf '%s' "$val" | tr -d '[:space:]')"
        [[ "$val" == "true" ]] && return 0 || return 1
        ;;
    esac
  done < "$spec"
  return 1
}

while IFS= read -r spec; do
  is_customer_facing "$spec" || continue

  # Trích nội dung mục `## Truy vết demo` (tới heading `## ` kế tiếp), bỏ code
  # fence. Viết ra file tạm (KHÔNG dùng $(...) vì literal ``` bị parse nhầm thành
  # command substitution lồng nhau).
  : > "$section_file"
  insection=0; incode=0
  while IFS= read -r raw; do
    case "$raw" in
      '```'* | '~~~'*) incode=$((1 - incode)); continue ;;
    esac
    (( incode )) && continue
    case "$raw" in
      "$SECTION_HEADER"*) insection=1; continue ;;
      '## '*) insection=0; continue ;;
    esac
    (( insection )) && printf '%s\n' "$raw" >> "$section_file"
  done < "$spec"
  section="$(cat "$section_file")"

  if ! grep -q "^${SECTION_HEADER}" "$spec"; then
    echo "✗ Thiếu mục  '$SECTION_HEADER'  trong $spec  (spec customer_facing: true phải khai demo)"
    violations=$((violations + 1))
    continue
  fi

  # Các tham chiếu demo file: token dạng spec/demo/<...>_demo_spec.rb
  demo_refs="$(printf '%s' "$section" | grep -oE 'spec/demo/[A-Za-z0-9_./-]+_demo_spec\.rb' | sort -u || true)"
  has_deferred=0
  if printf '%s' "$section" | grep -qE 'DEFERRED'; then
    has_deferred=1
    if ! printf '%s' "$section" | grep -qE 'DEFERRED[^#]*#[0-9]+'; then
      echo "✗ DEFERRED thiếu Issue  $spec  → mục '$SECTION_HEADER' cần dạng 'DEFERRED #<số>'"
      violations=$((violations + 1))
    fi
  fi

  if [[ -z "$demo_refs" && "$has_deferred" -eq 0 ]]; then
    echo "✗ Mục '$SECTION_HEADER' rỗng/không khai  $spec  — cần trỏ một spec/demo/*_demo_spec.rb hoặc 'DEFERRED #<số>'"
    violations=$((violations + 1))
    continue
  fi

  # Mỗi demo file được trỏ phải tồn tại (bắt drift đường dẫn/đổi tên).
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$DEMO_ROOT/$ref" ]]; then
      echo "✗ Demo file không tồn tại  $ref  (trỏ trong $spec, mục '$SECTION_HEADER')"
      violations=$((violations + 1))
    fi
  done <<< "$demo_refs"
done < <(find "$SPECS_DIR" -type f -name '*.md' | sort)

if (( violations > 0 )); then
  echo "✗ check-demo-deliverable: $violations demo-deliverable issue(s)."
  exit 1
fi
echo "✓ check-demo-deliverable: every customer-facing spec declares a demo deliverable (or DEFERRED)."
