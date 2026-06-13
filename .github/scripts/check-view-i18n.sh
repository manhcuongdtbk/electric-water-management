#!/usr/bin/env bash
# Guardrail i18n cho view (ADR-032): quét app/views/**/*.erb, chặn literal tiếng
# Việt MỚI nằm ngoài t(...). Phần hard-code đã có được grandfather qua baseline
# .github/i18n-view-baseline.txt (app single-locale → không ép migration). Tín
# hiệu: dòng (sau khi bỏ comment span) còn chứa ký tự Latin có dấu = chữ tiếng
# Việt người-dùng-thấy. Bản ghi vi phạm = "relpath<TAB>text chuẩn-hoá khoảng-trắng"
# (KHÔNG số dòng → ổn định khi dòng dịch chuyển). Vi phạm không có trong baseline
# → đỏ. UPDATE_BASELINE=1 → ghi lại baseline (escape hatch, diff thấy ở PR).
# Theo pattern ADR-024/030 (bash fail-loud). Cần perl (line scan Unicode) — có ở
# ubuntu-latest (CI) và macOS. FAIL-LOUD: vi phạm/lỗi → exit 1.
set -uo pipefail

VIEWS_DIR="${1:-app/views}"
BASELINE="${2:-.github/i18n-view-baseline.txt}"

[[ -d "$VIEWS_DIR" ]] || { echo "✗ check-view-i18n: views dir not found: $VIEWS_DIR"; exit 1; }
command -v perl >/dev/null 2>&1 || { echo "✗ check-view-i18n: perl not found (required for the Unicode line scan)"; exit 1; }

# extract_violations: in mỗi dòng vi phạm dạng "relpath<TAB>normalized-text".
# Bỏ comment span ERB (<%# … %>) và HTML (<!-- … -->) theo greedy, trên TỪNG dòng
# (perl đọc từng dòng). Với comment MỘT-dòng: sai sót duy nhất là false negative
# hiếm (comment cùng-dòng đứng trước code), không đỏ oan. Lưu ý: comment NHIỀU-dòng
# có chữ Việt ở dòng giữa (mở <!-- và đóng --> khác dòng) CÓ THỂ bị bắt — codebase
# hiện không dùng kiểu đó; nếu cần, thêm dòng đó vào baseline. Lớp ký tự: Latin
# Extended (U+00C0–U+024F) + Latin
# Extended Additional (U+1E00–U+1EFF) = các chữ tiếng Việt precomposed; ASCII Anh
# thuần không khớp. Key chuẩn-hoá từ phần ĐÃ bỏ comment (sửa comment không churn).
extract_violations() {
  find "$VIEWS_DIR" -type f -name '*.erb' | LC_ALL=C sort | while IFS= read -r f; do
    perl -CSD -ne '
      my $code = $_;
      $code =~ s/<!--.*-->//g;
      $code =~ s/<%#.*%>//g;
      next unless $code =~ /[\x{00C0}-\x{024F}\x{1E00}-\x{1EFF}]/;
      my $t = $code;
      $t =~ s/\s+/ /g; $t =~ s/^ //; $t =~ s/ $//;
      print "$ARGV\t$t\n";
    ' "$f"
  done
}

current="$(mktemp)"
base="$(mktemp)"
trap 'rm -f "$current" "$base"' EXIT
extract_violations | LC_ALL=C sort -u > "$current"

# Chế độ regenerate: ghi baseline rồi thoát xanh.
if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
  {
    echo "# i18n view guardrail baseline (ADR-032) — grandfathered hard-coded"
    echo "# Vietnamese literals outside t(...) in $VIEWS_DIR/**/*.erb."
    echo "# Regenerate: UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh"
    echo "# Format: <relpath><TAB><whitespace-normalized offending text>"
    cat "$current"
  } > "$BASELINE"
  echo "✓ check-view-i18n: baseline written to $BASELINE ($(grep -c . "$current") entr(ies))."
  exit 0
fi

[[ -f "$BASELINE" ]] || { echo "✗ check-view-i18n: baseline not found: $BASELINE (run UPDATE_BASELINE=1 to create it)"; exit 1; }

# So sánh: bỏ dòng comment/blank của baseline rồi sort giống current.
grep -v '^#' "$BASELINE" | grep -v '^[[:space:]]*$' | LC_ALL=C sort -u > "$base"

new="$(comm -23 "$current" "$base")"    # có ở current, không có ở baseline → mới
stale="$(comm -13 "$current" "$base")"  # có ở baseline, không còn ở current → cũ/đã sửa

violations=0
if [[ -n "$new" ]]; then
  echo "✗ check-view-i18n: new hard-coded Vietnamese literal(s) outside t(...) in $VIEWS_DIR/:"
  printf '%s\n' "$new" | while IFS="$(printf '\t')" read -r path text; do
    echo "  ✗ $path  →  $text"
  done
  echo "  Fix: wrap the text in t(...) and add the key to config/locales/vi.yml."
  echo "  (If it is genuinely not user-facing, regenerate the baseline: UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh)"
  violations=1
fi

if [[ -n "$stale" ]]; then
  echo "ℹ check-view-i18n: $(printf '%s\n' "$stale" | grep -c .) stale baseline entr(ies) (fixed/migrated). Prune: UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh"
fi

if (( violations > 0 )); then exit 1; fi
echo "✓ check-view-i18n: no new hard-coded Vietnamese literals in views (baseline grandfathered)."
exit 0
