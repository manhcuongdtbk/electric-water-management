#!/usr/bin/env bash
# Remind to merge-back main → develop after release/hotfix merges to main
# (Issue #445, CONTRIBUTING §2). Runs from close-traceability workflow when
# a PR targeting main from release/* or hotfix/* is merged.
# Posts a reminder comment on the merged PR (idempotent via marker).
# Inputs via env: PR_NUMBER, HEAD_REF, BASE_REF.
# Bash thuần FAIL-LOUD. Comment tiếng Việt; echo/log tiếng Anh.
set -uo pipefail

: "${PR_NUMBER:?PR_NUMBER is required}"
HEAD_REF="${HEAD_REF:-}"
BASE_REF="${BASE_REF:-}"

# Only act on release/hotfix merged into main
if [[ "$BASE_REF" != "main" ]]; then
  echo "Base ref is '${BASE_REF}', not 'main'; skipping merge-back reminder."
  exit 0
fi

if [[ "$HEAD_REF" != release/* ]] && [[ "$HEAD_REF" != hotfix/* ]]; then
  echo "Head ref '${HEAD_REF}' is not release/* or hotfix/*; skipping merge-back reminder."
  exit 0
fi

# Idempotency
marker="<!-- merge-back-reminder:pr-${PR_NUMBER} -->"
if gh pr view "$PR_NUMBER" --json comments --jq '.comments[].body' 2>/dev/null | grep -qF "$marker"; then
  echo "PR #${PR_NUMBER} already has merge-back reminder; skipping."
  exit 0
fi

body="$(cat <<EOF
${marker}
## Nhắc merge-back (tự động)

\`${HEAD_REF}\` đã merge vào \`main\`. **Cần merge-back \`main\` → \`develop\`** để develop có \`CHANGELOG.md\`, \`version.txt\`, và các commit release/hotfix.

\`\`\`bash
git fetch origin
git checkout develop
git merge origin/main
git push origin develop
\`\`\`

> Merge-back dùng **merge commit** (không squash) — xem CONTRIBUTING.md §2.
EOF
)"

if gh pr comment "$PR_NUMBER" --body "$body" >/dev/null; then
  echo "Posted merge-back reminder to PR #${PR_NUMBER}."
else
  echo "::warning::Failed to post merge-back reminder to PR #${PR_NUMBER}."
  exit 1
fi
