#!/usr/bin/env bash
# Guardrail truy vết chiều test (ADR-030): mỗi spec trong docs/superpowers/specs/
# có thể khai một bảng "## Truy vết chiều test" với hàng `CHIEU-<slug> | mô tả |
# trạng thái`. Test mang anchor `CHIEU-<slug>` ở mô tả `it`. Script đối chiếu bảng
# ↔ grep cây spec/ với 4 luật: (1) hàng required (không DEFERRED) phải có ≥1 test;
# (2) hàng DEFERRED phải kèm #<số>; (3) anchor CHIEU- dùng trong test phải có trong
# một bảng (chống orphan/typo); (4) một anchor không được khai ở >1 spec (unique).
# Tiền tố "CHIEU" (chiều) viết đủ chữ, tránh trùng "CT" (công tơ) dùng làm tên công
# tơ trong fixture test. Opt-in: spec không có section thì không đóng góp khai báo.
# Portable bash (macOS 3.2: while-read, không mapfile/assoc-array). FAIL-LOUD:
# vi phạm/lỗi → exit 1.
set -uo pipefail

SPECS_DIR="${1:-docs/superpowers/specs}"
TESTS_DIR="${2:-spec}"
SECTION_HEADER='## Truy vết chiều test'

[[ -d "$SPECS_DIR" ]] || { echo "✗ check-test-dimensions: specs dir not found: $SPECS_DIR"; exit 1; }
[[ -d "$TESTS_DIR" ]]  || { echo "✗ check-test-dimensions: tests dir not found: $TESTS_DIR"; exit 1; }

decl="$(mktemp)"   # mỗi dòng: anchor<TAB>specfile<TAB>deferred(0|1)
trap 'rm -f "$decl"' EXIT

violations=0

# (1) Trích khai báo từ mọi spec: hàng bảng trong section, bỏ code fence.
while IFS= read -r spec; do
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
    (( insection )) || continue
    case "$raw" in '|'*) : ;; *) continue ;; esac           # chỉ hàng bảng
    case "$raw" in *CHIEU-*) : ;; *) continue ;; esac        # có token CHIEU-
    # Một anchor mỗi hàng theo convention (cột Mã); đa-anchor là chuyện ở test.
    anchor="$(printf '%s' "$raw" | grep -oE 'CHIEU-[a-z0-9-]+' | head -n1)"
    [[ -z "$anchor" ]] && continue
    # Cột trạng thái = cell cuối: bỏ một dấu | cuối (nếu có) rồi lấy phần sau dấu |
    # cuối — để '#<số>' ở cột mô tả KHÔNG vô tình thoả luật DEFERRED.
    status="${raw%|}"; status="${status##*|}"
    deferred=0
    if printf '%s' "$status" | grep -qE 'DEFERRED'; then
      deferred=1
      if ! printf '%s' "$status" | grep -qE '#[0-9]+'; then
        echo "✗ Deferred thiếu Issue  $spec  → $anchor  (cần dạng 'DEFERRED #<số>')"
        violations=$((violations + 1))
      fi
    fi
    printf '%s\t%s\t%s\n' "$anchor" "$spec" "$deferred" >> "$decl"
  done < "$spec"
done < <(find "$SPECS_DIR" -type f -name '*.md' | sort)

# (2) Đụng tên: cùng anchor khai ở >1 spec khác nhau.
while IFS= read -r anchor; do
  [[ -z "$anchor" ]] && continue
  nfiles="$(awk -F'\t' -v a="$anchor" '$1==a {print $2}' "$decl" | sort -u | wc -l | tr -d ' ')"
  if [[ "$nfiles" -gt 1 ]]; then
    echo "✗ Đụng tên anchor  $anchor  khai ở $nfiles spec khác nhau"
    violations=$((violations + 1))
  fi
done < <(cut -f1 "$decl" | sort -u)

# (3) Độ phủ: mỗi anchor required (deferred=0) phải có ≥1 test nhắc tới
#     (theo sau anchor là ký tự không-slug để tránh khớp tiền tố nhầm).
while IFS=$'\t' read -r anchor spec deferred; do
  [[ "$deferred" == "1" ]] && continue
  if ! grep -rqE -- "${anchor}([^a-z0-9-]|\$)" "$TESTS_DIR" 2>/dev/null; then
    echo "✗ Thiếu test  $anchor  (khai ở $spec, không DEFERRED) — không test nào trong $TESTS_DIR/ nhắc tới"
    violations=$((violations + 1))
  fi
done < "$decl"

# (4) Orphan: anchor CHIEU- dùng trong mô tả test phải có trong một bảng spec.
#     Anchor theo convention `CHIEU-<slug>:` (mô tả `it "CHIEU-...: ..."` — ADR-030),
#     nên chỉ nhận token có dấu hai chấm theo sau (định nghĩa rõ "một tham chiếu anchor").
while IFS= read -r token; do
  [[ -z "$token" ]] && continue
  if ! cut -f1 "$decl" | grep -qxF -- "$token"; then
    echo "✗ Orphan  $token  dùng trong $TESTS_DIR/ nhưng không có trong bảng spec nào"
    violations=$((violations + 1))
  fi
done < <(grep -rhoE 'CHIEU-[a-z0-9-]+:' "$TESTS_DIR" 2>/dev/null | sed 's/:$//' | sort -u)

if (( violations > 0 )); then
  echo "✗ check-test-dimensions: $violations test-dimension traceability issue(s)."
  exit 1
fi
echo "✓ check-test-dimensions: every declared test dimension is covered or DEFERRED."
