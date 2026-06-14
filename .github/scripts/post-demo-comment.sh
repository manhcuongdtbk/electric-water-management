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
🎬 **Demo đã quay lại** — CI vừa ghi hình lại **toàn bộ** demo walkthrough cho lần chạy này.
ℹ️ Comment này chỉ xuất hiện khi pull request **đụng path demo lái qua** (\`spec/demo/\`, \`app/views/\`, \`app/controllers/\`, \`config/routes.rb\`, \`db/seeds/demo.rb\`, helper demo trong \`spec/support/\`) — tức nội dung demo **có thể đã thay đổi** (ADR-055).
👉 **Tải video (mp4):** [demo-videos](${artifact_link})
(hoặc mở [lần chạy CI](${RUN_URL}) → cuối trang, mục **Artifacts**)
> Chặng owner: xem video để xác nhận demo vẫn chạy đúng trước khi merge (ADR-036)."

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
