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
# Word-boundary trái = start-of-line HOẶC whitespace: keyword phải đứng riêng,
# nên "auto-closed"/"disclosed"/"unfixed" KHÔNG khớp (#389). Dùng whitespace
# (không phải [^[:alpha:]]) vì gạch nối trong "auto-closed" cũng là non-alpha →
# vẫn dính; và whitespace không phải chữ số nên không bị grep [0-9]+ bắt nhầm.
extract_issue_numbers() {
  printf '%s\n' "$1" \
    | grep -ioE '(^|[[:space:]])(close[sd]?|fix(es|ed)?|resolve[sd]?)[[:space:]]+#[0-9]+' \
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

# --- Orchestrator (gh I/O; runs only when executed, not when sourced) ---------

# Xử một issue: copy milestone (copy-only) rồi post comment kết (idempotent).
# Trả 0 nếu OK/skip; 1 nếu có thao tác gh lỗi (để main gộp thành đỏ cuối).
process_issue() {
  local issue="$1"

  # GitHub closing-keywords only ever act on issues, never on pull requests, so
  # a number that resolves to a PR is not a close target — skip it (not an
  # error). This mirrors GitHub's own behavior and avoids commenting on a PR,
  # which the workflow lacks `pull-requests: write` for (would 403 → false red).
  # Reachable in practice: a PR body documenting a closing-keyword example (e.g.
  # "this closes #9" where #9 is a PR) matches legitimately yet must be ignored.
  # The REST /issues/N endpoint carries a `pull_request` object only for PRs;
  # this is the reliable discriminator (`gh pr view N` also resolves issue
  # numbers, so it cannot tell the two apart). (#389)
  local issue_kind
  issue_kind="$(gh api "repos/{owner}/{repo}/issues/${issue}" \
    --jq 'if .pull_request then "pr" else "issue" end' 2>/dev/null || echo "")"
  if [[ "$issue_kind" == "pr" ]]; then
    echo "#${issue} is a pull request, not an issue; skipping (closing keywords act on issues only)."
    return 0
  fi
  if [[ "$issue_kind" != "issue" ]]; then
    echo "::warning::Cannot resolve #${issue} (missing or no access); skipping."
    return 1
  fi

  local issue_ms
  if ! issue_ms="$(gh issue view "$issue" --json milestone --jq '.milestone.title // ""' 2>/dev/null)"; then
    echo "::warning::Cannot read issue #${issue} (missing or no access); skipping."
    return 1
  fi

  # Lớp 2 — milestone copy-only: chỉ khi PR có milestone và issue chưa có.
  if [[ -n "$PR_MILESTONE" && -z "$issue_ms" ]]; then
    if gh issue edit "$issue" --milestone "$PR_MILESTONE" >/dev/null; then
      issue_ms="$PR_MILESTONE"
      echo "Copied milestone '${PR_MILESTONE}' to issue #${issue}."
    else
      echo "::warning::Failed to copy milestone to issue #${issue}."
      echo "Skipping the close-traceability comment for issue #${issue} due to the milestone-copy failure."
      return 1
    fi
  fi

  # Idempotency — bỏ qua nếu issue đã có comment kết của đúng PR này.
  local marker; marker="$(comment_marker "$PR_NUMBER")"
  if gh issue view "$issue" --json comments --jq '.comments[].body' 2>/dev/null | grep -qF "$marker"; then
    echo "Issue #${issue} already has the close-traceability comment for PR #${PR_NUMBER}; skipping."
    return 0
  fi

  local ms_display
  if [[ -n "$issue_ms" ]]; then ms_display="$issue_ms"; else ms_display="— (chưa gán, chờ triage)"; fi

  local body
  body="$(render_comment "$PR_NUMBER" "$PR_TITLE" "$SHORT_SHA" "$MERGE_SHA" "$BASE_REF" "$MERGED_AT_LOCAL" "$ms_display")"
  if gh issue comment "$issue" --body "$body" >/dev/null; then
    echo "Posted close-traceability comment to issue #${issue}."
    return 0
  fi
  echo "::warning::Failed to comment on issue #${issue}."
  return 1
}

main() {
  : "${PR_NUMBER:?PR_NUMBER is required}"
  : "${MERGE_SHA:?MERGE_SHA is required}"
  PR_TITLE="${PR_TITLE:-}"
  PR_BODY="${PR_BODY:-}"
  BASE_REF="${BASE_REF:-}"
  MERGED_AT="${MERGED_AT:-}"
  PR_MILESTONE="${PR_MILESTONE:-}"

  SHORT_SHA="${MERGE_SHA:0:7}"
  # GitHub merged_at is UTC ISO-8601; GNU date on the runner converts the display.
  if [[ -n "$MERGED_AT" ]]; then
    MERGED_AT_LOCAL="$(TZ='Asia/Ho_Chi_Minh' date -d "$MERGED_AT" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '%s' "$MERGED_AT")"
  else
    MERGED_AT_LOCAL="(không rõ)"
  fi

  local issues; issues="$(extract_issue_numbers "$PR_BODY")"
  if [[ -z "$issues" ]]; then
    echo "No closing keywords (Closes/Fixes/Resolves #N) in PR #${PR_NUMBER} body; nothing to do."
    return 0
  fi

  local rc=0
  while IFS= read -r issue; do
    [[ -z "$issue" ]] && continue
    process_issue "$issue" || rc=1
  done <<< "$issues"
  return "$rc"
}

# Chỉ chạy main khi script được EXECUTE (không phải khi companion `source`).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
