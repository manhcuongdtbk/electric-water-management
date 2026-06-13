#!/usr/bin/env bash
# Post a PR comment linking the recorded demo videos artifact so the owner can
# review the walkthrough without leaving the PR (ADR-036). FAIL-LOUD.
set -uo pipefail

[[ -n "${PR_NUMBER:-}" ]] || {
  echo "post-demo-comment: no PR number (not a pull_request run) — skipping"
  exit 0
}

MARKER="<!-- demo-recordings -->"
# Prefer the direct artifact URL (upload-artifact output); fall back to the run page.
artifact_link="${ARTIFACT_URL:-${RUN_URL}}"
body="${MARKER}
🎬 **Bản demo tự động** cho pull request này đã được ghi hình.
👉 **Tải video (mp4):** [demo-videos](${artifact_link})
(hoặc mở [lần chạy CI](${RUN_URL}) → cuối trang, mục **Artifacts**)
> Chặng owner: xem để xác nhận tính năng ổn trước khi merge (ADR-036)."

# Delete the previous marker comment (best-effort) so the PR keeps one fresh link.
prev="$(gh api "repos/{owner}/{repo}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.body | contains(\"${MARKER}\")) | .id" 2>/dev/null | head -1)"
if [[ -n "$prev" ]]; then
  gh api "repos/{owner}/{repo}/issues/comments/${prev}" -X DELETE >/dev/null 2>&1 || true
  echo "post-demo-comment: deleted previous marker comment #${prev}"
fi

gh pr comment "$PR_NUMBER" --body "$body" \
  || { echo "post-demo-comment: gh comment failed"; exit 1; }
echo "post-demo-comment: posted demo link on PR #${PR_NUMBER}"
