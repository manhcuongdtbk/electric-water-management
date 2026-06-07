#!/usr/bin/env bash
# Branch-source guard (ADR-003, ADR-011): chặn pull request đích `main` đến từ
# nhánh KHÔNG phải release/* hoặc hotfix/*. Bash thuần, không dependency.
#
# Đọc hai biến môi trường (CI truyền từ github.base_ref / github.head_ref):
#   BASE_REF  — nhánh đích của pull request
#   HEAD_REF  — nhánh nguồn của pull request
#
# Quy ước thoát: 0 = hợp lệ (hoặc không áp dụng); 1 = vi phạm luật Git Flow.
set -euo pipefail

base="${BASE_REF:-}"
head="${HEAD_REF:-}"

if [ "$base" != "main" ]; then
  echo "✓ Pull request đích '${base:-<rỗng>}' (không phải main) — branch-source guard bỏ qua."
  exit 0
fi

case "$head" in
  release/* | hotfix/*)
    echo "✓ Pull request đích main đến từ '$head' — hợp lệ (Git Flow)."
    exit 0
    ;;
  *)
    echo "✗ Pull request đích main chỉ được đến từ release/* hoặc hotfix/* (ADR-003)."
    echo "  Nguồn hiện tại: '${head:-<rỗng>}'."
    echo "  → Đổi đích sang 'develop', hoặc cắt nhánh release/* | hotfix/* theo Git Flow."
    exit 1
    ;;
esac
