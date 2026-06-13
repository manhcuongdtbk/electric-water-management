#!/usr/bin/env bash
# Post (or refresh) a PR comment presenting the release demo bundle so the owner
# can review the delta clips before forwarding them to the customer (ADR-048).
# The comment embeds the bundle manifest and links the uploaded artifact. The
# owner reviews + forwards manually — this script SENDS NOTHING to the customer.
# Inputs via env: PR_NUMBER, MANIFEST_FILE (path to manifest.md), ARTIFACT_URL,
# RUN_URL. FAIL-LOUD on a failed comment; a missing PR number is a clean skip.
set -uo pipefail

[[ -n "${PR_NUMBER:-}" ]] || {
  echo "post-bundle-comment: no PR number (not a pull_request run) — skipping"
  exit 0
}

MARKER="<!-- demo-bundle -->"
artifact_link="${ARTIFACT_URL:-${RUN_URL}}"

if [[ -n "${MANIFEST_FILE:-}" && -f "${MANIFEST_FILE}" ]]; then
  manifest="$(cat "${MANIFEST_FILE}")"
else
  manifest="_Không tìm thấy manifest — chưa có demo hướng-khách mới trong release này, hoặc bước gom chưa chạy._"
fi

body="${MARKER}
🎞️ **Bộ demo delta của release** (các tính năng hướng-khách MỚI so với bản trước) đã được gom.
👉 **Tải bộ clip (mp4):** [demo-bundle](${artifact_link})
(hoặc mở [lần chạy CI](${RUN_URL}) → cuối trang, mục **Artifacts**)

${manifest}

> Chặng KHÁCH ①: owner **duyệt** nội dung rồi **gửi** khách qua kênh sẵn có (gate người · ADR-028/029). CI KHÔNG tự gửi."

# Keep a single fresh bundle comment: delete the previous marker comment (best-effort).
prev="$(gh api "repos/{owner}/{repo}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.body | contains(\"${MARKER}\")) | .id" 2>/dev/null | head -1)"
if [[ -n "$prev" ]]; then
  gh api "repos/{owner}/{repo}/issues/comments/${prev}" -X DELETE >/dev/null 2>&1 || true
  echo "post-bundle-comment: deleted previous marker comment #${prev}"
fi

gh pr comment "$PR_NUMBER" --body "$body" \
  || { echo "post-bundle-comment: gh comment failed"; exit 1; }
echo "post-bundle-comment: posted demo-bundle review comment on PR #${PR_NUMBER}"
