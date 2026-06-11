#!/usr/bin/env bash
# Guardrail quản trị tài liệu (ADR-024): mọi tài liệu (docs/**/*.md + file meta
# gốc) phải được docs/BAN_DO_TAI_LIEU.md phủ (đường dẫn chính xác hoặc glob tiền
# tố như docs/superpowers/specs/*); và mọi đường dẫn (file *.md hoặc glob */*)
# liệt kê trong bản đồ phải tồn tại. Bắt: file mới chưa phân loại, đường dẫn ma.
# FAIL-LOUD: vi phạm → exit 1.
set -uo pipefail

MAP="docs/BAN_DO_TAI_LIEU.md"
[[ -f "$MAP" ]] || { echo "✗ check-doc-map: $MAP not found."; exit 1; }

list_docs() {
  find docs -type f -name '*.md'
  for f in README.md AGENTS.md CONTRIBUTING.md CLAUDE.md; do
    [[ -f "$f" ]] && echo "$f"
  done
}

# Token đường dẫn liệt kê trong bản đồ: nội dung backtick dạng *.md hoặc */* sạch.
list_map_paths() {
  grep -oE '`[^`]+`' "$MAP" | tr -d '`' \
    | grep -E '^[A-Za-z0-9._/-]+\.md$|^[A-Za-z0-9._/-]+/\*$' | sort -u
}

violations=0

# (1) Completeness: mỗi file thực tế phải được phủ.
while IFS= read -r f; do
  covered=0
  while IFS= read -r p; do
    if [[ "$p" == "$f" ]]; then covered=1; break; fi
    if [[ "$p" == */\* ]]; then
      prefix="${p%\*}"   # "docs/superpowers/specs/"
      case "$f" in "$prefix"*) covered=1; break ;; esac
    fi
  done < <(list_map_paths)
  if (( ! covered )); then
    echo "✗ Unclassified  $f  (add it to $MAP)"
    violations=$((violations + 1))
  fi
done < <(list_docs | sort -u)

# (2) No-ghost: mỗi đường dẫn liệt kê phải tồn tại.
while IFS= read -r p; do
  if [[ "$p" == */\* ]]; then
    d="${p%/\*}"
    [[ -d "$d" ]] || { echo "✗ Ghost path (directory)  $p"; violations=$((violations + 1)); }
  else
    [[ -e "$p" ]] || { echo "✗ Ghost path (file)  $p"; violations=$((violations + 1)); }
  fi
done < <(list_map_paths)

if (( violations > 0 )); then
  echo "✗ check-doc-map: $violations document-map issue(s)."
  exit 1
fi
echo "✓ check-doc-map: document map matches the tree."
