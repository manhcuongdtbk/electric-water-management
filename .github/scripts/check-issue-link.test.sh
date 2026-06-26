#!/usr/bin/env bash
# Companion tests for check-issue-link.sh.
# Run: bash .github/scripts/check-issue-link.test.sh
set -uo pipefail

SCRIPT=".github/scripts/check-issue-link.sh"
pass=0; fail=0

run_test() {
  local desc="$1" expected="$2"
  shift 2
  # remaining args are env vars
  output=$(env "$@" bash "$SCRIPT" 2>&1) && rc=0 || rc=$?
  if [[ "$rc" -eq "$expected" ]]; then
    echo "  ✓ $desc"
    pass=$((pass + 1))
  else
    echo "  ✗ $desc (expected exit $expected, got $rc)"
    echo "    output: $output"
    fail=$((fail + 1))
  fi
}

echo "== check-issue-link tests =="

# Exempt: release-please bot (both author formats)
run_test "release-please bot exempt (app/)" 0 \
  PR_AUTHOR="app/github-actions" PR_TITLE="chore(main): release 1.2.0" PR_BODY=""
run_test "release-please bot exempt ([bot])" 0 \
  PR_AUTHOR="github-actions[bot]" PR_TITLE="chore(main): release 1.2.0" PR_BODY=""

# Exempt: dependabot (both author formats)
run_test "dependabot exempt (app/)" 0 \
  PR_AUTHOR="app/dependabot" PR_TITLE="chore(deps): Bump rails from 8.0.1 to 8.0.2" PR_BODY="Bumps rails..."
run_test "dependabot exempt ([bot])" 0 \
  PR_AUTHOR="dependabot[bot]" PR_TITLE="chore(deps): Bump rails from 8.0.1 to 8.0.2" PR_BODY="Bumps rails..."

# Exempt: release PR
run_test "release PR exempt" 0 \
  PR_AUTHOR="user" PR_TITLE="release: merge release/1.3 into main" PR_BODY=""

# Exempt: hotfix PR
run_test "hotfix PR exempt" 0 \
  PR_AUTHOR="user" PR_TITLE="hotfix: fix critical billing bug" PR_BODY=""

# Exempt: merge-back PR
run_test "merge-back PR exempt" 0 \
  PR_AUTHOR="user" PR_TITLE="Merge branch 'main' into develop" PR_BODY=""

# Pass: Refs #N
run_test "Refs #123 passes" 0 \
  PR_AUTHOR="user" PR_TITLE="feat: add feature" PR_BODY="Refs #123"

# Pass: Closes #N
run_test "Closes #456 passes" 0 \
  PR_AUTHOR="user" PR_TITLE="fix: bug" PR_BODY="Closes #456"

# Pass: Fixes #N
run_test "Fixes #789 passes" 0 \
  PR_AUTHOR="user" PR_TITLE="fix: bug" PR_BODY="Some text. Fixes #789. More text."

# Pass: Resolves #N
run_test "Resolves #10 passes" 0 \
  PR_AUTHOR="user" PR_TITLE="feat: thing" PR_BODY="Resolves #10"

# Pass: case-insensitive
run_test "refs #1 (lowercase) passes" 0 \
  PR_AUTHOR="user" PR_TITLE="feat: thing" PR_BODY="refs #1"

# Pass: keyword in multiline body
run_test "multiline body with Closes passes" 0 \
  PR_AUTHOR="user" PR_TITLE="feat: thing" PR_BODY=$'## Summary\nSome work.\n\nCloses #42'

# Fail: empty body
run_test "empty body fails" 1 \
  PR_AUTHOR="user" PR_TITLE="feat: thing" PR_BODY=""

# Fail: no keyword, just #N
run_test "bare #123 without keyword fails" 1 \
  PR_AUTHOR="user" PR_TITLE="feat: thing" PR_BODY="Related to #123"

# Fail: keyword without number
run_test "Refs without number fails" 1 \
  PR_AUTHOR="user" PR_TITLE="feat: thing" PR_BODY="Refs some issue"

# Fail: template placeholder not filled
run_test "template placeholder Refs # fails" 1 \
  PR_AUTHOR="user" PR_TITLE="feat: thing" PR_BODY="Refs #"

echo ""
echo "== Results: $pass passed, $fail failed =="
[[ "$fail" -eq 0 ]]
