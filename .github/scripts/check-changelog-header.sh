#!/usr/bin/env bash
# Guardrail header lịch sử thay đổi (#339): tài liệu spec dùng DUY NHẤT header
# `## Lịch sử thay đổi` (khớp `AGENTS.md`), KHÔNG dùng biến thể `## Changelog`.
# Bỏ qua khối code fence (ví dụ `## Changelog` minh hoạ trong code block không
# tính); chỉ bắt heading thật `^#+ Changelog`. Plans là bản ghi lịch sử → ngoài
# phạm vi (không viết lại tài liệu lịch sử). Theo pattern ADR-024/030/033 (bash
# fail-loud). FAIL-LOUD: vi phạm/lỗi → exit 1.
set -uo pipefail

SPECS_DIR="${1:-docs/superpowers/specs}"
[[ -d "$SPECS_DIR" ]] || { echo "✗ check-changelog-header: specs dir not found: $SPECS_DIR"; exit 1; }

violations=0
while IFS= read -r f; do
  incode=0; lineno=0
  while IFS= read -r raw; do
    lineno=$((lineno + 1))
    case "$raw" in '```'*|'~~~'*) incode=$((1 - incode)); continue ;; esac
    (( incode )) && continue
    # Một heading có nội dung đúng là "Changelog" (mọi cấp #). Prose nhắc tới
    # `## Changelog` (bọc backtick, không mở đầu bằng #) KHÔNG khớp `^#+`.
    if printf '%s' "$raw" | grep -qiE '^#+[[:space:]]+changelog[[:space:]]*$'; then
      echo "✗ non-canonical changelog header  $f:$lineno  → use '## Lịch sử thay đổi' (AGENTS), not '## Changelog'"
      violations=$((violations + 1))
    fi
  done < "$f"
done < <(find "$SPECS_DIR" -type f -name '*.md' | sort)

if (( violations > 0 )); then
  echo "✗ check-changelog-header: $violations non-canonical changelog header(s)."
  exit 1
fi
echo "✓ check-changelog-header: specs use the canonical '## Lịch sử thay đổi' header."
