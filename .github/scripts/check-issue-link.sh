#!/usr/bin/env bash
# Guardrail (ADR-015 revisit, Issue #442): every pull request must reference at
# least one GitHub Issue in its body (Refs #N, Closes #N, Fixes #N, Resolves #N).
# Exempt: release-please PRs (bot author), release/hotfix/merge-back PRs.
# Inputs via env: PR_BODY, PR_AUTHOR, PR_TITLE.
# FAIL-LOUD: violation → exit 1.
set -uo pipefail

# --- Exemptions ---

# release-please bot
if [[ "${PR_AUTHOR:-}" == "app/github-actions" ]]; then
  echo "✓ check-issue-link: release-please PR (bot author) — exempt."
  exit 0
fi

# release/hotfix/merge-back PRs (non-feature, process PRs without a dedicated issue)
title="${PR_TITLE:-}"
if [[ "$title" == release:* ]] || [[ "$title" == hotfix:* ]] || [[ "$title" == Merge\ * ]]; then
  echo "✓ check-issue-link: process PR (${title%%:*}) — exempt."
  exit 0
fi

# --- Check ---

body="${PR_BODY:-}"

if [[ -z "$body" ]]; then
  echo "✗ check-issue-link: PR body is empty — must contain at least one issue reference (Refs #N, Closes #N, Fixes #N, or Resolves #N)."
  exit 1
fi

if echo "$body" | grep -qiE '(Refs|Closes|Fixes|Resolves)\s+#[0-9]+'; then
  echo "✓ check-issue-link: PR body references an issue."
  exit 0
fi

echo "✗ check-issue-link: PR body does not reference any issue."
echo "  Add 'Refs #N', 'Closes #N', 'Fixes #N', or 'Resolves #N' to the PR description."
echo "  (Process PRs like release/hotfix/merge-back are exempt.)"
exit 1
