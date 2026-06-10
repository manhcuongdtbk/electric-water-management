#!/usr/bin/env bash
# Guardrail quản trị tài liệu (ADR-024): mỗi thuật ngữ trong
# .github/dictionaries/glossary-terms.txt (6 viết tắt + 11 jargon) phải còn một
# hàng định nghĩa trong docs/THUAT_NGU.md (đầu cell bảng là thuật ngữ đó, có/không
# in đậm). Chống xóa định nghĩa âm thầm. KHÔNG quét prose (bất khả thi cho tiếng
# Việt — xem ADR-024). FAIL-LOUD: vi phạm → exit 1.
set -uo pipefail

GLOSSARY="docs/THUAT_NGU.md"
TERMS_FILE=".github/dictionaries/glossary-terms.txt"
for p in "$GLOSSARY" "$TERMS_FILE"; do
  [[ -f "$p" ]] || { echo "FAIL (check-glossary-definitions): thiếu $p"; exit 1; }
done

violations=0
while IFS= read -r term; do
  term="${term%%#*}"                                              # bỏ comment
  term="$(printf '%s' "$term" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"  # trim
  [[ -z "$term" ]] && continue
  # Hàng bảng có đầu cell là thuật ngữ (có/không **đậm**), không phân biệt hoa/thường.
  # vd: "| CI | ..."  hoặc  "| **Distill** (..) | ..."
  if ! grep -qiE "^\|[[:space:]]*\*{0,2}${term}([^[:alnum:]]|$)" "$GLOSSARY"; then
    echo "MẤT ĐỊNH NGHĨA  '$term'  không còn hàng trong $GLOSSARY"
    violations=$((violations + 1))
  fi
done < "$TERMS_FILE"

if (( violations > 0 )); then
  echo "FAIL (check-glossary-definitions): $violations thuật ngữ mất định nghĩa."
  exit 1
fi
echo "OK (check-glossary-definitions): các thuật ngữ canonical đều còn định nghĩa."
