#!/usr/bin/env bash
# Guardrail chống trùng số ADR (ADR-046): mỗi số ADR-NNN chỉ được định nghĩa ở
# ĐÚNG MỘT dòng heading trên toàn cây docs/superpowers/specs/. "Định nghĩa" = dòng
# khớp heading '## ADR-NNN' HOẶC '### ADR-NNN' — BẮT CẢ HAI CẤP (chỉ '###' sẽ bỏ
# sót '## ADR-NNN', đúng lỗ hổng từng che trùng ADR-001/002). Bỏ code fence trước
# khi soi (giống check-adr-status.sh) để ví dụ trong fence không bị tính. Khi ≥2
# nhánh song song cùng +1 một số → trùng; script bắt khi cả hai định nghĩa cùng
# có mặt (nhánh sau đồng bộ develop), dựa single-merger (ADR-007) renumber nhánh
# gộp sau. Portable bash (macOS 3.2). Output/echo tiếng Anh. FAIL-LOUD → exit 1.
set -uo pipefail

SPECS_DIR="${1:-docs/superpowers/specs}"
[[ -d "$SPECS_DIR" ]] || { echo "✗ check-adr-numbering: specs dir not found: $SPECS_DIR"; exit 1; }

defs="$(mktemp)"   # mỗi dòng: ADR-NNN<TAB>specfile
trap 'rm -f "$defs"' EXIT

# Trích mọi dòng định nghĩa ADR (bỏ code fence), ghi (số, file).
while IFS= read -r spec; do
  incode=0
  while IFS= read -r raw; do
    case "$raw" in '```'*|'~~~'*) incode=$((1 - incode)); continue ;; esac
    (( incode )) && continue
    # Heading '## ' hoặc '### ' theo sau là 'ADR-' + 3 chữ số.
    case "$raw" in
      '## ADR-'[0-9][0-9][0-9]* | '### ADR-'[0-9][0-9][0-9]*) : ;;
      *) continue ;;
    esac
    num="$(printf '%s' "$raw" | grep -oE 'ADR-[0-9]{3}' | head -n1)"
    [[ -z "$num" ]] && continue
    printf '%s\t%s\n' "$num" "$spec" >> "$defs"
  done < "$spec"
done < <(find "$SPECS_DIR" -type f -name '*.md' | sort)

violations=0
# Số nào xuất hiện ở >1 dòng định nghĩa → trùng.
while IFS= read -r num; do
  [[ -z "$num" ]] && continue
  count="$(awk -F'\t' -v n="$num" '$1==n {c++} END{print c+0}' "$defs")"
  if [[ "$count" -gt 1 ]]; then
    echo "✗ Duplicate ADR number  $num  defined $count times:"
    awk -F'\t' -v n="$num" '$1==n {print "    - "$2}' "$defs" | sort
    violations=$((violations + 1))
  fi
done < <(cut -f1 "$defs" | sort -u)

if (( violations > 0 )); then
  echo "✗ check-adr-numbering: $violations duplicate ADR number(s)."
  exit 1
fi
echo "✓ check-adr-numbering: every ADR number is defined in exactly one spec heading."
