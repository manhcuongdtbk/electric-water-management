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
  echo "✓ Pull request targets '${base:-<empty>}' (not main) — branch-source guard skipped."
  exit 0
fi

case "$head" in
  release/* | hotfix/*)
    echo "✓ Pull request to main from '$head' — allowed (Git Flow)."
    exit 0
    ;;
  *)
    echo "✗ Pull request to main may only come from release/* or hotfix/* (ADR-003)."
    echo "  Current source: '${head:-<empty>}'."
    echo "  → Retarget to 'develop', or branch from release/* | hotfix/* per Git Flow."
    exit 1
    ;;
esac
