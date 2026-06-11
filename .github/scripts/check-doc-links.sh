#!/usr/bin/env bash
# Guardrail quản trị tài liệu (ADR-024): mọi markdown link nội bộ trong docs/ +
# file meta gốc phải trỏ tới FILE tồn tại. Bắt drift do đổi tên/xóa file (pattern
# "trỏ về" của ADR-023 dựa vào link sống). Bỏ code fence + inline code trước khi
# quét (plan/spec nhúng link ví dụ trong khối code). CHỈ bỏ span đơn-backtick
# (`...`); span kép (``...``) KHÔNG bị bỏ — tránh viết ``[text](path.md)`` trong
# tài liệu (dùng code fence thay thế). v1 KHÔNG ép anchor #slug.
# FAIL-LOUD: vi phạm → exit 1.
set -uo pipefail

list_docs() {
  find docs -type f -name '*.md'
  for f in README.md AGENTS.md CONTRIBUTING.md CLAUDE.md; do
    [[ -f "$f" ]] && echo "$f"
  done
}

violations=0
while IFS= read -r f; do
  dir="$(dirname "$f")"
  incode=0
  lineno=0
  while IFS= read -r raw; do
    lineno=$((lineno + 1))
    case "$raw" in
      '```'* | '~~~'*) incode=$((1 - incode)); continue ;;  # toggle khối code
    esac
    (( incode )) && continue
    line="$(printf '%s' "$raw" | sed 's/`[^`]*`//g')"        # bỏ inline code
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      url="${target%%#*}"   # bỏ #anchor (không ép ở v1)
      url="${url%% *}"      # bỏ "title" sau khoảng trắng (phòng xa; grep đã dừng ở space)
      [[ -z "$url" ]] && continue
      case "$url" in
        http://* | https://* | mailto:* | tel:*) continue ;;  # link ngoài
      esac
      if [[ ! -e "$dir/$url" ]]; then
        echo "✗ Broken link  $f:$lineno  → $url"
        violations=$((violations + 1))
      fi
    done < <(printf '%s\n' "$line" | grep -oE '\]\([^) ]+' | sed -E 's/^\]\(//')
  done < "$f"
done < <(list_docs | sort -u)

if (( violations > 0 )); then
  echo "✗ check-doc-links: $violations broken internal link(s)."
  exit 1
fi
echo "✓ check-doc-links: all internal links resolve."
