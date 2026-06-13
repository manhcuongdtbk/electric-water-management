#!/usr/bin/env bash
# Tự động khép dấu vết khi đóng issue (ADR-035). Chạy hậu-merge từ workflow
# close-traceability.yml. Parse closing-keyword trong body PR → mỗi issue:
# (1) copy milestone PR→issue khi issue chưa có (copy-only, không ghi đè/chặn);
# (2) post comment kết cơ học idempotent (marker ẩn). Phán đoán để người/AI.
# Bash thuần FAIL-LOUD. Comment tiếng Việt (issue thread); echo/log tiếng Anh.
set -uo pipefail

# --- Pure helpers (test offline; no gh/network) -------------------------------

# Marker ẩn để idempotency: một comment kết / một PR / một issue.
comment_marker() { printf '<!-- auto-close-traceability:pr-%s -->' "$1"; }

# Body PR → số issue có closing-keyword GitHub, một dòng/số, theo thứ tự xuất
# hiện, đã khử trùng. Chỉ khớp keyword + #<số> (Refs/#trần không tính).
extract_issue_numbers() {
  printf '%s\n' "$1" \
    | grep -ioE '(close[sd]?|fix(es|ed)?|resolve[sd]?)[[:space:]]+#[0-9]+' \
    | grep -oE '[0-9]+' \
    | awk '!seen[$0]++' || true
}

# Các field → markdown comment kết (kèm marker). milestone_display đã sẵn sàng
# hiển thị (giá trị hoặc "— (chưa gán, chờ triage)").
render_comment() {
  local pr="$1" title="$2" short="$3" full="$4" base="$5" merged="$6" milestone="$7"
  cat <<EOF
$(comment_marker "$pr")
## Khép dấu vết (tự động) — đã merge

- **Pull request:** #${pr} — ${title}
- **Merge commit:** \`${short}\` (\`${full}\`)
- **Nhánh đích:** \`${base}\`
- **Thời điểm merge:** ${merged} (Asia/Ho_Chi_Minh)
- **Milestone:** ${milestone}

> Comment cơ học (ADR-035): xác nhận "đã ship gì". Phần nhận định (sai khác
> plan, caveat, chiều test đã phủ) do người/AI bổ sung khi có nuance.
EOF
}
